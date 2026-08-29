# Tomato, from the chats

A start-to-end windback: Gemini threads in `chats/combined_chats.pdf`, dated verdicts in `docs/log/`, plates in `web/assets/`.

There is no MacTeX/`pdflatex` on this machine. Compile with **Tectonic** (self-contained XeTeX):

```bash
# once, if tectonic is not on PATH:
# curl the aarch64 macOS binary from
# https://github.com/tectonic-typesetting/tectonic/releases
# and put it on PATH (e.g. ~/.local/bin)

cd docs/history
tectonic -X compile tomato-from-the-chats.tex
```

Output: `tomato-from-the-chats.pdf` in the same directory.

`figs/broadsheet-front.png` is a symlink for the magazine plate whose filename contains a space.
