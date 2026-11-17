#!/bin/bash
# Command Line Tools ship Testing.framework outside the default search path and without its
# Foundation cross-import overlay, so the flags go on the command line: SwiftPM's generated
# test runner is a separate module that package-level unsafeFlags never reach.
set -euo pipefail
cd "$(dirname "$0")/.."
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
if [ -d "$frameworks/Testing.framework" ] && [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]; then
  exec swift test \
    -Xswiftc -F"$frameworks" -Xlinker -F"$frameworks" -Xlinker -rpath -Xlinker "$frameworks" \
    -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays "$@"
fi
exec swift test "$@"
