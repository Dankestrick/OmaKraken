#!/usr/bin/env bash
# Remove OmaKraken the same way the README describes.
set -euo pipefail
omarchy plugin remove io.github.dankestrick.omakraken --yes
echo "The udev rule and ~/.config/omakraken are still there. See the README to remove them."
