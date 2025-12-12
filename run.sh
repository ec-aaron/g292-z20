#!/usr/bin/env bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if auto-mount is enabled in config (simple grep for boolean flag)
if grep -q "auto_mount_for_testing: true" "${SCRIPT_DIR}/tests/config.yaml" 2>/dev/null; then
    echo "=== Auto-mounting Lexar drives (disk.auto_mount_for_testing=true) ==="
    if [ -x "${SCRIPT_DIR}/lexar-drives.sh" ]; then
        "${SCRIPT_DIR}/lexar-drives.sh" mount
        echo ""
    else
        echo "WARNING: lexar-drives.sh not found or not executable"
        echo ""
    fi
fi

# Run pytest as root using the virtualenv python
sudo "${SCRIPT_DIR}/.venv/bin/python" -m pytest "$@"
