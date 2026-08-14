# Tomato website

A bench broadsheet for the Tomato CPU: cream paper, Playfair nameplate, Source Serif columns, Franklin gothic kickers. Newspaper rhythm — not the bureau cadence.

## Preview

```bash
cd web && python3 -m http.server 8080
# or: npm run serve
```

Open [http://localhost:8080](http://localhost:8080).

Pages: `index.html` (front), `architecture.html`, `isa.html`, `journal.html` (section), `journal/*.html` (dispatches), `board.html`, `source.html`, `about.html`.

## Sanity tests

Zero-dependency Node checks for deploy breakage (dead links, missing assets, root-absolute paths that break on `/tomato/`, JS syntax, GLB header, HTTP smoke of every page):

```bash
cd web && npm test
# or from repo root: make web-test
```

CI: `.github/workflows/web.yml` on PRs; Pages deploy (`.github/workflows/pages.yml`) runs the same suite before publishing. Vercel uses the same suite as `buildCommand` in the root `vercel.json`.

## GitHub Pages

Publishes `web/` to [tmarhguy.github.io/tomato](https://tmarhguy.github.io/tomato/). Enable **Settings → Pages → Source: GitHub Actions**. Keep links **relative** (never `/css/...`) so the site works under the `/tomato/` base path.

## Vercel

Point the project at this repo. Root `vercel.json` serves `web/` and runs `npm test` as the build. No framework, no install.
