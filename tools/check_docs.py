#!/usr/bin/env python3
"""Focused documentation and static-site policy checks (standard library only)."""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web"
SKIP_DIRS = {".git", "node_modules", ".tools", "build", "sim", "work", "results"}
IMAGE_SUFFIXES = {".avif", ".gif", ".jpeg", ".jpg", ".png", ".svg", ".webp"}
MAX_IMAGE_BYTES = 6 * 1024 * 1024
CANONICAL_PREFIX = "https://tomato.tmarhguy.com/"
INDEXABLE_EXCEPTIONS = {"404.html"}
HISTORICAL_PARTS = {"log", "journal"}


class DocumentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.refs: list[tuple[str, str]] = []
        self.images: list[dict[str, str | None]] = []
        self.meta: list[dict[str, str | None]] = []
        self.links: list[dict[str, str | None]] = []
        self.title_depth = 0
        self.title = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        data = dict(attrs)
        for key in ("href", "src", "poster"):
            if data.get(key):
                self.refs.append((key, data[key] or ""))
        if tag == "img":
            self.images.append(data)
        elif tag == "meta":
            self.meta.append(data)
        elif tag == "link":
            self.links.append(data)
        elif tag == "title":
            self.title_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self.title_depth = max(0, self.title_depth - 1)

    def handle_data(self, data: str) -> None:
        if self.title_depth:
            self.title += data


def files_under(root: Path, suffixes: set[str]) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file()
        and path.suffix.lower() in suffixes
        and not any(part in SKIP_DIRS for part in path.relative_to(root).parts)
    )


def local_target(source: Path, raw: str, site_root: Path | None = None) -> Path | None:
    value = unquote(raw.strip())
    split = urlsplit(value)
    if not value or split.scheme or split.netloc or value.startswith(("mailto:", "tel:", "data:", "#")):
        return None
    clean = split.path
    if not clean:
        return None
    if clean.startswith("/") and site_root:
        target = site_root / clean.lstrip("/")
    else:
        target = source.parent / clean
    target = target.resolve()
    if site_root and target.is_dir():
        target /= "index.html"
    return target


def markdown_checks(errors: list[str]) -> None:
    pattern = re.compile(r"!?\[[^\]]*]\(([^)\s]+)(?:\s+['\"][^)]*['\"])?\)")
    roots = [ROOT / "README.md", ROOT / "THIRD_PARTY_NOTICES.md", ROOT / "docs"]
    markdown: list[Path] = []
    for item in roots:
        markdown.extend(
            [
                path
                for path in files_under(item, {".md"})
                if "log" not in path.relative_to(ROOT).parts
            ]
            if item.is_dir()
            else [item]
        )
    for path in markdown:
        text = path.read_text(encoding="utf-8")
        for raw in pattern.findall(text):
            target = local_target(path, raw)
            if target and not target.exists():
                errors.append(f"{path.relative_to(ROOT)}: missing Markdown target {raw}")

    # Historical prose may intentionally retain dead references, but local
    # media embedded in dated dispatches must remain renderable.
    media_suffixes = IMAGE_SUFFIXES | {".mp4", ".webm"}
    dated_logs = sorted((ROOT / "docs" / "log").glob("????-??-?? - *.md"))
    html_media = re.compile(
        r"<(?:img|video)\b[^>]*\b(?:src|poster)=[\"']([^\"']+)[\"']",
        re.IGNORECASE,
    )
    for path in dated_logs:
        text = path.read_text(encoding="utf-8")
        refs = pattern.findall(text) + html_media.findall(text)
        for raw in refs:
            split = urlsplit(unquote(raw.strip()))
            if Path(split.path).suffix.lower() not in media_suffixes:
                continue
            target = local_target(path, raw)
            if target and not target.exists():
                errors.append(f"{path.relative_to(ROOT)}: missing local media target {raw}")


def html_checks(errors: list[str]) -> list[Path]:
    pages = files_under(WEB, {".html"})
    web_root = WEB.resolve()
    for page in pages:
        rel = page.relative_to(WEB).as_posix()
        parser = DocumentParser()
        parser.feed(page.read_text(encoding="utf-8"))
        for key, raw in parser.refs:
            target = local_target(page, raw, WEB)
            if target and (target != web_root and web_root not in target.parents):
                errors.append(f"web/{rel}: {key} escapes web/: {raw}")
            elif target and not target.exists():
                errors.append(f"web/{rel}: missing {key} target {raw}")
        for image in parser.images:
            if "alt" not in image:
                errors.append(f"web/{rel}: image is missing an alt attribute ({image.get('src', '?')})")
        if rel not in INDEXABLE_EXCEPTIONS:
            metas = {(m.get("name") or m.get("property")): m.get("content") for m in parser.meta}
            canonicals = [link.get("href") for link in parser.links if link.get("rel") == "canonical"]
            for key in ("description", "viewport", "og:title", "og:description", "og:url", "og:image", "og:image:alt"):
                if not metas.get(key):
                    errors.append(f"web/{rel}: missing metadata {key}")
            if not parser.title.strip():
                errors.append(f"web/{rel}: missing title")
            expected = CANONICAL_PREFIX if rel == "index.html" else CANONICAL_PREFIX + rel
            if canonicals != [expected]:
                errors.append(f"web/{rel}: canonical must be {expected}")
    return pages


def sitemap_checks(errors: list[str], pages: list[Path]) -> None:
    sitemap = WEB / "sitemap.xml"
    try:
        tree = ET.parse(sitemap)
    except (ET.ParseError, OSError) as exc:
        errors.append(f"web/sitemap.xml: {exc}")
        return
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    actual = {node.text for node in tree.findall(".//sm:loc", ns)}
    expected = {
        CANONICAL_PREFIX if (rel := p.relative_to(WEB).as_posix()) == "index.html" else CANONICAL_PREFIX + rel
        for p in pages
        if p.relative_to(WEB).as_posix() not in INDEXABLE_EXCEPTIONS
    }
    if actual != expected:
        errors.append(
            "web/sitemap.xml: parity failure; "
            f"missing={sorted(expected - actual)}, extra={sorted(actual - expected)}"
        )


def policy_checks(errors: list[str]) -> None:
    current_files = [ROOT / "README.md"]
    current_files += [
        p for p in files_under(ROOT / "docs", {".md"}) if not HISTORICAL_PARTS.intersection(p.relative_to(ROOT).parts)
    ]
    current_files += [
        p for p in files_under(WEB, {".html"}) if not HISTORICAL_PARTS.intersection(p.relative_to(WEB).parts)
    ]
    stale = {
        r"\bTOMATO OS v(?:1|2)(?:\.\d+)?\b": "obsolete Tomato OS version",
        r"<strong>32,?768\s*[×x]\s*32-bit registers</strong>": "obsolete register count",
        r"\b60 instructions\b": "obsolete ISA count",
        r"\b90 MHz CPU\b": "routing target presented as CPU clock",
        r"\b524,?288\s+(?:ALU\s+)?(?:ops|operations)\b": (
            "ALU control configurations presented as distinct operations"
        ),
    }
    for path in current_files:
        text = path.read_text(encoding="utf-8")
        for pattern, label in stale.items():
            if re.search(pattern, text, re.IGNORECASE):
                errors.append(f"{path.relative_to(ROOT)}: {label}")

    for path in files_under(WEB, IMAGE_SUFFIXES):
        if path.stat().st_size > MAX_IMAGE_BYTES:
            errors.append(
                f"{path.relative_to(ROOT)}: image is {path.stat().st_size} bytes "
                f"(limit {MAX_IMAGE_BYTES})"
            )
    blocked = {".env", ".env.local", "id_rsa", "id_ed25519"}
    blocked_suffixes = {".aab", ".apk", ".dmg", ".ipa", ".key", ".pem", ".pfx", ".zip"}
    for path in WEB.rglob("*"):
        if path.is_file() and (path.name in blocked or path.suffix.lower() in blocked_suffixes):
            errors.append(f"{path.relative_to(ROOT)}: private/download artifact in public site")


def performance_claim_checks(errors: list[str]) -> None:
    sources = {
        "hardware/fpga/core/constr/nexys.xdc": "create_clock -period 10.000",
        "hardware/fpga/core/Makefile": "FREQ_MHZ   := 90",
        "hardware/fpga/core/rtl/board/nexys_top.v": "parameter CPU_DIV_LOG2 = 4",
        "web/js/tomato-cpu.js": "const CPU_HZ = 6250000;",
        "web/js/virtual.js": "const FRAME_BUDGET_MS = 8;",
    }
    for rel, phrase in sources.items():
        if phrase not in (ROOT / rel).read_text(encoding="utf-8"):
            errors.append(f"{rel}: performance contract drifted ({phrase})")

    required_public = {
        "README.md": ("100 MHz board input", "6.25 MHz", "25 MHz", "90 MHz"),
        "docs/status.md": (
            "100 MHz board oscillator",
            "6.25 MHz CPU clock",
            "25 MHz pixel clock",
            "~59.52 Hz",
            "place-and-route timing target",
            "workload-derived projection",
            "host-budgeted functional execution",
        ),
        "web/status.html": ("default CPU clock is 6.25 MHz", "nextpnr timing target"),
        "web/virtual.html": ("guest timer models a 6.25 MHz CPU", "not a 6.25 MHz or cycle-accurate emulator"),
    }
    for rel, phrases in required_public.items():
        text = (ROOT / rel).read_text(encoding="utf-8")
        for phrase in phrases:
            if phrase not in text:
                errors.append(f"{rel}: missing performance wording ({phrase})")

    for rel in ("web/index.html", "web/faq.html"):
        text = (ROOT / rel).read_text(encoding="utf-8")
        if re.search(r"about 1[–-]10(?:&nbsp;|\u00a0|\s)*MHz", text, re.IGNORECASE):
            errors.append(f"{rel}: ambiguous hardware-compiler frequency range")

    current_video = (
        ROOT / "hardware/fpga/core/README.md",
        ROOT / "hardware/fpga/core/reports/METRICS.md",
        ROOT / "hardware/fpga/hdmi_test/README.md",
        ROOT / "hardware/fpga/hdmi_test/rtl/main.sv",
    )
    for path in current_video:
        if re.search(r"640(?:x|×)480@60", path.read_text(encoding="utf-8")):
            errors.append(f"{path.relative_to(ROOT)}: 25 MHz video is ~59.52 Hz, not exact @60")


def workflow_checks(errors: list[str]) -> None:
    workflows = ROOT / ".github" / "workflows"
    use_re = re.compile(r"^\s*uses:\s*[^@\s]+@([^\s#]+)", re.MULTILINE)
    for path in sorted(workflows.glob("*.y*ml")):
        text = path.read_text(encoding="utf-8")
        if "\t" in text:
            errors.append(f"{path.relative_to(ROOT)}: tab character in workflow")
        for ref in use_re.findall(text):
            if not re.fullmatch(r"[0-9a-f]{40}", ref):
                errors.append(f"{path.relative_to(ROOT)}: action is not pinned to a commit ({ref})")
        if not re.search(r"^name:\s*\S", text, re.MULTILINE) or not re.search(
            r"^jobs:\s*$", text, re.MULTILINE
        ):
            errors.append(f"{path.relative_to(ROOT)}: missing top-level name/jobs")


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()
    errors: list[str] = []
    markdown_checks(errors)
    pages = html_checks(errors)
    sitemap_checks(errors, pages)
    policy_checks(errors)
    performance_claim_checks(errors)
    workflow_checks(errors)
    if errors:
        print("Documentation guardrails failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"PASS: documentation and site guardrails ({len(pages)} HTML pages)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
