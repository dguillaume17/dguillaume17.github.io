#!/usr/bin/env bash
# Flutter web: flutter pub get, tests (flutter test, when test/ exists), build without service worker when the option
# exists (an old build would be served from it), site = build/web.
source "$(dirname "$0")/lib.sh"
parse_args "$@"
cd "$(project_folder)"
flutter pub get
if [ -d test ]; then run_tests "flutter test"; fi
vBuild="flutter build web --release"
if flutter build web -h 2>/dev/null | grep -q -- '--pwa-strategy'; then vBuild+=" --pwa-strategy=none"; fi
run_build "$vBuild"
copy_site build/web
