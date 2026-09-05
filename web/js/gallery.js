/**
 * Gallery carousel — cover-flow stage, arrows, swipe, filmstrip, lightbox.
 */
(function () {
  "use strict";

  var SWIPE_PX = 28;
  var SWIPE_RATIO = 0.12;
  var AXIS_LOCK = 6;
  var FLICK_VX = 0.42; /* px/ms — quick flicks commit even with short travel */
  var FLICK_MIN_DX = 8;

  var root = null;
  var viewport = null;
  var track = null;
  var detail = null;
  var detailChapter = null;
  var detailDate = null;
  var detailTitle = null;
  var detailMeta = null;
  var detailFacts = null;
  var detailBody = null;
  var filmstrip = null;
  var counterCur = null;
  var lightbox = null;
  var lightboxStage = null;
  var lightboxPanel = null;
  var lightboxFigure = null;
  var lightboxCopy = null;

  var slides = [];
  var frames = [];
  var filmCells = [];
  var index = 0;
  var playlist = [];
  var filterChapter = "";
  var showTimer = null;
  var tabsRoot = null;
  var showBtn = null;
  var detailRaf = 0;
  var mediaSyncTimer = 0;

  var drag = {
    on: false,
    id: null,
    x0: 0,
    y0: 0,
    dx: 0,
    locked: false,
    swiped: false,
    lastX: 0,
    lastT: 0,
    vx: 0,
  };
  var tapFrame = null;
  var lbDrag = {
    on: false,
    id: null,
    x0: 0,
    y0: 0,
    dx: 0,
    locked: false,
    lastX: 0,
    lastT: 0,
    vx: 0,
  };
  var gapPx = 16;
  var trackBase = 0;
  var dragRaf = 0;
  var pendingDx = 0;
  var lbDragRaf = 0;
  var lbPendingDx = 0;

  function $(sel, el) {
    return (el || document).querySelector(sel);
  }

  function readSlide(el) {
    var rawSrc = el.getAttribute("data-src");
    var rawThumb = el.getAttribute("data-thumb") || rawSrc;
    var rawPoster = el.getAttribute("data-poster") || rawThumb;
    return {
      src: rawSrc,
      full: galleryVariant(rawSrc, 1280),
      display: galleryVariant(rawSrc, 640),
      type: el.getAttribute("data-type") || "image",
      thumb: galleryVariant(rawThumb, 128),
      rawThumb: rawThumb,
      poster: galleryVariant(rawPoster, 640),
      rawPoster: rawPoster,
      date: el.getAttribute("data-date") || "",
      title: el.getAttribute("data-title") || "",
      meta: el.getAttribute("data-meta") || "",
      chapter: el.getAttribute("data-chapter") || "",
      factsHtml: ($(".gallery-slide__facts", el) || {}).innerHTML || "",
      bodyHtml: ($(".gallery-slide__body", el) || {}).innerHTML || "",
    };
  }

  function galleryVariant(src, width) {
    if (!src || src.indexOf("assets/") !== 0 || /\.mp4$/i.test(src)) return src;
    var base = src.replace(/^assets\//, "").replace(/\.(webp|jpe?g|jpg|png)$/i, "");
    return "assets/gallery/" + base + "-" + width + "w.webp";
  }

  function bindOptimizedImage(img, primary, fallback, opts) {
    opts = opts || {};
    img.alt = opts.alt || "";
    img.decoding = "async";
    img.draggable = false;
    if (opts.deferSrc) {
      img.dataset.display = primary;
      if (fallback && fallback !== primary) img.dataset.fallback = fallback;
      return img;
    }
    img.src = primary;
    img.loading = opts.eager ? "eager" : "lazy";
    if (opts.eager && "fetchPriority" in img) img.fetchPriority = "high";
    if (fallback && fallback !== primary) {
      img.addEventListener("error", function onErr() {
        img.removeEventListener("error", onErr);
        img.src = fallback;
      }, { once: true });
    }
    return img;
  }

  function loadFrameImage(frame, slide) {
    var img = $("img", frame);
    if (!img || img.src) return;
    var primary = img.dataset.display || slide.display;
    var fallback = img.dataset.fallback || slide.src;
    img.src = primary;
    img.loading = "lazy";
    if (fallback && fallback !== primary) {
      img.addEventListener("error", function onErr() {
        img.removeEventListener("error", onErr);
        img.src = fallback;
      }, { once: true });
    }
  }

  function unloadFrameImage(frame) {
    var img = $("img", frame);
    if (!img || !img.src) return;
    img.removeAttribute("src");
  }

  function ensureFrameVideo(frame, slide) {
    var vid = $("video", frame);
    if (!vid || vid.src) return;
    vid.src = slide.src;
    if (frame.classList.contains("is-active")) {
      vid.play().catch(function () {});
    }
  }

  function unloadFrameVideo(frame) {
    var vid = $("video", frame);
    if (!vid || !vid.src) return;
    vid.pause();
    vid.removeAttribute("src");
    vid.load();
  }

  function pauseVideos(el) {
    el.querySelectorAll("video").forEach(function (v) {
      v.pause();
    });
  }

  function mediaNode(slide, opts) {
    opts = opts || {};
    if (slide.type === "video") {
      var vid = document.createElement("video");
      if (opts.loadVideo) vid.src = slide.src;
      vid.poster = slide.poster;
      vid.muted = !opts.controls;
      vid.loop = !opts.controls;
      vid.playsInline = true;
      vid.setAttribute("playsinline", "");
      vid.preload = opts.loadVideo ? "metadata" : "none";
      if (opts.controls) vid.controls = true;
      if (opts.autoplay) vid.autoplay = true;
      return vid;
    }
    var imgSrc = opts.full ? slide.full : slide.display;
    var imgFallback = opts.full ? slide.src : slide.src;
    return bindOptimizedImage(document.createElement("img"), imgSrc, imgFallback, {
      alt: slide.title,
      eager: opts.eager,
      deferSrc: opts.deferSrc,
    });
  }

  function wrap(i) {
    var n = slides.length;
    return ((i % n) + n) % n;
  }

  function wrapPlay(i) {
    var n = playlist.length;
    if (!n) return 0;
    return ((i % n) + n) % n;
  }

  function rebuildPlaylist() {
    playlist = [];
    slides.forEach(function (slide, i) {
      if (!filterChapter || slide.chapter === filterChapter) playlist.push(i);
    });
  }

  function paintPlaylist() {
    frames.forEach(function (frame, i) {
      var on = playlist.indexOf(i) >= 0;
      frame.hidden = !on;
      frame.style.display = on ? "" : "none";
    });
    filmCells.forEach(function (cell, i) {
      var on = playlist.indexOf(i) >= 0;
      cell.hidden = !on;
      cell.style.display = on ? "" : "none";
    });
  }

  function stopSlideshow() {
    if (!showTimer) return;
    clearInterval(showTimer);
    showTimer = null;
    if (showBtn) {
      showBtn.setAttribute("aria-pressed", "false");
      showBtn.textContent = "Slideshow";
    }
  }

  function startSlideshow() {
    stopSlideshow();
    if (playlist.length < 2) return;
    if (showBtn) {
      showBtn.setAttribute("aria-pressed", "true");
      showBtn.textContent = "Stop show";
    }
    showTimer = setInterval(function () {
      step(1);
    }, 1800);
  }

  function setFilter(chapter) {
    filterChapter = chapter || "";
    rebuildPlaylist();
    paintPlaylist();
    if (playlist.indexOf(index) < 0) index = playlist[0] || 0;
    if (tabsRoot) {
      tabsRoot.querySelectorAll(".gallery-tab").forEach(function (btn) {
        var on = (btn.getAttribute("data-chapter") || "") === filterChapter;
        btn.classList.toggle("is-active", on);
        btn.setAttribute("aria-selected", on ? "true" : "false");
      });
    }
    renderDetail();
    layoutTrack(0);
    scrollFilmstrip(false);
  }

  function buildTabs() {
    if (!tabsRoot) return;
    var seen = {};
    var chapters = [];
    slides.forEach(function (slide) {
      if (!slide.chapter || seen[slide.chapter]) return;
      seen[slide.chapter] = true;
      chapters.push(slide.chapter);
    });

    function addTab(label, chapter) {
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "gallery-tab" + (!chapter ? " is-active" : "");
      btn.setAttribute("role", "tab");
      btn.setAttribute("data-chapter", chapter);
      btn.setAttribute("aria-selected", chapter ? "false" : "true");
      btn.textContent = label;
      btn.addEventListener("click", function () {
        stopSlideshow();
        setFilter(chapter);
      });
      tabsRoot.appendChild(btn);
    }

    addTab("All", "");
    chapters.forEach(function (ch) {
      addTab(ch, ch);
    });
  }

  function setSwipeLock(on) {
    document.documentElement.classList.toggle("is-gallery-swipe", on);
  }

  function setIndex(i, options) {
    if (!slides.length) return;
    options = options || {};
    index = wrap(i);
    renderDetail();
    layoutTrack(0, { deferMedia: options.deferMedia === true });
    scrollFilmstrip(false);
  }

  function step(delta, options) {
    if (!playlist.length) {
      setIndex(index + delta, options);
      return;
    }
    var pos = playlist.indexOf(index);
    if (pos < 0) pos = 0;
    setIndex(playlist[wrapPlay(pos + delta)], options);
  }

  function swipeThreshold() {
    return Math.max(SWIPE_PX, (viewport ? viewport.offsetWidth : 0) * SWIPE_RATIO);
  }

  function sampleVelocity(state, clientX) {
    var now = performance.now();
    var dt = now - state.lastT;
    if (dt > 0 && dt < 64) {
      var instant = (clientX - state.lastX) / dt;
      state.vx = state.vx * 0.35 + instant * 0.65;
    }
    state.lastX = clientX;
    state.lastT = now;
  }

  function shouldCommitSwipe(dx, vx, threshold) {
    if (dx <= -threshold || (vx <= -FLICK_VX && dx <= -FLICK_MIN_DX)) return 1;
    if (dx >= threshold || (vx >= FLICK_VX && dx >= FLICK_MIN_DX)) return -1;
    return 0;
  }

  function setBlock(el, text) {
    if (!el) return;
    if (text) {
      el.textContent = text;
      el.hidden = false;
    } else {
      el.textContent = "";
      el.hidden = true;
    }
  }

  function setHtmlBlock(el, html) {
    if (!el) return;
    if (html) {
      el.innerHTML = html;
      el.hidden = false;
    } else {
      el.innerHTML = "";
      el.hidden = true;
    }
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function plainText(html) {
    var el = document.createElement("div");
    el.innerHTML = html;
    return (el.textContent || "").replace(/\s+/g, " ").trim();
  }

  function truncateWords(text, max) {
    if (!text || text.length <= max) return text;
    var cut = text.slice(0, max);
    var sp = cut.lastIndexOf(" ");
    if (sp > max * 0.55) cut = cut.slice(0, sp);
    return cut.replace(/[\s.,;:-]+$/, "") + "…";
  }

  function detailFits() {
    return detail.scrollHeight <= detail.clientHeight + 1;
  }

  function limitFactRows(maxRows) {
    if (!detailFacts || detailFacts.hidden) return;
    var rows = detailFacts.querySelectorAll("div");
    for (var i = rows.length - 1; i >= maxRows; i--) {
      rows[i].remove();
    }
  }

  function fitDetailPanel() {
    var s = slides[index];
    if (!s || !detail) return;

    detail.classList.remove("is-compact", "is-tight");
    if (detailBody) detailBody.classList.remove("is-truncated");

    setBlock(detailChapter, s.chapter);
    setBlock(detailDate, s.date);
    detailTitle.textContent = s.title;
    setBlock(detailMeta, s.meta);
    setHtmlBlock(detailFacts, s.factsHtml);
    setHtmlBlock(detailBody, s.bodyHtml);

    if (detail.clientHeight <= 0) return;

    limitFactRows(3);
    if (!detailFits()) detail.classList.add("is-compact");

    var bodyText = plainText(s.bodyHtml);
    if (bodyText && !detailFits()) {
      var len = bodyText.length;
      while (len > 48 && !detailFits()) {
        len -= 8;
        detailBody.innerHTML = "<p>" + escapeHtml(truncateWords(bodyText, len)) + "</p>";
      }
      detailBody.classList.add("is-truncated");
    }

    if (!detailFits() && detailFacts && !detailFacts.hidden) {
      setHtmlBlock(detailFacts, "");
    }

    if (!detailFits()) detail.classList.add("is-tight");

    if (!detailFits()) {
      var title = s.title;
      var tlen = title.length;
      while (tlen > 24 && !detailFits()) {
        tlen -= 4;
        detailTitle.textContent = truncateWords(title, tlen);
      }
    }
  }

  function scheduleFitDetail() {
    if (detailRaf) return;
    detailRaf = requestAnimationFrame(function () {
      detailRaf = 0;
      fitDetailPanel();
    });
  }

  function renderDetail() {
    var s = slides[index];
    if (!s || !detail) return;
    if (counterCur) {
      var pos = playlist.indexOf(index);
      counterCur.textContent = String((pos < 0 ? index : pos) + 1);
    }
    var totalEl = $(".gallery-counter__total");
    if (totalEl) totalEl.textContent = String(playlist.length || slides.length);
    root.setAttribute("aria-label", "Frame " + (index + 1) + " of " + slides.length + ": " + s.title);
    scheduleFitDetail();
  }

  function syncFrames(options) {
    options = options || {};
    var deferMedia = options.deferMedia === true;
    var pos = playlist.indexOf(index);
    var prev = pos > 0 ? playlist[pos - 1] : playlist.length > 1 ? playlist[playlist.length - 1] : -1;
    var next = pos >= 0 && pos < playlist.length - 1 ? playlist[pos + 1] : playlist.length > 1 ? playlist[0] : -1;
    frames.forEach(function (frame, i) {
      var dist;
      if (i === index) dist = 0;
      else if (i === prev || i === next) dist = 1;
      else dist = 2;
      frame.classList.toggle("is-active", i === index);
      frame.classList.toggle("is-adjacent", dist === 1);
      frame.classList.toggle("is-far", dist > 1);
      frame.setAttribute("aria-hidden", i === index ? "false" : "true");
      frame.dataset.dist = String(dist);
    });
    filmCells.forEach(function (cell, i) {
      cell.classList.toggle("is-active", i === index);
      cell.setAttribute("aria-selected", i === index ? "true" : "false");
    });
    if (deferMedia) {
      if (mediaSyncTimer) clearTimeout(mediaSyncTimer);
      mediaSyncTimer = setTimeout(function () {
        mediaSyncTimer = 0;
        syncFrameMedia();
      }, 120);
      return;
    }
    if (mediaSyncTimer) {
      clearTimeout(mediaSyncTimer);
      mediaSyncTimer = 0;
    }
    syncFrameMedia();
  }

  function syncFrameMedia() {
    frames.forEach(function (frame, i) {
      var dist = parseInt(frame.dataset.dist || "2", 10);
      if (slides[i].type === "video") {
        if (dist <= 1) ensureFrameVideo(frame, slides[i]);
        else unloadFrameVideo(frame);
      } else if (dist <= 1) {
        loadFrameImage(frame, slides[i]);
      } else {
        unloadFrameImage(frame);
      }
    });
    pauseVideos(track);
    var vid = $("video", frames[index]);
    if (vid && vid.src) vid.play().catch(function () {});
  }

  function centerOffset(at) {
    var frame = frames[at];
    if (!frame || !viewport) return 0;
    gapPx = parseFloat(getComputedStyle(track).gap) || 16;
    var x = 0;
    for (var i = 0; i < at; i++) {
      if (frames[i].hidden || frames[i].style.display === "none") continue;
      x += frames[i].offsetWidth + gapPx;
    }
    return x + frame.offsetWidth / 2 - viewport.offsetWidth / 2;
  }

  function measureTrackBase() {
    trackBase = -centerOffset(index);
  }

  function applyTrackTransform(extraDx) {
    if (!track) return;
    track.style.transform = "translate3d(" + (trackBase + (extraDx || 0)) + "px,0,0)";
  }

  function layoutTrack(extraDx, options) {
    if (!track || !frames.length) return;
    options = options || {};
    if (options.sync === false) {
      applyTrackTransform(extraDx);
      return;
    }
    measureTrackBase();
    applyTrackTransform(extraDx);
    syncFrames({ deferMedia: options.deferMedia === true });
  }

  function scheduleTrackDrag(dx) {
    pendingDx = dx;
    if (dragRaf) return;
    dragRaf = requestAnimationFrame(function () {
      dragRaf = 0;
      layoutTrack(pendingDx, { sync: false });
    });
  }

  function flushTrackDrag() {
    if (dragRaf) {
      cancelAnimationFrame(dragRaf);
      dragRaf = 0;
    }
    if (drag.locked) applyTrackTransform(pendingDx);
  }

  function scrollFilmstrip(smooth) {
    var cell = filmCells[index];
    if (!cell || !filmstrip) return;
    var left = cell.offsetLeft - (filmstrip.clientWidth - cell.offsetWidth) / 2;
    filmstrip.scrollTo({ left: Math.max(0, left), behavior: smooth ? "smooth" : "auto" });
  }

  function buildFrame(slide, i) {
    var frame = document.createElement("div");
    frame.className = "gallery-frame";
    frame.dataset.index = String(i);
    frame.setAttribute("role", "group");
    frame.setAttribute("aria-roledescription", "slide");

    var inner = document.createElement("div");
    inner.className = "gallery-frame__inner";
    inner.appendChild(mediaNode(slide, {
      eager: i === 0,
      deferSrc: slide.type !== "video" && i !== 0,
      loadVideo: slide.type === "video" && i === 0,
    }));

    if (slide.type === "video") {
      var badge = document.createElement("span");
      badge.className = "gallery-frame__clip";
      badge.textContent = "Clip";
      inner.appendChild(badge);
    }

    frame.appendChild(inner);

    return frame;
  }

  function buildFilmCell(slide, i) {
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "gallery-filmstrip__cell";
    btn.setAttribute("role", "tab");
    btn.setAttribute("aria-label", slide.title);
    btn.addEventListener("click", function () {
      stopSlideshow();
      setIndex(i);
      openLightbox();
    });

    var img = bindOptimizedImage(document.createElement("img"), slide.thumb, slide.rawThumb, {
      eager: i === 0,
    });
    img.alt = "";
    btn.appendChild(img);

    if (slide.type === "video") btn.classList.add("gallery-filmstrip__cell--clip");
    return btn;
  }

  function ensureLightbox() {
    if (lightbox) return;
    lightbox = document.createElement("div");
    lightbox.className = "gallery-lightbox";
    lightbox.hidden = true;
    lightbox.innerHTML =
      '<div class="gallery-lightbox__veil" data-close></div>' +
      '<div class="gallery-lightbox__panel" role="dialog" aria-modal="true" aria-labelledby="gallery-lb-title">' +
      '  <button type="button" class="gallery-lightbox__close" data-close aria-label="Close">&times;</button>' +
      '  <div class="gallery-lightbox__figure">' +
      '    <p class="gallery-lightbox__hint">Swipe for the next frame</p>' +
      '    <button type="button" class="gallery-lightbox__nav gallery-lightbox__nav--prev" data-step="-1" aria-label="Previous">&lsaquo;</button>' +
      '    <button type="button" class="gallery-lightbox__nav gallery-lightbox__nav--next" data-step="1" aria-label="Next">&rsaquo;</button>' +
      '    <div class="gallery-lightbox__stage"></div>' +
      '  </div>' +
      '  <div class="gallery-lightbox__copy">' +
      '    <p class="gallery-lightbox__kicker"></p>' +
      '    <h2 class="gallery-lightbox__title" id="gallery-lb-title"></h2>' +
      '    <p class="gallery-lightbox__meta"></p>' +
      '    <dl class="gallery-lightbox__facts"></dl>' +
      '    <div class="gallery-lightbox__body"></div>' +
      '    <p class="gallery-lightbox__count"></p>' +
      '  </div>' +
      "</div>";
    document.body.appendChild(lightbox);
    lightboxStage = $(".gallery-lightbox__stage", lightbox);
    lightboxPanel = $(".gallery-lightbox__panel", lightbox);
    lightboxFigure = $(".gallery-lightbox__figure", lightbox);
    lightboxCopy = $(".gallery-lightbox__copy", lightbox);

    lightbox.addEventListener("click", function (e) {
      var close = e.target.closest("[data-close]");
      var stepBtn = e.target.closest("[data-step]");
      if (close) closeLightbox();
      if (stepBtn) {
        e.preventDefault();
        lightboxStep(parseInt(stepBtn.getAttribute("data-step"), 10));
      }
    });

    lightboxFigure.addEventListener("pointerdown", onLightboxPointerDown);
  }

  function refreshLightboxCopy() {
    if (!lightboxCopy) return;
    var s = slides[index];
    var kicker = $(".gallery-lightbox__kicker", lightboxCopy);
    var title = $(".gallery-lightbox__title", lightboxCopy);
    var meta = $(".gallery-lightbox__meta", lightboxCopy);
    var facts = $(".gallery-lightbox__facts", lightboxCopy);
    var body = $(".gallery-lightbox__body", lightboxCopy);
    var count = $(".gallery-lightbox__count", lightboxCopy);
    var pos = playlist.indexOf(index);
    setBlock(kicker, [s.chapter, s.date].filter(Boolean).join(" · "));
    title.textContent = s.title;
    setBlock(meta, s.meta);
    setHtmlBlock(facts, s.factsHtml);
    setHtmlBlock(body, s.bodyHtml);
    if (count) {
      count.textContent = (pos < 0 ? index + 1 : pos + 1) + " / " + (playlist.length || slides.length);
    }
  }

  function refreshLightboxMedia() {
    if (!lightboxStage) return;
    pauseVideos(lightbox);
    var s = slides[index];
    lightboxStage.replaceChildren(
      mediaNode(s, { controls: true, autoplay: s.type === "video", eager: true, full: true, loadVideo: true })
    );
    lightboxStage.style.transform = "";
    lightboxStage.classList.remove("is-dragging");
    refreshLightboxCopy();
  }

  function lightboxStep(delta) {
    step(delta);
    refreshLightboxMedia();
  }

  function lightboxSwipeThreshold() {
    return Math.max(SWIPE_PX, (lightboxFigure ? lightboxFigure.offsetWidth : 0) * SWIPE_RATIO);
  }

  function flushLbDrag() {
    if (lbDragRaf) {
      cancelAnimationFrame(lbDragRaf);
      lbDragRaf = 0;
    }
    if (lbDrag.locked && lightboxStage) {
      lightboxStage.style.transform = "translate3d(" + lbPendingDx + "px,0,0)";
    }
  }

  function resetLbDrag() {
    if (lbDragRaf) {
      cancelAnimationFrame(lbDragRaf);
      lbDragRaf = 0;
    }
    bindLbDragWindow(false);
    lbDrag.on = false;
    lbDrag.locked = false;
    lbDrag.dx = 0;
    lbDrag.vx = 0;
    lbPendingDx = 0;
    if (lightboxStage) {
      lightboxStage.style.transform = "";
      lightboxStage.classList.remove("is-dragging");
    }
    if (lightboxFigure) lightboxFigure.classList.remove("is-dragging");
    setSwipeLock(false);
  }

  function onLightboxPointerDown(e) {
    if (e.button > 0) return;
    if (lightbox.hidden) return;
    if (e.target.closest(".gallery-lightbox__close, .gallery-lightbox__nav, [data-close], [data-step]")) return;
    lbDrag.on = true;
    lbDrag.id = e.pointerId;
    lbDrag.x0 = e.clientX;
    lbDrag.y0 = e.clientY;
    lbDrag.dx = 0;
    lbDrag.locked = false;
    lbDrag.lastX = e.clientX;
    lbDrag.lastT = performance.now();
    lbDrag.vx = 0;
    bindLbDragWindow(true);
  }

  function onLightboxPointerMove(e) {
    if (!lbDrag.on || e.pointerId !== lbDrag.id) return;
    var dx = e.clientX - lbDrag.x0;
    var dy = e.clientY - lbDrag.y0;

    if (!lbDrag.locked) {
      if (Math.abs(dx) < AXIS_LOCK && Math.abs(dy) < AXIS_LOCK) return;
      if (Math.abs(dx) <= Math.abs(dy)) {
        resetLbDrag();
        return;
      }
      lbDrag.locked = true;
      lightboxStage.classList.add("is-dragging");
      lightboxFigure.classList.add("is-dragging");
      setSwipeLock(true);
      try {
        lightboxFigure.setPointerCapture(e.pointerId);
      } catch (err) {}
      lbPendingDx = dx;
      lightboxStage.style.transform = "translate3d(" + dx + "px,0,0)";
    }

    e.preventDefault();
    sampleVelocity(lbDrag, e.clientX);
    lbDrag.dx = dx;
    lbPendingDx = dx;
    if (lbDragRaf) return;
    lbDragRaf = requestAnimationFrame(function () {
      lbDragRaf = 0;
      if (!lightboxStage) return;
      lightboxStage.style.transform = "translate3d(" + lbPendingDx + "px,0,0)";
    });
  }

  function onLightboxPointerUp(e) {
    if (!lbDrag.on || e.pointerId !== lbDrag.id) return;
    flushLbDrag();
    bindLbDragWindow(false);
    var threshold = lightboxSwipeThreshold();
    var dx = lbDrag.dx;
    var vx = lbDrag.vx;
    var locked = lbDrag.locked;
    var settleDx = lbPendingDx;
    lbDrag.on = false;
    lbDrag.locked = false;
    if (lbDragRaf) {
      cancelAnimationFrame(lbDragRaf);
      lbDragRaf = 0;
    }

    try {
      lightboxFigure.releasePointerCapture(e.pointerId);
    } catch (err) {}

    if (!locked) {
      resetLbDrag();
      return;
    }

    var dir = shouldCommitSwipe(dx, vx, threshold);
    if (lightboxStage) lightboxStage.style.transform = "translate3d(" + settleDx + "px,0,0)";

    requestAnimationFrame(function () {
      lbDrag.dx = 0;
      lbDrag.vx = 0;
      lbPendingDx = 0;

      if (dir) {
        /* Swap while transitions are still off to avoid a snap flash */
        if (lightboxStage) lightboxStage.style.transform = "";
        lightboxStep(dir);
        if (lightboxStage) lightboxStage.classList.remove("is-dragging");
        if (lightboxFigure) lightboxFigure.classList.remove("is-dragging");
        setSwipeLock(false);
        return;
      }

      if (lightboxStage) lightboxStage.classList.remove("is-dragging");
      if (lightboxFigure) lightboxFigure.classList.remove("is-dragging");
      setSwipeLock(false);
      if (lightboxStage) lightboxStage.style.transform = "";
    });
  }

  function openLightbox() {
    stopSlideshow();
    ensureLightbox();
    refreshLightboxMedia();
    lightbox.hidden = false;
    document.documentElement.classList.add("is-gallery-open");
    $(".gallery-lightbox__close", lightbox).focus();
  }

  function closeLightbox() {
    if (!lightbox || lightbox.hidden) return;
    resetLbDrag();
    pauseVideos(lightbox);
    lightbox.hidden = true;
    document.documentElement.classList.remove("is-gallery-open");
    viewport.focus({ preventScroll: true });
  }

  var dragWindowBound = false;
  var lbDragWindowBound = false;

  function bindDragWindow(on) {
    if (on) {
      if (dragWindowBound) return;
      dragWindowBound = true;
      window.addEventListener("pointermove", onPointerMove, { passive: false });
      window.addEventListener("pointerup", onPointerUp);
      window.addEventListener("pointercancel", onPointerUp);
    } else {
      if (!dragWindowBound) return;
      dragWindowBound = false;
      window.removeEventListener("pointermove", onPointerMove);
      window.removeEventListener("pointerup", onPointerUp);
      window.removeEventListener("pointercancel", onPointerUp);
    }
  }

  function bindLbDragWindow(on) {
    if (on) {
      if (lbDragWindowBound) return;
      lbDragWindowBound = true;
      window.addEventListener("pointermove", onLightboxPointerMove, { passive: false });
      window.addEventListener("pointerup", onLightboxPointerUp);
      window.addEventListener("pointercancel", onLightboxPointerUp);
    } else {
      if (!lbDragWindowBound) return;
      lbDragWindowBound = false;
      window.removeEventListener("pointermove", onLightboxPointerMove);
      window.removeEventListener("pointerup", onLightboxPointerUp);
      window.removeEventListener("pointercancel", onLightboxPointerUp);
    }
  }

  function resetDrag() {
    if (dragRaf) {
      cancelAnimationFrame(dragRaf);
      dragRaf = 0;
    }
    bindDragWindow(false);
    drag.on = false;
    drag.locked = false;
    drag.dx = 0;
    drag.vx = 0;
    pendingDx = 0;
    tapFrame = null;
    track.classList.remove("is-dragging");
    if (viewport) viewport.classList.remove("is-dragging");
    setSwipeLock(false);
  }

  function onPointerDown(e) {
    if (e.button > 0) return;
    if (lightbox && !lightbox.hidden) return;
    tapFrame = e.target.closest(".gallery-frame");
    drag.on = true;
    drag.id = e.pointerId;
    drag.x0 = e.clientX;
    drag.y0 = e.clientY;
    drag.dx = 0;
    drag.locked = false;
    drag.swiped = false;
    drag.lastX = e.clientX;
    drag.lastT = performance.now();
    drag.vx = 0;
    bindDragWindow(true);
  }

  function onPointerMove(e) {
    if (!drag.on || e.pointerId !== drag.id) return;
    var dx = e.clientX - drag.x0;
    var dy = e.clientY - drag.y0;

    if (!drag.locked) {
      if (Math.abs(dx) < AXIS_LOCK && Math.abs(dy) < AXIS_LOCK) return;
      if (Math.abs(dx) <= Math.abs(dy)) {
        resetDrag();
        return;
      }
      drag.locked = true;
      drag.swiped = true;
      track.classList.add("is-dragging");
      viewport.classList.add("is-dragging");
      setSwipeLock(true);
      try {
        viewport.setPointerCapture(e.pointerId);
      } catch (err) {}
      pendingDx = dx;
      applyTrackTransform(dx);
    }

    e.preventDefault();
    sampleVelocity(drag, e.clientX);
    drag.dx = dx;
    scheduleTrackDrag(dx);
  }

  function onPointerUp(e) {
    if (!drag.on || e.pointerId !== drag.id) return;
    flushTrackDrag();
    bindDragWindow(false);
    var threshold = swipeThreshold();
    var dx = drag.dx;
    var vx = drag.vx;
    var wasSwipe = drag.swiped;
    var frame = tapFrame;
    tapFrame = null;

    var settleDx = pendingDx;
    drag.on = false;
    drag.locked = false;
    if (dragRaf) {
      cancelAnimationFrame(dragRaf);
      dragRaf = 0;
    }

    try {
      viewport.releasePointerCapture(e.pointerId);
    } catch (err) {}

    var dir = wasSwipe ? shouldCommitSwipe(dx, vx, threshold) : 0;

    if (wasSwipe) applyTrackTransform(settleDx);

    requestAnimationFrame(function () {
      track.classList.remove("is-dragging");
      if (viewport) viewport.classList.remove("is-dragging");
      setSwipeLock(false);
      pendingDx = 0;
      drag.dx = 0;
      drag.vx = 0;

      if (dir) {
        step(dir, { deferMedia: true });
      } else {
        layoutTrack(0);
        if (!wasSwipe && frame) {
          stopSlideshow();
          var tapIndex = parseInt(frame.dataset.index, 10);
          if (!isNaN(tapIndex) && tapIndex !== index) setIndex(tapIndex);
          openLightbox();
        }
      }

      if (wasSwipe) {
        setTimeout(function () {
          drag.swiped = false;
        }, 0);
      }
    });
  }

  function onKeyDown(e) {
    if (e.target.closest("input, textarea, select")) return;

    var inLightbox = lightbox && !lightbox.hidden;
    if (inLightbox) {
      if (e.key === "Escape") {
        e.preventDefault();
        closeLightbox();
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        lightboxStep(-1);
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        lightboxStep(1);
      }
      return;
    }

    if (!root) return;
    if (e.key === "ArrowLeft") {
      e.preventDefault();
      stopSlideshow();
      step(-1);
    } else if (e.key === "ArrowRight") {
      e.preventDefault();
      stopSlideshow();
      step(1);
    } else if (e.key === "Home") {
      e.preventDefault();
      stopSlideshow();
      setIndex(playlist[0] || 0);
    } else if (e.key === "End") {
      e.preventDefault();
      stopSlideshow();
      setIndex(playlist[playlist.length - 1] || slides.length - 1);
    }
  }

  function init() {
    var source = $(".gallery-slides");
    if (!source) return;

    slides = Array.prototype.map.call(source.querySelectorAll(".gallery-slide"), readSlide);
    if (!slides.length) return;

    root = $(".gallery-carousel");
    viewport = $(".gallery-viewport");
    track = $(".gallery-track");
    detail = $(".gallery-detail");
    detailChapter = $(".gallery-detail__chapter", detail);
    detailDate = $(".gallery-detail__date", detail);
    detailTitle = $(".gallery-detail__title", detail);
    detailMeta = $(".gallery-detail__meta", detail);
    detailFacts = $(".gallery-detail__facts", detail);
    detailBody = $(".gallery-detail__body", detail);
    filmstrip = $(".gallery-filmstrip");
    counterCur = $(".gallery-counter__cur");
    tabsRoot = $(".gallery-tabs");
    showBtn = $(".gallery-slideshow");

    rebuildPlaylist();
    buildTabs();

    var counterTotal = $(".gallery-counter__total");
    if (counterTotal) counterTotal.textContent = String(slides.length);

    slides.forEach(function (slide, i) {
      var frame = buildFrame(slide, i);
      var cell = buildFilmCell(slide, i);
      frames.push(frame);
      filmCells.push(cell);
      track.appendChild(frame);
      filmstrip.appendChild(cell);
    });

    paintPlaylist();

    $(".gallery-arrow--next").addEventListener("click", function () {
      stopSlideshow();
      step(1);
    });
    $(".gallery-arrow--prev").addEventListener("click", function () {
      stopSlideshow();
      step(-1);
    });

    if (showBtn) {
      showBtn.addEventListener("click", function () {
        if (showTimer) stopSlideshow();
        else startSlideshow();
      });
    }

    viewport.addEventListener("pointerdown", function (e) {
      stopSlideshow();
      onPointerDown(e);
    });
    /* move/up are bound on window for the active gesture so web mouse drags stay smooth */

    document.addEventListener("keydown", onKeyDown);

    new ResizeObserver(function () {
      measureTrackBase();
      applyTrackTransform(drag.on && drag.locked ? drag.dx : 0);
      if (!drag.on) syncFrames();
      scheduleFitDetail();
    }).observe(viewport);

    new ResizeObserver(function () {
      scheduleFitDetail();
    }).observe(detail);

    renderDetail();
    requestAnimationFrame(function () {
      layoutTrack(0);
      scrollFilmstrip(false);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
