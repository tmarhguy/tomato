#!/usr/bin/env node
/**
 * Run Lighthouse mobile + desktop on index.html. Requires serve running or starts one.
 *   npm run perf
 */
import { spawn } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { setTimeout as sleep } from "node:timers/promises";

const PORT = Number(process.env.PORT || 8791);
const URL = `http://127.0.0.1:${PORT}/index.html`;

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (out += d));
    child.on("close", (code) => {
      if (code === 0) resolve(out);
      else reject(new Error(out || `exit ${code}`));
    });
  });
}

async function ensureServer() {
  try {
    await run("curl", ["-sf", URL]);
    return null;
  } catch {
    const child = spawn(process.execPath, ["scripts/serve.mjs"], {
      env: { ...process.env, PORT: String(PORT) },
      stdio: "ignore",
      detached: true,
    });
    child.unref();
    for (let i = 0; i < 20; i++) {
      await sleep(200);
      try {
        await run("curl", ["-sf", URL]);
        return child;
      } catch {
        /* retry */
      }
    }
    throw new Error("server did not start");
  }
}

async function audit(formFactor, outPath) {
  const args = [
    "lighthouse",
    URL,
    "--only-categories=performance",
    `--form-factor=${formFactor}`,
    "--output=json",
    `--output-path=${outPath}`,
    "--chrome-flags=--headless --no-sandbox",
    "--quiet",
  ];
  if (formFactor === "desktop") args.push("--screenEmulation.disabled");
  await run("npx", args);
  const report = JSON.parse(readFileSync(outPath, "utf8"));
  const perf = Math.round(report.categories.performance.score * 100);
  const metrics = ["first-contentful-paint", "largest-contentful-paint", "total-blocking-time", "cumulative-layout-shift", "speed-index"];
  const lines = metrics.map((k) => `${k}: ${report.audits[k].displayValue}`);
  return { perf, lines, report };
}

const server = await ensureServer();
try {
  const mobile = await audit("mobile", "/tmp/tomato-lh-mobile.json");
  const desktop = await audit("desktop", "/tmp/tomato-lh-desktop.json");
  console.log("Mobile performance:", mobile.perf);
  mobile.lines.forEach((l) => console.log(" ", l));
  console.log("Desktop performance:", desktop.perf);
  desktop.lines.forEach((l) => console.log(" ", l));
  const floor = Number(process.env.PERF_MIN || 0);
  if (floor && (mobile.perf < floor || desktop.perf < floor)) {
    process.exitCode = 1;
    console.error(`Below PERF_MIN=${floor}`);
  }
} finally {
  if (server) server.kill("SIGTERM");
}
