/* Mobile mast: hamburger on the right, drawer from the same side. */
(function () {
  const mast = document.querySelector(".mast");
  const nav = document.querySelector(".mast-nav");
  if (!mast || !nav || mast.querySelector(".mast-burger")) return;

  if (!nav.id) nav.id = "mast-nav";

  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "mast-burger";
  btn.setAttribute("aria-controls", nav.id);
  btn.setAttribute("aria-expanded", "false");
  btn.setAttribute("aria-label", "Open menu");
  btn.innerHTML = "<span></span><span></span><span></span>";

  const veil = document.createElement("div");
  veil.className = "mast-veil";
  veil.hidden = true;

  mast.append(btn);
  document.body.append(veil);

  const mq = window.matchMedia("(max-width: 860px)");

  function placeNav() {
    if (mq.matches) document.body.append(nav);
    else mast.insertBefore(nav, btn);
  }

  function setOpen(open) {
    document.documentElement.classList.toggle("is-nav-open", open);
    btn.setAttribute("aria-expanded", String(open));
    btn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    veil.hidden = !open;
    if (mq.matches) nav.toggleAttribute("inert", !open);
    else nav.removeAttribute("inert");
  }

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

  const onBreak = () => {
    setOpen(false);
    placeNav();
  };
  if (mq.addEventListener) mq.addEventListener("change", onBreak);
  else mq.addListener(onBreak);

  placeNav();
  if (mq.matches) nav.setAttribute("inert", "");
})();
