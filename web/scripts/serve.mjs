#!/usr/bin/env node
/**
 * Local static server with production-like Cache-Control + gzip for text assets.
 */
import { createServer } from "node:http";
import { readFileSync, statSync, existsSync } from "node:fs";
import { join, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";

const WEB = fileURLToPath(new URL("..", import.meta.url));
const PORT = Number(process.env.PORT || 8080);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".mp4": "video/mp4",
  ".mov": "video/quicktime",
  ".glb": "model/gltf-binary",
  ".woff2": "font/woff2",
  ".txt": "text/plain; charset=utf-8",
  ".xml": "application/xml; charset=utf-8",
};

const GZIP = new Set([".html", ".css", ".js", ".json", ".svg", ".xml", ".txt"]);

function cacheFor(path) {
  if (path.startsWith("/assets/")) return "public, max-age=2592000, stale-while-revalidate=86400";
  if (path.startsWith("/css/") || path.startsWith("/js/")) {
    return "public, max-age=86400, stale-while-revalidate=86400";
  }
  if (path.endsWith(".html")) return "public, max-age=0, must-revalidate";
  return "public, max-age=3600";
}

function safePath(urlPath) {
  const clean = decodeURIComponent(urlPath.split("?")[0]);
  const rel = clean === "/" ? "/index.html" : clean;
  const abs = join(WEB, rel);
  if (!abs.startsWith(WEB)) return null;
  return abs;
}

const server = createServer((req, res) => {
  const path = safePath(req.url || "/");
  if (!path || !existsSync(path)) {
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Not found");
    return;
  }
  const st = statSync(path);
  if (!st.isFile()) {
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Not found");
    return;
  }
  const ext = extname(path).toLowerCase();
  const raw = readFileSync(path);
  const type = MIME[ext] || "application/octet-stream";
  const accept = req.headers["accept-encoding"] || "";
  const canGzip = GZIP.has(ext) && accept.includes("gzip") && raw.length > 512;
  const body = canGzip ? gzipSync(raw) : raw;
  const headers = {
    "Content-Type": type,
    "Cache-Control": cacheFor((req.url || "/").split("?")[0]),
    "Content-Length": body.length,
    Vary: "Accept-Encoding",
  };
  if (canGzip) headers["Content-Encoding"] = "gzip";
  res.writeHead(200, headers);
  res.end(body);
});

server.listen(PORT, () => {
  console.log(`tomato web @ http://localhost:${PORT}/ (cache + gzip)`);
  console.log("Use this server for Lighthouse — not python -m http.server (no cache/compression).");
});
