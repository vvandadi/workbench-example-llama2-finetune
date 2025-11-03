#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# sudo/apt helpers (script may run as non-root)
SUDO=""
APT="apt-get"
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo -n "
    APT="sudo -n apt-get"
  else
    echo "Need root or sudo to install system packages" >&2
    exit 1
  fi
fi

# Ensure Python toolchain present (CUDA images often lack it)
if ! command -v python3 >/dev/null 2>&1; then
  ${APT} update
  ${APT} install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    git build-essential curl ca-certificates
  ${APT} clean
  ${SUDO} rm -rf /var/lib/apt/lists/* || true
fi

# -----------------------------
# PEP 668: use a virtual env
# -----------------------------
VENV_DIR="${VENV_DIR:-$HOME/.venv}"
if [ ! -d "${VENV_DIR}" ]; then
  python3 -m venv "${VENV_DIR}"
fi
# shellcheck disable=SC1090
. "${VENV_DIR}/bin/activate"

# Upgrade packaging tools inside the venv
python -m pip install --upgrade pip wheel setuptools

# Stable stack from cu124 index (Arm64 wheels available)
pip install \
  "torch==2.5.*" \
  "torchvision==0.20.*" \
  "torchaudio==2.5.*" \
  --index-url https://download.pytorch.org/whl/cu124


# NeMo after Torch
pip install "nemo_toolkit[all]"

# Project deps
if [ -f "/workspace/environment/reqs.txt" ]; then
  pip install -r /workspace/environment/reqs.txt
elif [ -f "environment/reqs.txt" ]; then
  pip install -r environment/reqs.txt
elif [ -f "reqs.txt" ]; then
  pip install -r reqs.txt
fi

# Non-fatal smoke test
python - <<'PY' || true
import torch
print("torch:", torch.__version__)
print("cuda available:", torch.cuda.is_available())
print("device:", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "-")
PY
