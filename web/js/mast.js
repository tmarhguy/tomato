/* Paper / Black stock. Runs before paint if the head snippet set data-theme. */
(function () {
  const KEY = "tomato.theme";
  const PAPER = "#f5f5f0";
  const BLACK = "#050505";

  function systemMode() {
    return typeof matchMedia === "function" && matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }

  function defaultMode() {
    /* Sitewide dark-first — Paper is an explicit choice */
    return "dark";
  }

  function pathPrefix() {
    const script = document.querySelector('script[src*="mast.js"]');
    const src = (script && script.getAttribute("src")) || "";
    if (src.startsWith("../")) return "../";
    const home = document.querySelector('.mast-nav a[href$="index.html"], .mast-nav a[href*="/index.html"]');
    const href = home && home.getAttribute("href");
    if (href && href.startsWith("../")) return "../";
    return "";
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
    const lcp = document.getElementById("lead-lcp");
    const shell = (paper || night) && (paper || night).closest(".lead-gif");
    if (!paper && !night) return;
    const reduce = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
    const gen = ++leadGen;

    if (lcp) {
      if (dark) {
        lcp.src = "assets/gallery/pcb/immersion_black-640w.webp";
        lcp.srcset =
          "assets/gallery/pcb/immersion_black-640w.webp 640w, assets/gallery/pcb/immersion_black-1280w.webp 1280w, assets/pcb/immersion_black.webp 960w";
      } else {
        lcp.src = "assets/gallery/pcb/hero-640w.webp";
        lcp.srcset =
          "assets/gallery/pcb/hero-640w.webp 640w, assets/gallery/pcb/hero-1280w.webp 1280w, assets/pcb/hero.webp 960w";
      }
    }

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
      try { el.fetchPriority = "low"; } catch {}

      const kick = () => {
        if (gen !== leadGen) return;
        const p = el.play();
        if (p && typeof p.then === "function") {
          p.then(() => {
            if (shell && gen === leadGen) shell.classList.add("is-live");
          }).catch(() => {});
        } else if (p && typeof p.catch === "function") {
          p.catch(() => {});
        }
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

    if (shell) shell.classList.remove("is-live");

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

  function apply(mode) {
    const dark = mode === "dark";
    document.documentElement.setAttribute("data-theme", mode);
    document.documentElement.style.colorScheme = mode;
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.content = dark ? BLACK : PAPER;
    document.querySelectorAll('img[src*="mark"], img[src*="dip"], img[src*="slice"]').forEach((img) => swapSrc(img, dark));
    lead(dark);
    document.querySelectorAll("[data-theme-set]").forEach((btn) => {
      btn.classList.toggle("is-on", btn.getAttribute("data-theme-set") === mode);
    });
    document.querySelectorAll("[data-theme-toggle]").forEach((btn) => {
      btn.hidden = false;
      btn.textContent = dark ? "Light mode" : "Dark mode";
      btn.setAttribute("aria-label", dark ? "Switch to light theme" : "Switch to dark theme");
    });
    try {
      document.dispatchEvent(new CustomEvent("tomato:theme", { detail: { mode } }));
    } catch {}
  }

  document.addEventListener("click", (e) => {
    if (e.target.closest("[data-theme-toggle]")) {
      const currentMode = document.documentElement.getAttribute("data-theme") || defaultMode();
      set(currentMode === "dark" ? "light" : "dark");
    }
  });

  function paint() {
    let mode = document.documentElement.getAttribute("data-theme") || defaultMode();
    try {
      const saved = localStorage.getItem(KEY);
      if (saved === "dark" || saved === "light") mode = saved;
    } catch {}
    apply(mode);
  }

  function set(mode) {
    try {
      localStorage.setItem(KEY, mode);
    } catch {}
    apply(mode);
  }

  function bindThemeSwitch(box) {
    if (!box || box.dataset.themeWired === "1") return;
    box.dataset.themeWired = "1";
    box.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-theme-set]");
      if (!btn) return;
      set(btn.getAttribute("data-theme-set"));
    });
  }

  function wireSwitch(host) {
    if (!host) return;
    let box = host.querySelector(".theme-switch");
    if (!box) {
      box = document.createElement("div");
      box.className = "theme-switch";
      box.setAttribute("role", "group");
      box.setAttribute("aria-label", "Color theme");
      box.innerHTML =
        '<button type="button" data-theme-toggle aria-label="Switch to light theme">Light mode</button>';
      host.append(box);
    }
    bindThemeSwitch(box);
  }

  function currentPath() {
    try {
      return (location.pathname || "").replace(/\/+$/, "") || "/";
    } catch {
      return "";
    }
  }

  function linkCurrent(href) {
    const path = currentPath();
    const leaf = href.split("/").pop() || "";
    if (!leaf) return false;
    if (leaf === "index.html") return /(?:^|\/)(index\.html)?$/.test(path) || path.endsWith("/web");
    return path.endsWith("/" + leaf) || path.endsWith(leaf);
  }

  function shellStatusHtml() {
    return "";
  }

  /** Full site map — mobile drawer */
  const SITE_NAV = [
    { href: "index.html", label: "Front" },
    { href: "architecture.html", label: "Architecture" },
    { href: "software.html", label: "Software" },
    { href: "os.html", label: "Tomato OS" },
    { href: "playground.html", label: "Playground" },
    { href: "isa.html", label: "ISA" },
    { href: "journal.html", label: "Journal" },
    { href: "gallery.html", label: "Gallery" },
    { href: "about.html", label: "About" },
    { href: "viewer.html", label: "Tour the board", tour: true },
  ];

  /** Secondary — drawer footer row (verification, catalog, source) */
  const SITE_NAV_MORE = [
    { href: "verification.html", label: "Verification" },
    { href: "boards.html", label: "Catalog" },
    { href: "source.html", label: "GitHub" },
  ];

  /** Desktop bottom dock — single scrollable row */
  const DOCK_NAV = [
    { href: "index.html", label: "Front", short: "Home" },
    { href: "architecture.html", label: "Architecture", short: "Arch" },
    { href: "software.html", label: "Software", short: "Soft" },
    { href: "os.html", label: "Tomato OS", short: "OS" },
    { href: "playground.html", label: "Playground", short: "Play" },
    { href: "isa.html", label: "ISA", short: "ISA" },
    { href: "journal.html", label: "Journal", short: "Jrnl" },
    { href: "gallery.html", label: "Gallery", short: "Gall" },
    { href: "about.html", label: "About", short: "About" },
    { href: "viewer.html", label: "Tour the board", short: "Tour", tour: true },
    { href: "verification.html", label: "Verification", short: "Verify" },
    { href: "boards.html", label: "Catalog", short: "Cat" },
    { href: "source.html", label: "GitHub", short: "Git" },
  ];

  const SHELL_LINKS = [
    { href: "index.html#what-is-tomato", label: "The idea" },
    { href: "index.html#running", label: "See it run" },
    { href: "architecture.html", label: "Engineering" },
    { href: "journal.html", label: "Build journal" },
  ];

  const MOBILE_NAV_MQ = typeof matchMedia === "function" ? matchMedia("(max-width: 860px)") : null;

  function navLink(prefix, item, opts) {
    const options = opts || {};
    const href = prefix + item.href;
    const cur = linkCurrent(item.href) ? ' aria-current="page"' : "";
    const cls = item.tour ? ' class="is-tour"' : "";
    const short = item.short || item.label;
    if (options.dock) {
      return (
        '<a href="' + href + '"' + cls + cur + ">" +
        '<span class="site-dock__long">' + item.label + "</span>" +
        '<span class="site-dock__short">' + short + "</span>" +
        "</a>"
      );
    }
    return '<a href="' + href + '"' + cls + cur + ">" + item.label + "</a>";
  }

  function dockLink(prefix, item) {
    return navLink(prefix, item, { dock: true });
  }

  function dockNavHtml(prefix, items) {
    const nav = items || DOCK_NAV;
    return (
      '<nav class="site-dock mast-nav landing-dock" id="mast-nav" aria-label="Site">' +
      '<div class="site-dock__track">' +
      nav.map((item) => dockLink(prefix, item)).join("") +
      "</div></nav>"
    );
  }

  function shellLinksHtml(prefix) {
    const links = SHELL_LINKS.map((item) => {
      const href = prefix + item.href;
      const cur = linkCurrent(item.href) ? ' aria-current="page"' : "";
      const cls = item.tour ? ' class="is-tour"' : "";
      return "<a href=\"" + href + "\"" + cls + cur + ">" + item.label + "</a>";
    }).join("");
    return '<nav class="site-bar-links" aria-label="Shortcuts">' + links + "</nav>";
  }

  function ensureShellExtras(nav, prefix) {
    if (!nav || nav.querySelector(".site-bar-links")) return;

    let left = nav.querySelector(".site-bar-left");
    if (!left) {
      left = document.createElement("div");
      left.className = "site-bar-left";
      const brand = nav.querySelector(".landing-brand, .site-brand, a.nameplate");
      if (brand) left.append(brand);
      nav.prepend(left);
    }

    const theme = nav.querySelector(".theme-switch");
    const linksHtml = shellLinksHtml(prefix);
    if (theme) theme.insertAdjacentHTML("beforebegin", linksHtml);
    else nav.insertAdjacentHTML("beforeend", linksHtml);
  }

  /* Inject landing-style top shell on every non-landing page. */
  (function injectShell() {
    if (document.querySelector(".project-nav")) return;
    const prefix = pathPrefix();
    const existingNav = document.querySelector(
      ".landing-shell .landing-nav, .site-shell .landing-nav, .site-shell .site-nav, .page--landing .landing-nav"
    );

    if (document.querySelector(".page--landing") || document.querySelector(".landing-shell, .site-shell")) {
      document.documentElement.classList.add("has-site-shell");
      if (existingNav) ensureShellExtras(existingNav, prefix);
      queueShellHeight();
      return;
    }
    if (!document.querySelector(".mast-nav") && !document.querySelector(".page")) return;

    const page = document.querySelector(".page") || document.body;
    const shell = document.createElement("div");
    shell.className = "landing-shell site-shell";
      shell.innerHTML =
      '<header class="landing-nav site-nav wrap">' +
      '<div class="site-bar-left">' +
      '<a class="landing-brand site-brand nameplate" href="' + prefix + 'index.html">' +
      '<img src="' + prefix + 'assets/mark.svg" alt="" width="52" height="61" />' +
      "<h1>Tomato</h1>" +
      "</a>" +
      "</div>" +
      shellLinksHtml(prefix) +
      "</header>";
    page.prepend(shell);
    page.classList.add("page--site");
    document.documentElement.classList.add("has-site-shell");
    queueShellHeight();
  })();

  /* Sticky bottom site nav — one canonical dock on every page. */
  (function pinDock() {
    if (document.querySelector(".project-nav")) return;
    const prefix = pathPrefix();
    let nav = document.getElementById("mast-nav");
    const headerNav = document.querySelector("header.wrap .mast-nav");

    if (headerNav && headerNav !== nav) {
      const mast = headerNav.closest(".mast");
      if (mast) {
        mast.hidden = true;
        mast.setAttribute("aria-hidden", "true");
      }
      headerNav.remove();
    }

    if (!nav) {
      nav = document.querySelector(".mast-nav:not(header.wrap .mast-nav)");
    }

    if (!nav) {
      document.body.insertAdjacentHTML("beforeend", dockNavHtml(prefix));
      nav = document.getElementById("mast-nav");
    }

    document.documentElement.classList.add("has-site-dock");

    const themeHost =
      document.querySelector(".site-shell .landing-nav, .site-shell .site-nav") ||
      document.querySelector(".landing-nav") ||
      document.querySelector(".landing-brand") ||
      document.querySelector(".nameplate");
    if (themeHost) {
      wireSwitch(themeHost);
    } else if (nav) {
      wireSwitch(nav);
    }

    syncDockHeight();
    wireMobileNav(prefix);
    queueShellHeight();
  })();

  function wireMobileNav(prefix) {
    const shellNav =
      document.querySelector(".site-shell .landing-nav") ||
      document.querySelector(".site-shell .site-nav");
    if (!shellNav) return;

    let toggle = shellNav.querySelector(".site-nav-toggle");
    if (!toggle) {
      toggle = document.createElement("button");
      toggle.type = "button";
      toggle.className = "site-nav-toggle";
      toggle.setAttribute("aria-label", "Open menu");
      toggle.setAttribute("aria-expanded", "false");
      toggle.setAttribute("aria-controls", "site-nav-drawer");
      toggle.innerHTML = "<span></span><span></span><span></span>";

      const theme = shellNav.querySelector(".theme-switch");
      if (theme) shellNav.insertBefore(toggle, theme);
      else shellNav.appendChild(toggle);
    }

    if (document.getElementById("site-nav-drawer")) return;

    const veil = document.createElement("div");
    veil.className = "site-nav-veil";
    veil.hidden = true;

    const drawer = document.createElement("nav");
    drawer.id = "site-nav-drawer";
    drawer.className = "site-nav-drawer";
    drawer.setAttribute("aria-label", "Site");
    drawer.hidden = true;
    drawer.innerHTML =
      SITE_NAV.map((item) => navLink(prefix, item)).join("") +
      '<p class="site-nav-drawer__more-label">Also</p>' +
      SITE_NAV_MORE.map((item) => navLink(prefix, item)).join("");

    const closeMenu = document.createElement("button");
    closeMenu.type = "button";
    closeMenu.className = "site-menu-close";
    closeMenu.textContent = "Close menu ×";
    closeMenu.addEventListener("click", () => { close(); toggle.focus(); });
    drawer.prepend(closeMenu);

    document.body.appendChild(veil);
    document.body.appendChild(drawer);

    function setOpen(open) {
      document.documentElement.classList.toggle("is-site-nav-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
      toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
      drawer.hidden = !open;
      veil.hidden = !open;
    }

    function close() {
      setOpen(false);
    }

    toggle.addEventListener("click", () => {
      setOpen(!document.documentElement.classList.contains("is-site-nav-open"));
    });
    veil.addEventListener("click", close);
    drawer.addEventListener("click", (e) => {
      if (e.target.closest("a[href]")) close();
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") close();
    });

    if (MOBILE_NAV_MQ) {
      const onMq = () => {
        close();
        syncDockHeight();
        syncShellHeight();
      };
      if (MOBILE_NAV_MQ.addEventListener) MOBILE_NAV_MQ.addEventListener("change", onMq);
      else if (MOBILE_NAV_MQ.addListener) MOBILE_NAV_MQ.addListener(onMq);
    }
  }

  function syncShellHeight() {
    const shell = document.querySelector(".site-shell, .landing-shell");
    if (!shell) return;
    const h = Math.ceil(shell.getBoundingClientRect().bottom);
    if (h > 0) {
      document.documentElement.style.setProperty("--site-shell-h", `${h}px`);
    }
  }

  function queueShellHeight() {
    syncShellHeight();
    requestAnimationFrame(syncShellHeight);
  }

  function syncDockHeight() {
    const dock = document.getElementById("mast-nav");
    if (!dock) return;
    if (MOBILE_NAV_MQ && MOBILE_NAV_MQ.matches) {
      document.documentElement.style.setProperty("--site-dock-h", "0px");
      return;
    }
    const h = Math.ceil(dock.getBoundingClientRect().height);
    if (h > 0) {
      document.documentElement.style.setProperty("--site-dock-h", `${h}px`);
    }
  }

  let chromeResizeTimer = 0;
  window.addEventListener(
    "resize",
    () => {
      window.clearTimeout(chromeResizeTimer);
      chromeResizeTimer = window.setTimeout(() => {
        syncDockHeight();
        syncShellHeight();
      }, 80);
    },
    { passive: true }
  );

  function wireExternalLinks(root) {
    const scope = root || document;
    scope.querySelectorAll("a[href]").forEach((a) => {
      const href = a.getAttribute("href");
      if (!href) return;
      const trimmed = href.trim();
      if (
        trimmed.startsWith("#") ||
        trimmed.startsWith("/") ||
        trimmed.startsWith("./") ||
        trimmed.startsWith("../") ||
        trimmed.startsWith("mailto:") ||
        trimmed.startsWith("tel:") ||
        trimmed.startsWith("javascript:")
      ) {
        return;
      }
      if (!/^https?:/i.test(trimmed)) return;
      let external = false;
      try {
        external = new URL(trimmed, location.href).origin !== location.origin;
      } catch {
        return;
      }
      if (!external) return;
      if (!a.target || a.target === "_self") a.target = "_blank";
      const rel = new Set((a.getAttribute("rel") || "").split(/\s+/).filter(Boolean));
      rel.add("noopener");
      rel.add("noreferrer");
      a.rel = [...rel].join(" ");
    });
  }

  document.querySelectorAll(".theme-switch").forEach(bindThemeSwitch);
  if (!document.querySelector(".theme-switch")) {
    wireSwitch(
      document.querySelector(".site-shell .landing-nav, .landing-nav") ||
        document.querySelector(".mast-nav") ||
        document.querySelector(".mast") ||
        document.querySelector(".nameplate")
    );
  }

  paint();
  queueShellHeight();
  window.addEventListener("load", queueShellHeight, { once: true });

  const scheme = typeof matchMedia === "function" ? matchMedia("(prefers-color-scheme: dark)") : null;
  function onSystem(event) {
    // Phone / OS appearance toggle should drive the site the same way the in-page control does.
    const mode = event && typeof event.matches === "boolean"
      ? (event.matches ? "dark" : "light")
      : systemMode();
    set(mode);
  }
  if (scheme) {
    if (scheme.addEventListener) scheme.addEventListener("change", onSystem);
    else if (scheme.addListener) scheme.addListener(onSystem);
  }
  window.addEventListener("storage", (event) => {
    if (event.key !== KEY) return;
    if (event.newValue === "dark" || event.newValue === "light") apply(event.newValue);
    else paint();
  });
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) paint();
  });
  window.addEventListener("focus", () => paint());

  (function loadMediaLightbox() {
    if (document.querySelector('script[src*="media-lightbox.js"]')) return;
    const script = document.querySelector('script[src*="mast.js"]');
    const src = (script && script.getAttribute("src")) || "js/mast.js";
    const prefix = src.startsWith("../") ? "../" : "";
    const tag = document.createElement("script");
    tag.src = prefix + "js/media-lightbox.js";
    tag.onload = () => {
      if (window.tomatoMediaLightbox && typeof window.tomatoMediaLightbox.scan === "function") {
        window.tomatoMediaLightbox.scan();
      }
    };
    document.head.appendChild(tag);
  })();

  wireExternalLinks(document);
})();

(function () {
  if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  ["lead-spin", "lead-night"].forEach((id) => {
    const el = document.getElementById(id);
    if (el && typeof el.pause === "function") {
      el.removeAttribute("autoplay");
      el.pause();
    }
  });
  document.querySelectorAll(".ambient-video, .verify-hero-video").forEach((el) => {
    if (typeof el.pause !== "function") return;
    el.removeAttribute("autoplay");
    el.preload = "none";
    el.pause();
  });
})();
