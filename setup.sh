#!/usr/bin/env bash

sudo apt update
sudo apt install -y ipmitool fio

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create virtualenv in the repo directory
python3 -m venv "${SCRIPT_DIR}/.venv"

# Install requirements
"${SCRIPT_DIR}/.venv/bin/pip" install -r "${SCRIPT_DIR}/requirements.txt"

echo "Virtual environment created at ${SCRIPT_DIR}/.venv"


# nvbandwidth setup
sudo apt install -y build-essential libboost-program-options-dev cmake git

# Require CUDA toolkit (nvcc + cuobjdump)
if [ ! -x /usr/local/cuda/bin/nvcc ]; then
  echo "ERROR: /usr/local/cuda/bin/nvcc not found. Install CUDA toolkit first." >&2
  exit 1
fi
if [ ! -x /usr/local/cuda/bin/cuobjdump ]; then
  echo "ERROR: /usr/local/cuda/bin/cuobjdump not found. Install CUDA toolkit first." >&2
  exit 1
fi

NVBW_DIR="$HOME/nvbandwidth"
if [ ! -d "$NVBW_DIR/.git" ]; then
  rm -rf "$NVBW_DIR"
  git clone https://github.com/NVIDIA/nvbandwidth.git "$NVBW_DIR"
fi

cd "$NVBW_DIR"

# Clean any old in-source cmake state and rebuild cleanly
rm -f CMakeCache.txt
rm -rf CMakeFiles build
mkdir -p build

CAP="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1 | tr -d '.' )"
if [ -z "${CAP}" ]; then
  echo "ERROR: failed to read compute capability from nvidia-smi" >&2
  exit 1
fi
echo "Building nvbandwidth for sm_${CAP}"

cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_ARCHITECTURES="${CAP}" \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc

cmake --build build -j

BIN="$NVBW_DIR/build/nvbandwidth"
if [ ! -x "$BIN" ]; then
  echo "ERROR: build succeeded but $BIN not found/executable" >&2
  exit 1
fi

# Verify the binary actually contains the right SASS arch (prevents PTX-JIT failures)
if ! /usr/local/cuda/bin/cuobjdump --list-elf "$BIN" | grep -q "sm_${CAP}"; then
  echo "ERROR: built nvbandwidth does not contain sm_${CAP} (wrong arch embedded)" >&2
  echo "Embedded arches:" >&2
  /usr/local/cuda/bin/cuobjdump --list-elf "$BIN" | egrep -o 'sm_[0-9]+' | sort -u >&2 || true
  exit 1
fi

echo "nvbandwidth built at $BIN"

# Optional: install globally so `nvbandwidth` uses the correct binary
sudo ln -sfn "$BIN" /usr/local/bin/nvbandwidth
echo "Symlinked /usr/local/bin/nvbandwidth -> $BIN"

# Optional quick sanity test (non-fatal)
# CUDA_DISABLE_PTX_JIT=1 /usr/local/bin/nvbandwidth -t 1 || true