/* Paper / Black stock. Runs before paint if the head snippet set data-theme. */
(function () {
  const KEY = "tomato.theme";
  const PAPER = "#f4f0e6";
  const BLACK = "#050505";

  function systemMode() {
    return typeof matchMedia === "function" && matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }

  function swapSrc(el, dark) {
    const src = el.getAttribute("src") || "";
    const next = dark
      ? src.replace(/mark\.svg(\?.*)?$/, "mark-dark.svg").replace(/dip\.svg(\?.*)?$/, "dip-dark.svg").replace(/slice\.svg(\?.*)?$/, "slice-dark.svg")
      : src.replace(/mark-dark\.svg(\?.*)?$/, "mark.svg").replace(/dip-dark\.svg(\?.*)?$/, "dip.svg").replace(/slice-dark\.svg(\?.*)?$/, "slice.svg");
    if (next !== src) el.setAttribute("src", next);
  }

  let leadGen = 0;

  function lead(dark) {
    const paper = document.getElementById("lead-spin");
    const night = document.getElementById("lead-night");
    if (!paper && !night) return;
    const reduce = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
    const gen = ++leadGen;

    function stop(el) {
      if (!el || typeof el.pause !== "function") return;
      el.removeAttribute("autoplay");
      el.preload = "none";
      el.pause();
    }

    function play(el) {
      if (!el || typeof el.play !== "function") return;
      el.muted = true;
      el.defaultMuted = true;
      el.playsInline = true;
      el.setAttribute("playsinline", "");
      el.setAttribute("webkit-playsinline", "");
      el.preload = "auto";
      el.setAttribute("autoplay", "");
      try { el.fetchPriority = "high"; } catch {}

      const kick = () => {
        if (gen !== leadGen) return;
        const p = el.play();
        if (p && typeof p.catch === "function") p.catch(() => {});
      };

      el.addEventListener("canplay", kick, { once: true });
      el.addEventListener("loadeddata", kick, { once: true });
      if (el.readyState < 2 && el.networkState !== 2) {
        try { el.load(); } catch {}
      }
      kick();
      requestAnimationFrame(kick);
      setTimeout(kick, 280);
      setTimeout(kick, 1200);
    }

    if (reduce) {
      stop(paper);
      stop(night);
      return;
    }
    if (dark) {
      stop(paper);
      play(night);
    } else {
      stop(night);
      play(paper);
    }
  }

  function apply(mode, lock) {
    const dark = mode === "dark";
    if (lock) document.documentElement.setAttribute("data-theme", mode);
    else document.documentElement.removeAttribute("data-theme");
    document.documentElement.style.colorScheme = mode;
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.content = dark ? BLACK : PAPER;
    document.querySelectorAll('img[src*="mark"], img[src*="dip"], img[src*="slice"]').forEach((img) => swapSrc(img, dark));
    lead(dark);
    document.querySelectorAll("[data-theme-set]").forEach((btn) => {
      btn.classList.toggle("is-on", btn.getAttribute("data-theme-set") === mode);
    });
  }

  let painted = false;
  function paint() {
    let mode;
    let lock = false;
    try {
      const saved = localStorage.getItem(KEY);
      if (saved === "dark" || saved === "light") {
        mode = saved;
        lock = true;
      }
    } catch {}
    if (!mode) mode = systemMode();
    const html = document.documentElement;
    const wasLock = html.hasAttribute("data-theme");
    const current = wasLock ? html.getAttribute("data-theme") : html.style.colorScheme;
    if (painted && lock === wasLock && current === mode) return;
    painted = true;
    apply(mode, lock);
  }

  function set(mode) {
    try {
      if (mode === systemMode()) localStorage.removeItem(KEY);
      else localStorage.setItem(KEY, mode);
    } catch {}
    paint();
  }

  function wireSwitch(nav) {
    if (!nav || nav.querySelector(".theme-switch")) return;
    const box = document.createElement("div");
    box.className = "theme-switch";
    box.setAttribute("role", "group");
    box.setAttribute("aria-label", "Paper color");
    box.innerHTML =
      '<button type="button" data-theme-set="light">Paper</button>' +
      '<button type="button" data-theme-set="dark">Black</button>';
    box.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-theme-set]");
      if (!btn) return;
      set(btn.getAttribute("data-theme-set"));
    });
    nav.append(box);
  }

  wireSwitch(document.querySelector(".mast-nav"));
  paint();

  const scheme = typeof matchMedia === "function" ? matchMedia("(prefers-color-scheme: dark)") : null;
  function onSystem() {
    try { localStorage.removeItem(KEY); } catch {}
    paint();
  }
  if (scheme) {
    if (scheme.addEventListener) scheme.addEventListener("change", onSystem);
    else if (scheme.addListener) scheme.addListener(onSystem);
  }
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) paint();
  });
  window.addEventListener("focus", () => paint());
})();

/* Mobile mast: hamburger on the right, drawer from the same side. */
(function () {
  const mast = document.querySelector(".mast");
  const nav = document.querySelector(".mast-nav");
  const nameplate = document.querySelector(".nameplate");
  if (!mast || !nav || !nameplate || nameplate.querySelector(".mast-burger")) return;

  if (!nav.id) nav.id = "mast-nav";

  const mq = window.matchMedia("(max-width: 860px)");
  let btn;
  let veil;

  function wire() {
    if (btn) return;

    btn = document.createElement("button");
    btn.type = "button";
    btn.className = "mast-burger";
    btn.setAttribute("aria-controls", nav.id);
    btn.setAttribute("aria-expanded", "false");
    btn.setAttribute("aria-label", "Open menu");
    btn.innerHTML = "<span></span><span></span><span></span>";

    veil = document.createElement("div");
    veil.className = "mast-veil";
    veil.hidden = true;

    nameplate.append(btn);
    document.body.append(veil);

    btn.addEventListener("click", () => {
      setOpen(!document.documentElement.classList.contains("is-nav-open"));
    });
    veil.addEventListener("click", () => setOpen(false));
    nav.addEventListener("click", (e) => {
      if (e.target.closest("a")) setOpen(false);
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") setOpen(false);
    });
  }

  function placeNav() {
    if (mq.matches) {
      wire();
      document.body.append(nav);
      nav.setAttribute("inert", "");
    } else {
      mast.append(nav);
      nav.removeAttribute("inert");
    }
  }

  function setOpen(open) {
    document.documentElement.classList.toggle("is-nav-open", open);
    if (btn) {
      btn.setAttribute("aria-expanded", String(open));
      btn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    }
    if (veil) veil.hidden = !open;
    if (mq.matches) nav.toggleAttribute("inert", !open);
    else nav.removeAttribute("inert");
  }

  const onBreak = () => {
    setOpen(false);
    placeNav();
  };
  if (mq.addEventListener) mq.addEventListener("change", onBreak);
  else mq.addListener(onBreak);

  placeNav();
})();

(function () {
  if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  ["lead-spin", "lead-night"].forEach((id) => {
    const clip = document.getElementById(id);
    if (!clip || typeof clip.pause !== "function") return;
    clip.removeAttribute("autoplay");
    clip.pause();
  });
})();
