#!/usr/bin/env bash
# Static site: optional --build, then copies the project folder (or --sortie) as it is.
source "$(dirname "$0")/lib.sh"
parse_args "$@"
cd "$(project_folder)"
if [ -n "$BUILD_COMMAND" ]; then run_build ""; fi
copy_site .
