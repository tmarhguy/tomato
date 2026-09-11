/** Tomato ISA — ROM peek (hover / tap) + catalog hash sync. */

const rom = document.getElementById("isa-rom");
const peek = document.getElementById("isa-peek");
const list = document.getElementById("catalog-list") || document.getElementById("catalog");

function showPeek(cell) {
  if (!peek || !cell) return;
  const addr = cell.dataset.addr || "—";
  const name = cell.dataset.name || "—";
  const op = cell.dataset.op || "";
  const href = cell.dataset.href || "";
  const open = !href;

  peek.querySelector(".isa-peek-addr").textContent = addr;
  peek.querySelector(".isa-peek-name").textContent = open ? "Open slot" : name;
  peek.querySelector(".isa-peek-op").textContent = op;

  const link = peek.querySelector(".isa-peek-link");
  if (href) {
    link.hidden = false;
    link.href = href;
    link.textContent = `Open ${name} in catalog`;
  } else {
    link.hidden = true;
    link.removeAttribute("href");
  }

  for (const c of rom.querySelectorAll(".isa-cell.is-peek")) c.classList.remove("is-peek");
  cell.classList.add("is-peek");
}

if (rom && peek) {
  rom.addEventListener("pointerover", (event) => {
    const cell = event.target.closest(".isa-cell");
    if (!cell || !rom.contains(cell)) return;
    if (event.pointerType === "mouse") showPeek(cell);
  });

  rom.addEventListener("focusin", (event) => {
    const cell = event.target.closest(".isa-cell");
    if (cell) showPeek(cell);
  });

  rom.addEventListener("click", (event) => {
    const cell = event.target.closest(".isa-cell");
    if (!cell || !rom.contains(cell)) return;
    showPeek(cell);
  });
}

if (list && rom) {
  const sync = () => {
    const id = (location.hash || "").replace(/^#/, "");
    for (const cell of document.querySelectorAll(".isa-cell.is-burn")) {
      const on = Boolean(id && cell.dataset.href === `#${id}`);
      cell.classList.toggle("is-active", on);
      if (on) showPeek(cell);
    }
  };
  window.addEventListener("hashchange", sync);
  sync();
}
