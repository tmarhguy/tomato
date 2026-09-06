for (const menu of document.querySelectorAll('.site-menu')) {
  menu.addEventListener('click', event => { if (event.target.closest('a')) menu.open = false; });
  document.addEventListener('click', event => { if (!menu.contains(event.target)) menu.open = false; });
  menu.addEventListener('keydown', event => { if (event.key === 'Escape') { menu.open = false; menu.querySelector('summary').focus(); } });
}
const primaryPages = new Set([...document.querySelectorAll('.front-links a,.project-primary a')].map(a => a.href));
for (const a of document.querySelectorAll('.site-menu nav a')) {
  if (primaryPages.has(a.href)) a.setAttribute('data-primary-page','');
}
// Silent previews start when visible; a deliberate pause stays paused.
for (const video of document.querySelectorAll('[data-auto-preview]')) {
  video.muted = true;
  let visible = false, held = false, managedPause = false;
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  video.autoplay = false;
  const update = () => {
    if (visible && !document.hidden && !motion.matches && !held) video.play().catch(() => {});
    else if (!video.paused) { managedPause = true; video.pause(); }
  };
  video.addEventListener('pause', () => { if (managedPause) managedPause = false; else held = true; });
  video.addEventListener('play', () => { held = false; });
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; update(); }, {threshold:.2}).observe(video);
  document.addEventListener('visibilitychange', update);
  motion.addEventListener('change', update);
}
