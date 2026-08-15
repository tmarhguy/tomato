/**
 * Architecture map — ordered by how the machine actually runs.
 */
(function () {
  /** @typedef {{ path: string, label: string, hash?: string, flag?: string }} Link */

  /** @type {{ title: string, items: Link[] }[]} */
  const SECTIONS = [
    {
      title: "Playground",
      items: [
        { path: "playground.html", hash: "bench", label: "The bench" },
        { path: "playground.html", hash: "trace", label: "Bit by bit" },
        { path: "playground.html", hash: "touch", label: "What moves" },
        { path: "playground.html", hash: "compiler", label: "Find opcode" },
        { path: "board.html", label: "Lot 07 in 3D" },
      ],
    },
    {
      title: "Essay",
      items: [
        { path: "architecture.html", hash: "quirks", label: "Quirks of Tomato" },
        { path: "architecture.html", hash: "overview", label: "Machine overview" },
        { path: "architecture.html", hash: "datapath", label: "Fetch to write-back" },
        { path: "architecture.html", hash: "slice", label: "Dual-LUT slice" },
        { path: "architecture.html", hash: "word", label: "32-bit word" },
        { path: "architecture.html", hash: "decode", label: "Modular decode" },
        { path: "architecture.html", hash: "boards", label: "Board progress" },
        { path: "architecture.html", hash: "verification", label: "ALU sign-off" },
      ],
    },
    {
      title: "Compute",
      items: [
        { path: "architecture.html", hash: "slice", label: "Dual-LUT ALU" },
        { path: "boards/07-alu.html", label: "Lot 07 — copper", flag: "ordered" },
        { path: "boards/01-alu.html", label: "Lot 01 — predecessor" },
        { path: "journal/mode-mux.html", label: "Muxes removed" },
      ],
    },
    {
      title: "Datapath",
      items: [
        { path: "architecture.html", hash: "register-file", label: "Registers & write-back" },
        { path: "boards/04-register.html", label: "Lot 04 — register file" },
        { path: "boards/06-bus.html", label: "Lot 06 — data bus" },
      ],
    },
    {
      title: "Shift & multiply",
      items: [
        { path: "architecture.html", hash: "multiply", label: "Multiply loop" },
        { path: "boards/02-shift.html", label: "Lot 02 — barrel shifter" },
        { path: "journal/mul-engine.html", label: "Priority encoder" },
      ],
    },
    {
      title: "Memory",
      items: [
        { path: "architecture.html", hash: "memory", label: "RAM & load/store" },
        { path: "boards/03-memory.html", label: "Lot 03 — memory" },
        { path: "journal/load-store.html", label: "Load/store timing" },
      ],
    },
    {
      title: "Sequencing & I/O",
      items: [
        { path: "architecture.html", hash: "sequencing", label: "PC & interrupts" },
        { path: "boards/05-pc.html", label: "Lot 05 — program counter" },
      ],
    },
    {
      title: "Video & display",
      items: [
        { path: "architecture.html", hash: "video", label: "Tile framebuffer" },
        { path: "boards/08-display.html", label: "Lot 08 — display panel" },
        { path: "journal/display.html", label: "Display dispatch" },
      ],
    },
    {
      title: "Firmware",
      items: [{ path: "architecture.html", hash: "firmware", label: "TomatoOS" }],
    },
    {
      title: "Opcode & ISA",
      items: [
        { path: "isa.html", label: "512-row ROM" },
        { path: "isa.html", hash: "profiles", label: "Parametric ISA maps" },
        { path: "journal/isa-as-a-wire.html", label: "ISA as a Wire" },
      ],
    },
    {
      title: "Copper lots",
      items: [
        { path: "boards.html", label: "Full catalog" },
        { path: "board.html", label: "3D · lot 07" },
      ],
    },
    {
      title: "Journal",
      items: [{ path: "journal/microcode.html", label: "Decode modularization" }],
    },
  ];

  function siteRelPath() {
    const path = location.pathname.replace(/\/+$/, "");
    const parts = path.split("/").filter(Boolean);
    const idx = parts.lastIndexOf("tomato");
    const tail = idx >= 0 ? parts.slice(idx + 1) : parts;
    if (tail.length >= 2 && tail[0] === "journal") return `journal/${tail[1]}`;
    if (tail.length >= 2 && tail[0] === "boards") return `boards/${tail[1]}`;
    return tail[tail.length - 1] || "index.html";
  }

  function href(root, link) {
    return link.hash ? `${root}${link.path}#${link.hash}` : `${root}${link.path}`;
  }

  function isActive(link, rel, hash) {
    if (rel !== link.path) return false;
    const want = link.hash || "";
    const have = hash.replace(/^#/, "");
    if (want) {
      if (have === want) return true;
      if (!have && want === "overview") return true;
      return false;
    }
    return !have;
  }

  function renderLink(root, link, rel, hash) {
    const current = isActive(link, rel, hash);
    const cls = current ? " arch-map__link--current" : "";
    const aria = current ? ' aria-current="location"' : "";
    const flag = link.flag ? ` <span class="arch-map__flag">${link.flag}</span>` : "";
    return `<li><a class="arch-map__link${cls}" href="${href(root, link)}"${aria}>${link.label}${flag}</a></li>`;
  }

  function render() {
    const mount = document.querySelector("[data-arch-map]");
    if (!mount) return;

    const root = mount.dataset.root ?? "";
    const rel = siteRelPath();
    const hash = location.hash;

    mount.className = "arch-map";
    mount.setAttribute("aria-label", "Architecture map");

    let html = '<p class="arch-map__title">Architecture map</p>';

    for (const section of SECTIONS) {
      html += `<p class="arch-map__heading">${section.title}</p>`;
      html += '<ul class="arch-map__list">';
      for (const link of section.items) html += renderLink(root, link, rel, hash);
      html += "</ul>";
    }

    mount.innerHTML = html;
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", render);
  else render();
  window.addEventListener("hashchange", render);
})();
