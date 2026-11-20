#!/usr/bin/env bash
# Angular: npm ci, tests (npm test -- --watch=false), build (npm run build), site = the single dist/*/browser.
source "$(dirname "$0")/lib.sh"
parse_args "$@"
cd "$(project_folder)"
npm ci
run_tests "npm test -- --watch=false"
run_build "npm run build"
if [ -z "$BUILT_FOLDER" ]; then
  vFound=$(find dist -mindepth 2 -maxdepth 2 -type d -name browser 2>/dev/null)
  [ "$(grep -c . <<< "$vFound" || true)" = 1 ] || fail "Il faut exactement un dossier dist/*/browser (trouvé : ${vFound:-aucun}) ; sinon, --sortie."
  BUILT_FOLDER=$vFound
fi
copy_site
