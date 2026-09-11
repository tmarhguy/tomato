/**
 * Architecture map — ordered by how the machine actually runs.
 */
(function () {
  /** @typedef {{ path: string, label: string, hash?: string, flag?: string }} Link */

  /** @type {{ title: string, items: Link[] }[]} */
  const SECTIONS = [
    {
      title: "Verification",
      items: [
        { path: "verification.html", label: "ALU sign-off" },
        { path: "verification.html", hash: "ladder", label: "1b → 32b ladder" },
        { path: "verification.html", hash: "signoff", label: "Fast sign-off" },
        { path: "verification.html", hash: "formal", label: "SymbiYosys" },
        { path: "verification.html", hash: "directed", label: "476 directed" },
        { path: "verification.html", hash: "uvm", label: "UVM" },
        { path: "verification.html", hash: "gauntlet", label: "10B / 130B gauntlet" },
        { path: "verification.html", hash: "commands", label: "Run commands" },
        { path: "verification.html", hash: "limits", label: "Scope & limits" },
        { path: "playground.html", hash: "compiler", label: "Opcode compiler" },
      ],
    },
    {
      title: "Playground",
      items: [
        { path: "playground.html", hash: "bench", label: "Try the slice" },
        { path: "playground.html", hash: "trace", label: "One bit at a time" },
        { path: "playground.html", hash: "compiler", label: "Opcode compiler" },
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
        { path: "architecture.html", hash: "verification", label: "ALU sign-off (essay)" },
      ],
    },
    {
      title: "Compute",
      items: [
        { path: "architecture.html", hash: "slice", label: "Dual-LUT ALU" },
        { path: "boards/07-alu.html", label: "Lot 07 — copper", flag: "soldering" },
        { path: "journal/first-lights.html", label: "First lights and flux" },
        { path: "journal/first-assembly.html", label: "First phase of assembly" },
        { path: "boards/01-alu.html", label: "Lot 01 — predecessor" },
        { path: "journal/mode-mux.html", label: "Muxes removed" },
      ],
    },
    {
      title: "Datapath",
      items: [
        { path: "architecture.html", hash: "register-file", label: "Registers & write-back" },
        { path: "journal/register-upgrade.html", label: "Register Upgrade", flag: "now" },
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
      title: "Software",
      items: [
        { path: "software.html", label: "Assembler & toolchain" },
        { path: "software.html", hash: "usage", label: "How you use it" },
        { path: "software.html", hash: "stack", label: "What each file does" },
        { path: "os.html", label: "Tomato OS", flag: "hdmi" },
        { path: "os.html", hash: "controls", label: "D-pad controls" },
        { path: "os.html", hash: "menu", label: "Main menu" },
        { path: "os.html", hash: "display", label: "Framebuffer" },
        { path: "os.html", hash: "build", label: "Build & run" },
        { path: "os.html", hash: "screens", label: "Screenshots" },
        { path: "journal/tomato-works.html", label: "First HDMI boot" },
        { path: "journal/one-press.html", label: "One press, one key" },
        { path: "architecture.html", hash: "firmware", label: "Firmware chapter" },
      ],
    },
    {
      title: "Opcode & ISA",
      items: [
        { path: "isa.html", label: "Tomato ISA" },
        { path: "isa.html", hash: "rom", label: "ROM map" },
        { path: "isa.html", hash: "catalog", label: "Burned opcodes" },
        { path: "isa.html", hash: "usage", label: "How you use it" },
        { path: "journal/isa-as-a-wire.html", label: "ISA as a Wire" },
        { path: "software.html", hash: "stack", label: "Pseudos & assembler" },
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
      items: [
        { path: "journal/pixels-on-glass.html", label: "Pixels on the glass", flag: "now" },
        { path: "journal/pmod-pivot.html", label: "The PMOD pivot" },
        { path: "journal/first-lights.html", label: "First lights and flux" },
        { path: "journal/first-assembly.html", label: "First phase of assembly" },
        { path: "journal/pcbs-arrive.html", label: "PCBs arrive" },
        { path: "journal/microcode.html", label: "Decode modularization" },
      ],
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

    const isMobile = window.innerWidth <= 860;
    const openAttr = isMobile ? "" : " open";

    let html = `<details class="arch-map__details"${openAttr}>`;
    html += `<summary class="arch-map__title">Architecture map <span class="arch-map__burger"><span></span><span></span><span></span></span></summary>`;
    html += `<div class="arch-map__body">`;

    for (const section of SECTIONS) {
      html += `<p class="arch-map__heading">${section.title}</p>`;
      html += '<ul class="arch-map__list">';
      for (const link of section.items) html += renderLink(root, link, rel, hash);
      html += "</ul>";
    }

    html += `</div></details>`;
    mount.innerHTML = html;
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", render);
  else render();
  window.addEventListener("hashchange", render);
})();
