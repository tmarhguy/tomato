#!/usr/bin/env node
import { existsSync, mkdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const web = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const root = resolve(web, "..");
const sourceDir = join(root, "docs", "diagrams");
const outputDir = join(web, "assets", "gallery", "diagrams");
const mmdc = join(web, "node_modules", ".bin", process.platform === "win32" ? "mmdc.cmd" : "mmdc");

const diagrams = [
  "system-realizations",
  "artifact-pipeline",
  "fpga-datapath",
  "envelop-boundary",
];
const themes = ["default", "dark"];

if (!existsSync(mmdc)) {
  throw new Error("Mermaid CLI is not installed; run `npm install` in web/");
}

mkdirSync(outputDir, { recursive: true });

for (const diagram of diagrams) {
  const input = join(sourceDir, `${diagram}.mmd`);
  if (!existsSync(input)) throw new Error(`missing Mermaid source: ${input}`);

  for (const theme of themes) {
    const variant = theme === "default" ? "light" : "dark";
    const output = join(outputDir, `${diagram}-${variant}.svg`);
    const result = spawnSync(
      mmdc,
      ["--input", input, "--output", output, "--theme", theme, "--backgroundColor", "transparent", "--quiet"],
      { encoding: "utf8" },
    );
    if (result.status !== 0) {
      throw new Error(`failed to render ${diagram} (${variant})\n${result.stderr || result.stdout}`);
    }
    console.log(`rendered ${output.slice(root.length + 1)}`);
  }
}
