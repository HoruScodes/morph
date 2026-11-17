#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
tool="$(mktemp -d)/make-icon"
swiftc scripts/icon/main.swift Sources/Morph/Mascot.swift -o "$tool"
"$tool" Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
