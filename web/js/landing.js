/** Landing — scroll reveals + defer below-the-fold scripts. Hero bench mounts via bench.js. */

function revealLanding() {
  const nodes = [...document.querySelectorAll(".landing-reveal, .landing-scrub[data-scrub]")];
  if (!nodes.length) return;

  const showAll = () => {
    nodes.forEach((el) => el.classList.add("is-in"));
  };

  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const narrow = window.matchMedia("(max-width: 860px)").matches;
  if (reduced || narrow || !("IntersectionObserver" in window)) {
    showAll();
    return;
  }

  // Mark anything already on screen before enabling hide-until-reveal,
  // so the first viewport never flashes blank.
  const pending = [];
  for (const el of nodes) {
    if (el.getBoundingClientRect().top < window.innerHeight * 0.92) {
      el.classList.add("is-in");
    } else {
      pending.push(el);
    }
  }

  if (!pending.length) return;

  document.documentElement.classList.add("has-landing-reveal");

  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("is-in");
        io.unobserve(entry.target);
      }
    },
    { rootMargin: "0px 0px -6% 0px", threshold: 0.08 }
  );

  pending.forEach((el) => io.observe(el));

  // Safety: never leave content invisible if the observer never fires.
  window.setTimeout(showAll, 8000);
}

function deferCompilerReels() {
  if (document.getElementById("tomato-compiler-reels")) return;
  const s = document.createElement("script");
  s.id = "tomato-compiler-reels";
  s.src = "js/compiler-reels.js";
  s.defer = true;
  document.body.appendChild(s);
}

function bootLanding() {
  if (document.documentElement.dataset.landingBooted === "1") return;
  document.documentElement.dataset.landingBooted = "1";

  revealLanding();

  if (document.getElementById("bench")) {
    if (window.requestIdleCallback) {
      window.requestIdleCallback(deferCompilerReels, { timeout: 3000 });
    } else {
      window.setTimeout(deferCompilerReels, 800);
    }
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootLanding, { once: true });
} else {
  bootLanding();
}
