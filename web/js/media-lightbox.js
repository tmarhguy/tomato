/**
 * Site-wide tap-to-enlarge for figures, plates, hero media, and content photos.
 * Loaded by mast.js on every page with the shell.
 */
(function () {
  "use strict";

  var lightbox = null;
  var stage = null;
  var lastOpen = 0;

  var EXCLUDE =
    ".gallery-carousel, .gallery-slides, .gallery-frame, .gallery-filmstrip, .gallery-lightbox, " +
    ".compiler-lightbox, .lead-gif, .landing-lead-media, .landing-hero__viewer, " +
    ".bench--hero, .contact-icons, .nameplate, .landing-brand, .site-brand, " +
    ".mast-nav, .site-dock, .site-bar, .arch-map, .playground, .theme-switch, .ads-sheet, " +
    ".shield, .works-track, .pager, .site-shell__links";

  var CONTENT_ROOT = "main, .landing-reveal, .site-prose, article, .wrap";

  function $(sel, el) {
    return (el || document).querySelector(sel);
  }

  function isDecorative(src) {
    return /(?:mark|dip|slice|favicon)(?:-dark)?\.(?:svg|webp|png)/i.test(src || "") ||
      /img\.shields\.io/i.test(src || "");
  }

  function isExcluded(el) {
    if (!el || !(el instanceof Element)) return true;
    if (el.closest(EXCLUDE)) return true;
    if (el.closest(".site-brand, .landing-brand, .nameplate, .theme-switch")) return true;
    if (el.tagName === "IMG" && isDecorative(el.getAttribute("src") || el.currentSrc || "")) return true;
    return false;
  }

  function inContent(el) {
    return !!(el && el.closest(CONTENT_ROOT));
  }

  function bestSrc(img) {
    if (!img) return "";
    var srcset = img.getAttribute("srcset");
    if (srcset) {
      var best = "";
      var bestW = 0;
      srcset.split(",").forEach(function (part) {
        var bits = part.trim().split(/\s+/);
        var url = bits[0];
        var w = bits[1] ? parseInt(bits[1], 10) : 0;
        if (!best || w > bestW) {
          best = url;
          bestW = w;
        }
      });
      if (best) return best;
    }
    var src = img.currentSrc || img.getAttribute("src") || "";
    if (/-\d+w\.webp$/i.test(src)) {
      var hi = src.replace(/-\d+w\.webp$/i, "-1280w.webp");
      if (hi !== src) return hi;
    }
    return src;
  }

  function mediaPack(host) {
    if (!host || isExcluded(host)) return null;

    if (host.hasAttribute("data-src")) {
      return {
        type: "video",
        src: host.getAttribute("data-src") || "",
        poster: host.getAttribute("data-poster") || "",
        alt: host.getAttribute("aria-label") || "",
      };
    }

    var video = host.matches("video") ? host : host.querySelector("video");
    if (video && !isExcluded(video)) {
      var source = video.querySelector("source");
      return {
        type: "video",
        src: video.currentSrc || (source && source.getAttribute("src")) || video.getAttribute("src") || "",
        poster: video.getAttribute("poster") || "",
        alt: video.getAttribute("aria-label") || "",
      };
    }

    var img = host.matches("img") ? host : host.querySelector("img");
    if (img && !isDecorative(img.getAttribute("src") || img.currentSrc || "")) {
      return {
        type: "image",
        src: bestSrc(img),
        alt: img.getAttribute("alt") || "",
      };
    }

    return null;
  }

  function shotHost(el) {
    return el.closest(
      "figure, .figure, .plate, .ad-face-shot, .alu-compare__shot, .sweep-media, " +
        ".assembly-bench .figure, .compiler-reels .figure, .site-hero__media"
    );
  }

  function resolveTarget(el) {
    if (!el || !(el instanceof Element)) return null;
    if (el.matches("img, video")) {
      if (isExcluded(el)) return null;
      if (!inContent(el) && !shotHost(el)) return null;
      return el;
    }
    var host = shotHost(el);
    if (!host || isExcluded(host)) return null;
    if (!inContent(host) && !host.closest(".site-hero, .landing-reveal")) return null;
    var media = host.querySelector("img, video");
    return media && !isExcluded(media) ? media : null;
  }

  function ensureLightbox() {
    if (lightbox) return;
    lightbox = document.createElement("div");
    lightbox.className = "compiler-lightbox media-lightbox";
    lightbox.hidden = true;
    lightbox.innerHTML =
      '<div class="compiler-lightbox__veil" data-close></div>' +
      '<div class="compiler-lightbox__panel" role="dialog" aria-modal="true" aria-label="Expanded media">' +
      '  <button type="button" class="compiler-lightbox__close" data-close aria-label="Close">&times;</button>' +
      '  <div class="compiler-lightbox__stage"></div>' +
      "</div>";
    document.body.appendChild(lightbox);
    stage = $(".compiler-lightbox__stage", lightbox);

    lightbox.addEventListener("click", function (e) {
      if (e.target.closest("[data-close]")) closeLightbox();
    });

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") closeLightbox();
    });
  }

  function openLightbox(media) {
    if (!media || !media.src) return;
    var now = Date.now();
    if (now - lastOpen < 200) return;
    lastOpen = now;
    ensureLightbox();
    stage.replaceChildren();

    if (media.type === "video") {
      var vid = document.createElement("video");
      vid.src = media.src;
      vid.poster = media.poster || "";
      vid.controls = true;
      vid.autoplay = true;
      vid.playsInline = true;
      vid.setAttribute("playsinline", "");
      vid.setAttribute("webkit-playsinline", "");
      vid.muted = true;
      vid.loop = true;
      if (media.alt) vid.setAttribute("aria-label", media.alt);
      stage.appendChild(vid);
    } else {
      var image = document.createElement("img");
      image.src = media.src;
      image.alt = media.alt || "";
      image.decoding = "async";
      stage.appendChild(image);
    }

    lightbox.hidden = false;
    document.documentElement.classList.add("is-media-open", "is-compiler-open");
    var close = $(".compiler-lightbox__close", lightbox);
    if (close) close.focus();
  }

  function closeLightbox() {
    if (!lightbox || lightbox.hidden) return;
    stage.querySelectorAll("video").forEach(function (v) {
      v.pause();
    });
    stage.replaceChildren();
    lightbox.hidden = true;
    document.documentElement.classList.remove("is-media-open", "is-compiler-open");
  }

  function packForMedia(mediaEl) {
    if (!mediaEl) return null;
    if (mediaEl.matches("video")) {
      var source = mediaEl.querySelector("source");
      return {
        type: "video",
        src: mediaEl.currentSrc || (source && source.getAttribute("src")) || mediaEl.getAttribute("src") || "",
        poster: mediaEl.getAttribute("poster") || "",
        alt: mediaEl.getAttribute("aria-label") || "",
      };
    }
    if (mediaEl.matches("img")) {
      return {
        type: "image",
        src: bestSrc(mediaEl),
        alt: mediaEl.getAttribute("alt") || "",
      };
    }
    var host = shotHost(mediaEl) || mediaEl;
    return mediaPack(host);
  }

  function shouldExpand(mediaEl) {
    if (!mediaEl || isExcluded(mediaEl)) return false;
    if (!inContent(mediaEl) && !mediaEl.closest(".site-hero, .landing-reveal")) return false;
    var pack = packForMedia(mediaEl);
    return !!(pack && pack.src);
  }

  function markExpandable(el) {
    var host = shotHost(el) || el;
    if (!host || host.dataset.mediaLb === "1") return;
    if (!shouldExpand(el)) return;
    host.dataset.mediaLb = "1";
    host.classList.add("is-media-expandable");
  }

  function onActivate(e) {
    if (lightbox && !lightbox.hidden) return;
    if (e.target.closest("button, [data-close], [data-step], .gallery-arrow, .theme-switch")) return;

    var mediaEl = resolveTarget(e.target);
    if (!mediaEl) return;

    var pack = packForMedia(mediaEl);
    if (!pack || !pack.src) return;

    var anchor = mediaEl.closest("a[href]");
    if (anchor && !shotHost(mediaEl)) return;

    e.preventDefault();
    e.stopPropagation();
    openLightbox(pack);
  }

  function scan() {
    document.querySelectorAll("img, video").forEach(function (el) {
      markExpandable(el);
    });
  }

  document.addEventListener("click", onActivate, true);

  window.tomatoMediaLightbox = {
    scan: scan,
    open: openLightbox,
    close: closeLightbox,
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", scan);
  } else {
    scan();
  }
})();
