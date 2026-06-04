#!/usr/bin/env bash
# Codemagic Workflow Editor → Post-clone script: انسخ هذا المحتوى أو شغّل:
#   bash scripts/codemagic_post_clone.sh
set -euo pipefail
cd "${CM_BUILD_DIR:-$(pwd)}"
flutter pub get
