#!/usr/bin/env bash
# Build Project X-Ray bitgen (xc7frames2bit + fasm2frames) — one-time.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${ROOT}/.tools"
PRJXRAY="${TOOLS}/prjxray"
VENV="${TOOLS}/prjxray-venv"
MARKER="${TOOLS}/prjxray-tools.stamp"

if [[ -f "${MARKER}" ]]; then
  exit 0
fi

# Only the C++ half needs a compiler. Re-running to refresh the python venv
# should not demand a nix shell it will never use.
if [[ ! -x "${PRJXRAY}/build/tools/xc7frames2bit" ]] && ! command -v cmake >/dev/null; then
  echo "cmake required — run via: nix shell nixpkgs#cmake nixpkgs#ninja --command $0" >&2
  exit 1
fi

if [[ ! -d "${PRJXRAY}/.git" ]]; then
  echo "==> cloning prjxray (master)"
  git clone --depth 1 --branch master https://github.com/f4pga/prjxray.git "${PRJXRAY}"
  git -C "${PRJXRAY}" submodule update --init --recursive --depth 1 \
    third_party/fasm third_party/yaml-cpp third_party/abseil-cpp \
    third_party/gflags third_party/sanitizers-cmake third_party/googletest third_party/cctz
fi

if [[ ! -x "${PRJXRAY}/build/tools/xc7frames2bit" ]]; then
  # macOS: the newest CLT SDK can ship arm64e.x1 TBD slices that the bundled
  # ld/TAPI cannot parse ("unknown architecture arm64e.x1-macos" in
  # libSystem.B.tbd), which fails CMake's compiler check on an otherwise fine
  # toolchain. Pin the newest SDK without those slices when SDKROOT is unset.
  if [[ "$(uname -s)" == "Darwin" && -z "${SDKROOT:-}" ]]; then
    for sdk in $(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | sort -Vr); do
      tbd="${sdk}/usr/lib/libSystem.B.tbd"
      if [[ -f "${tbd}" ]] && ! grep -q "arm64e\.x1" "${tbd}" 2>/dev/null; then
        export SDKROOT="${sdk}"
        echo "==> pinning SDKROOT=${SDKROOT} (default SDK TBD has arm64e.x1 slices ld cannot parse)"
        break
      fi
    done
  fi
  # A previous failed configure leaves a stale CMakeCache behind; a retry with
  # a fixed SDKROOT must start clean or cmake reuses the broken check.
  if [[ -f "${PRJXRAY}/build/CMakeCache.txt" ]]; then
    echo "==> clearing stale cmake cache (previous configure failed)"
    rm -rf "${PRJXRAY}/build"
  fi
  echo "==> building xc7frames2bit"
  cmake -S "${PRJXRAY}" -B "${PRJXRAY}/build" -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_TESTING=OFF \
    -DCMAKE_CXX_FLAGS="-Wno-error -Wno-deprecated-builtins -Wno-deprecated-declarations"
  cmake --build "${PRJXRAY}/build" --parallel "$(sysctl -n hw.ncpu 2>/dev/null || nproc)" \
    --target xc7frames2bit
fi

echo "==> installing fasm2frames (python)"
rm -rf "${VENV}"
python3 -m venv "${VENV}"
PY="${VENV}/bin/python3"
"${PY}" -m ensurepip --upgrade >/dev/null 2>&1 || true
"${PY}" -m pip install -q --upgrade pip setuptools wheel
"${PY}" -m pip install -q "${PRJXRAY}/third_party/fasm"
"${PY}" -m pip install -q intervaltree pyjson5 pyyaml simplejson numpy textx

# fasm2frames.py imports the `prjxray` package from the repo root. The wrapper
# resolves everything from its own location so moving .tools — or the checkout —
# does not leave it pointing at a python that is no longer there.
cat > "${TOOLS}/fasm2frames" <<'EOF'
#!/usr/bin/env bash
TOOLS="$(cd "$(dirname "$0")" && pwd)"
export PYTHONPATH="${TOOLS}/prjxray${PYTHONPATH:+:${PYTHONPATH}}"
exec "${TOOLS}/prjxray-venv/bin/python3" "${TOOLS}/prjxray/utils/fasm2frames.py" "$@"
EOF
chmod +x "${TOOLS}/fasm2frames"

touch "${MARKER}"
echo "prjxray bitgen ready:"
echo "  ${PRJXRAY}/build/tools/xc7frames2bit"
echo "  ${TOOLS}/fasm2frames"
