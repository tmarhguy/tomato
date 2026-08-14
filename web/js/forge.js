/* Live GitHub repo, rendered in The Tomato frame. Public API, this repo only. */
(function () {
  const OWNER = "tmarhguy";
  const REPO = "tomato";
  const ROOT = `https://api.github.com/repos/${OWNER}/${REPO}`;
  const GH = `https://github.com/${OWNER}/${REPO}`;
  const GH_USER = `https://github.com/${OWNER}`;
  const ICONS = {
    dir: '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M1.75 2A1.75 1.75 0 0 0 0 3.75v8.5C0 13.216.784 14 1.75 14h12.5A1.75 1.75 0 0 0 16 12.25v-6.5A1.75 1.75 0 0 0 14.25 4H7.5L6.28 2.78A.75.75 0 0 0 5.75 2.5H1.75Z"/></svg>',
    file: '<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M2 1.75C2 .784 2.784 0 3.75 0h6.586c.464 0 .909.184 1.237.513l2.914 2.914c.329.328.513.773.513 1.237v9.586A1.75 1.75 0 0 1 13.25 16h-9.5A1.75 1.75 0 0 1 2 14.25Zm1.75-.25a.25.25 0 0 0-.25.25v12.5c0 .138.112.25.25.25h9.5a.25.25 0 0 0 .25-.25V6H9.75A1.75 1.75 0 0 1 8 4.25V1.5Zm7.47 1.97L9.5 1.56v2.69c0 .138.112.25.25.25h2.69Z"/></svg>',
  };

  const mount = document.getElementById("forge");
  const cache = new Map();
  let repoMeta = null;

  async function api(url) {
    if (cache.has(url)) return cache.get(url);
    const res = await fetch(url, { headers: { Accept: "application/vnd.github+json" } });
    if (res.status === 403) throw new Error("GitHub rate limit — wait a minute and reload.");
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    const data = await res.json();
    cache.set(url, data);
    return data;
  }

  function parseHash() {
    const raw = (location.hash || "#/tree/main").replace(/^#/, "");
    const parts = raw.split("/").filter(Boolean);
    const head = parts[0] || "tree";
    if (head === "issues" || head === "pulls" || head === "commits") {
      return { tab: head };
    }
    const kind = head === "blob" ? "blob" : "tree";
    const branch = parts[1] || "main";
    const path = parts.slice(2).join("/");
    return { tab: "code", kind, branch, path };
  }

  function href(kind, branch, path) {
    const p = path ? `/${path}` : "";
    return `#/${kind}/${branch}${p}`;
  }

  function fmtDate(iso) {
    if (!iso) return "";
    const d = new Date(iso);
    return d.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
  }

  function decode64(b64) {
    const bin = atob(b64.replace(/\n/g, ""));
    const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
    return new TextDecoder("utf-8").decode(bytes);
  }

  function isImage(name) {
    return /\.(png|jpe?g|gif|webp|svg)$/i.test(name);
  }

  function esc(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function resolvePath(fromDir, rel) {
    const clean = String(rel).split("#")[0].split("?")[0];
    const parts = fromDir ? fromDir.split("/").filter(Boolean) : [];
    clean.split("/").forEach((p) => {
      if (!p || p === ".") return;
      if (p === "..") parts.pop();
      else parts.push(p);
    });
    return parts.join("/");
  }

  function rawUrl(src, dir, branch) {
    if (!src) return src;
    if (/^(data:|blob:)/i.test(src)) return src;
    if (/^https?:\/\/img\.shields\.io/i.test(src)) return src;
    const blob = src.match(/github\.com\/[^/]+\/[^/]+\/(?:blob|raw)\/([^/]+)\/(.+)$/);
    if (blob) return `https://raw.githubusercontent.com/${OWNER}/${REPO}/${blob[1]}/${blob[2]}`;
    if (/^https?:\/\//i.test(src)) return src;
    return `https://raw.githubusercontent.com/${OWNER}/${REPO}/${branch}/${resolvePath(dir, src)}`;
  }

  function rewriteMd(html, dir, branch) {
    const wrap = document.createElement("div");
    wrap.innerHTML = html;
    wrap.querySelectorAll("img").forEach((img) => {
      img.setAttribute("src", rawUrl(img.getAttribute("src") || "", dir, branch));
      img.loading = "lazy";
    });
    wrap.querySelectorAll("a[href]").forEach((a) => {
      const href = a.getAttribute("href") || "";
      if (/^(https?:|mailto:|#|\/\/)/i.test(href)) return;
      const resolved = resolvePath(dir, href);
      const kind = /\.[a-z0-9]+$/i.test(resolved.split("/").pop() || "") ? "blob" : "tree";
      a.setAttribute("href", `#/${kind}/${branch}/${resolved}`);
    });
    return wrap.innerHTML;
  }

  function md(text, dir, branch) {
    let html;
    if (window.marked && typeof window.marked.parse === "function") {
      html = window.marked.parse(text);
    } else {
      html = `<pre>${esc(text)}</pre>`;
    }
    return rewriteMd(html, dir || "", branch || "main");
  }

  function crumb(branch, path) {
    const bits = path ? path.split("/") : [];
    let acc = "";
    const links = [`<a href="${href("tree", branch, "")}">${REPO}</a>`];
    bits.forEach((b, i) => {
      acc = acc ? `${acc}/${b}` : b;
      const last = i === bits.length - 1;
      const kind = last && location.hash.includes("/blob/") ? "blob" : "tree";
      links.push(last ? `<strong>${esc(b)}</strong>` : `<a href="${href(kind, branch, acc)}">${esc(b)}</a>`);
    });
    return `<nav class="forge-crumb">${links.join(" / ")}</nav>`;
  }

  function tabs(route) {
    const on = (t) => (route.tab === t ? "is-on" : "");
    return `<nav class="forge-tabs">
      <a class="${on("code")}" href="#/tree/${route.branch || "main"}">Code</a>
      <a class="${on("issues")}" href="#/issues">Issues</a>
      <a class="${on("pulls")}" href="#/pulls">Pull requests</a>
      <a class="${on("commits")}" href="#/commits">Commits</a>
    </nav>`;
  }

  function header(meta, route) {
    return `<div class="forge-head">
      <div>
        <div class="forge-title"><a href="${GH_USER}" target="_blank" rel="noopener">${esc(OWNER)}</a><span class="slash">/</span><a href="#/tree/main">${esc(REPO)}</a></div>
        <p class="forge-about">${esc(meta.description || "")}</p>
      </div>
      <div class="forge-tools">
        <div class="forge-toggle" role="group" aria-label="Read the tree">
          <a class="is-on" href="source.html" aria-current="page">Paper</a>
          <a href="${GH}" target="_blank" rel="noopener">GitHub</a>
        </div>
        <div class="forge-actions">
          <a class="forge-btn" href="${GH}" target="_blank" rel="noopener">Star</a>
          <a class="forge-btn forge-btn--ghost" href="${GH_USER}" target="_blank" rel="noopener">Follow</a>
        </div>
        <div class="forge-counts">
          <a href="${GH}" target="_blank" rel="noopener"><strong>${meta.stargazers_count}</strong> Stars</a>
          <a href="${GH}/fork" target="_blank" rel="noopener"><strong>${meta.forks_count}</strong> Forks</a>
          <a href="${GH}/issues" target="_blank" rel="noopener"><strong>${meta.open_issues_count}</strong> Issues</a>
        </div>
      </div>
    </div>
    ${tabs(route)}`;
  }

  function side(meta, langs) {
    const langList = Object.keys(langs || {})
      .slice(0, 8)
      .map((k) => `<li>${esc(k)}</li>`)
      .join("");
    const license = meta.license ? meta.license.spdx_id || meta.license.name : "CERN-OHL-P-2.0";
    return `<aside>
      <div class="forge-side">
        <h3>About</h3>
        <p>${esc(meta.description || "A homebrew 32-bit CPU.")}</p>
      </div>
      <div class="forge-side">
        <h3>License</h3>
        <p>${esc(license)}</p>
      </div>
      <div class="forge-side">
        <h3>Languages</h3>
        <ul>${langList || "<li>—</li>"}</ul>
      </div>
      <div class="forge-side">
        <h3>Updated</h3>
        <p>${fmtDate(meta.pushed_at)}</p>
      </div>
    </aside>`;
  }

  async function commitBar(branch, path) {
    const q = path ? `&path=${encodeURIComponent(path)}` : "";
    const commits = await api(`${ROOT}/commits?sha=${encodeURIComponent(branch)}&per_page=1${q}`);
    const c = commits[0];
    if (!c) return "";
    return `<div class="forge-commit">
      <span><strong>${esc(c.commit.author.name)}</strong> — ${esc(c.commit.message.split("\n")[0])}</span>
      <span><span class="sha">${esc(c.sha.slice(0, 7))}</span> · ${fmtDate(c.commit.author.date)}</span>
    </div>`;
  }

  function fileRow(item, branch) {
    const kind = item.type === "dir" ? "tree" : "blob";
    const icon = item.type === "dir" ? ICONS.dir : ICONS.file;
    const size = item.type === "file" && item.size != null ? `${item.size} b` : "";
    return `<a class="forge-row" href="${href(kind, branch, item.path)}">
      <span class="name">${icon}<span>${esc(item.name)}</span></span>
      <span class="msg">${item.type === "dir" ? "—" : ""}</span>
      <span class="age">${esc(size)}</span>
    </a>`;
  }

  async function renderTree(route) {
    const path = route.path ? `/${route.path}` : "";
    const listing = await api(`${ROOT}/contents${path}?ref=${encodeURIComponent(route.branch)}`);
    const items = Array.isArray(listing) ? listing.slice() : [];
    items.sort((a, b) => (a.type === b.type ? a.name.localeCompare(b.name) : a.type === "dir" ? -1 : 1));

    const parent = route.path
      ? `<a class="forge-row" href="${href("tree", route.branch, route.path.split("/").slice(0, -1).join("/"))}">
          <span class="name">${ICONS.dir}<span>..</span></span>
          <span class="msg">Parent</span>
          <span class="age"></span>
        </a>`
      : "";

    const bar = await commitBar(route.branch, route.path);
    let readme = "";
    if (!route.path) {
      const readmeFile = items.find((i) => /^readme(\.md)?$/i.test(i.name));
      if (readmeFile) {
        const blob = await api(`${ROOT}/contents/${readmeFile.path}?ref=${encodeURIComponent(route.branch)}`);
        if (blob.content) {
          readme = `<article class="forge-readme">
            <div class="forge-readme-bar"><span>${esc(readmeFile.name)}</span><span>Rendered</span></div>
            <div class="forge-readme-body">${md(decode64(blob.content), "", route.branch)}</div>
          </article>`;
        }
      }
    }

    const langs = await api(`${ROOT}/languages`);
    mount.innerHTML = `
      ${header(repoMeta, route)}
      <div class="forge-toolbar">
        <select id="forge-branch" aria-label="Branch"></select>
        <label class="forge-clone">
          <input id="forge-clone" readonly value="https://github.com/${OWNER}/${REPO}.git" />
          <button type="button" id="forge-copy">Copy</button>
        </label>
      </div>
      ${crumb(route.branch, route.path)}
      <div class="forge-grid">
        <div>
          ${bar}
          <div class="forge-files">${parent}${items.map((i) => fileRow(i, route.branch)).join("")}</div>
          ${readme}
        </div>
        ${side(repoMeta, langs)}
      </div>`;
    await fillBranches(route.branch);
    bindClone();
  }

  async function renderBlob(route) {
    const blob = await api(`${ROOT}/contents/${route.path}?ref=${encodeURIComponent(route.branch)}`);
    const bar = await commitBar(route.branch, route.path);
    let body = "";
    if (isImage(blob.name)) {
      const src = blob.download_url;
      body = `<div style="padding:1rem"><img class="forge-img" src="${esc(src)}" alt="${esc(blob.name)}" /></div>`;
    } else if (blob.content && blob.encoding === "base64") {
      const text = decode64(blob.content);
      if (/\.md$/i.test(blob.name)) {
        body = `<div class="forge-md">${md(text, route.path.split("/").slice(0, -1).join("/"), route.branch)}</div>`;
      } else {
        body = `<pre><code>${esc(text)}</code></pre>`;
      }
    } else {
      body = `<p class="forge-err" style="padding:1rem">Binary file. Fetch the tree if you need the bytes.</p>`;
    }

    mount.innerHTML = `
      ${header(repoMeta, route)}
      <div class="forge-toolbar">
        <select id="forge-branch" aria-label="Branch"></select>
        <a class="forge-btn" href="${href("tree", route.branch, route.path.split("/").slice(0, -1).join("/"))}">Up</a>
      </div>
      ${crumb(route.branch, route.path)}
      ${bar}
      <article class="forge-blob">
        <div class="forge-blob-bar"><span>${esc(blob.name)}</span><span>${blob.size || 0} bytes</span></div>
        ${body}
      </article>`;
    await fillBranches(route.branch);
  }

  async function renderIssues() {
    const issues = await api(`${ROOT}/issues?state=open&per_page=30`);
    const onlyIssues = issues.filter((i) => !i.pull_request);
    mount.innerHTML = `
      ${header(repoMeta, { tab: "issues" })}
      <p class="forge-load">${onlyIssues.length} open</p>
      <div class="forge-list">${
        onlyIssues.length
          ? onlyIssues
              .map(
                (i) => `<a href="#/issues">
            <div class="ttl">#${i.number} ${esc(i.title)}</div>
            <div class="meta">${esc(i.user.login)} · ${fmtDate(i.created_at)}</div>
          </a>`
              )
              .join("")
          : `<p class="forge-err" style="padding:1rem">No open issues.</p>`
      }</div>`;
  }

  async function renderPulls() {
    const pulls = await api(`${ROOT}/pulls?state=open&per_page=30`);
    mount.innerHTML = `
      ${header(repoMeta, { tab: "pulls" })}
      <p class="forge-load">${pulls.length} open</p>
      <div class="forge-list">${
        pulls.length
          ? pulls
              .map(
                (p) => `<a href="#/pulls">
            <div class="ttl">#${p.number} ${esc(p.title)}</div>
            <div class="meta">${esc(p.user.login)} · ${esc(p.head.ref)} → ${esc(p.base.ref)} · ${fmtDate(p.created_at)}</div>
          </a>`
              )
              .join("")
          : `<p class="forge-err" style="padding:1rem">No open pull requests.</p>`
      }</div>`;
  }

  async function renderCommits() {
    const commits = await api(`${ROOT}/commits?per_page=20`);
    mount.innerHTML = `
      ${header(repoMeta, { tab: "commits" })}
      <div class="forge-list">${commits
        .map(
          (c) => `<a href="#/tree/main">
          <div class="ttl">${esc(c.commit.message.split("\n")[0])}</div>
          <div class="meta">${esc(c.commit.author.name)} · ${esc(c.sha.slice(0, 7))} · ${fmtDate(c.commit.author.date)}</div>
        </a>`
        )
        .join("")}</div>`;
  }

  async function fillBranches(current) {
    const sel = document.getElementById("forge-branch");
    if (!sel) return;
    try {
      const branches = await api(`${ROOT}/branches?per_page=50`);
      sel.innerHTML = branches
        .map((b) => `<option value="${esc(b.name)}"${b.name === current ? " selected" : ""}>${esc(b.name)}</option>`)
        .join("");
      sel.onchange = () => {
        const route = parseHash();
        location.hash = href(route.kind || "tree", sel.value, route.path || "");
      };
    } catch {
      sel.innerHTML = `<option>${esc(current)}</option>`;
    }
  }

  function bindClone() {
    const btn = document.getElementById("forge-copy");
    const input = document.getElementById("forge-clone");
    if (!btn || !input) return;
    btn.onclick = async () => {
      try {
        await navigator.clipboard.writeText(input.value);
        btn.textContent = "Copied";
        setTimeout(() => (btn.textContent = "Copy"), 1200);
      } catch {
        input.select();
      }
    };
  }

  async function render() {
    if (!mount) return;
    mount.innerHTML = `<p class="forge-load">Setting type… fetching the tree from GitHub.</p>`;
    try {
      if (!repoMeta) repoMeta = await api(ROOT);
      const route = parseHash();
      if (route.tab === "issues") return renderIssues();
      if (route.tab === "pulls") return renderPulls();
      if (route.tab === "commits") return renderCommits();
      if (route.kind === "blob" && route.path) return renderBlob(route);
      return renderTree(route);
    } catch (err) {
      mount.innerHTML = `<p class="forge-err">${esc(err.message)}</p>
        <p class="forge-err">The paper still holds. Try the journal while the forge cools.</p>`;
    }
  }

  if (!location.hash || location.hash === "#") location.hash = "#/tree/main";
  window.addEventListener("hashchange", render);
  render();
})();
