/**
 * Homepage opcode sweep pair — both clips visible; tap expands via media-lightbox.js.
 */
(function () {
  "use strict";

  function init() {
    var reduce = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
    var clips = Array.prototype.slice.call(
      document.querySelectorAll(".compiler-reels video, .assembly-bench video, .two-up--sweeps video")
    );

    function kick(el) {
      if (!el) return;
      el.muted = true;
      el.defaultMuted = true;
      el.loop = true;
      el.playsInline = true;
      el.setAttribute("playsinline", "");
      if (el.preload === "none") el.preload = "metadata";
      try {
        el.load();
      } catch (e) {}
      var p = el.play();
      if (p && typeof p.catch === "function") p.catch(function () {});
    }

    function kickHero(el) {
      if (!el) return;
      el.muted = true;
      el.defaultMuted = true;
      el.loop = false;
      el.playsInline = true;
      el.setAttribute("playsinline", "");
      el.preload = "metadata";
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
      document.querySelectorAll(".verify-hero-video").forEach(kickHero);
    } else {
      clips.forEach(kick);
      document.querySelectorAll(".verify-hero-video").forEach(kickHero);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
