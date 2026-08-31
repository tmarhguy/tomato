/** Landing — defer below-the-fold scripts. Hero bench mounts via bench.js. */
function deferCompilerReels() {
  if (document.getElementById("tomato-compiler-reels")) return;
  const s = document.createElement("script");
  s.id = "tomato-compiler-reels";
  s.src = "js/compiler-reels.js";
  s.defer = true;
  document.body.appendChild(s);
}

if (document.getElementById("bench")) {
  if (window.requestIdleCallback) {
    window.requestIdleCallback(deferCompilerReels, { timeout: 3000 });
  } else {
    window.setTimeout(deferCompilerReels, 800);
  }
}
