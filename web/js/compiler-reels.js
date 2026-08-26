/**
 * Homepage opcode sweep pair — both clips visible; click expands.
 */
(function () {
  "use strict";

  var root = null;
  var lightbox = null;
  var stage = null;
  var figures = [];

  function $(sel, el) {
    return (el || document).querySelector(sel);
  }

  function ensureLightbox() {
    if (lightbox) return;
    lightbox = document.createElement("div");
    lightbox.className = "compiler-lightbox";
    lightbox.hidden = true;
    lightbox.innerHTML =
      '<div class="compiler-lightbox__veil" data-close></div>' +
      '<div class="compiler-lightbox__panel" role="dialog" aria-modal="true">' +
      '  <button type="button" class="compiler-lightbox__close" data-close aria-label="Close">&times;</button>' +
      '  <div class="compiler-lightbox__stage"></div>' +
      "</div>";
    document.body.appendChild(lightbox);
    stage = $(".compiler-lightbox__stage", lightbox);

    lightbox.addEventListener("click", function (e) {
      if (e.target.closest("[data-close]")) closeLightbox();
    });
  }

  function openLightbox(fig) {
    ensureLightbox();
    var src = fig.getAttribute("data-src");
    var poster = fig.getAttribute("data-poster") || "";
    if (!src || !stage) return;

    var vid = document.createElement("video");
    vid.src = src;
    vid.poster = poster;
    vid.controls = true;
    vid.autoplay = true;
    vid.playsInline = true;
    vid.setAttribute("playsinline", "");
    vid.muted = true;
    vid.loop = true;

    stage.replaceChildren(vid);
    lightbox.hidden = false;
    document.documentElement.classList.add("is-compiler-open");
    $(".compiler-lightbox__close", lightbox).focus();
  }

  function closeLightbox() {
    if (!lightbox || lightbox.hidden) return;
    stage.querySelectorAll("video").forEach(function (v) {
      v.pause();
    });
    lightbox.hidden = true;
    document.documentElement.classList.remove("is-compiler-open");
  }

  function init() {
    root = $(".compiler-reels");
    if (root) {
      figures = Array.prototype.slice.call(root.querySelectorAll(".figure"));
      figures.forEach(function (fig) {
        fig.addEventListener("click", function (e) {
          e.preventDefault();
          openLightbox(fig);
        });
      });
    }

    var reduce = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
    var clips = Array.prototype.slice.call(
      document.querySelectorAll(".compiler-reels video, .assembly-bench video")
    );

    function kick(el) {
      if (!el) return;
      el.muted = true;
      el.defaultMuted = true;
      el.loop = true;
      el.playsInline = true;
      el.setAttribute("playsinline", "");
      el.preload = "auto";
      var p = el.play();
      if (p && typeof p.catch === "function") p.catch(function () {});
    }

    if (reduce) {
      clips.forEach(function (el) {
        el.pause();
        el.preload = "none";
      });
    } else if ("IntersectionObserver" in window) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) kick(entry.target);
          else entry.target.pause();
        });
      }, { rootMargin: "80px", threshold: 0.15 });
      clips.forEach(function (el) {
        io.observe(el);
      });
    } else {
      clips.forEach(kick);
    }

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") closeLightbox();
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
