# Shared by the generic build scripts of this folder (sourced, not run).
# Arguments of every script: <out> [project] [--sans-tests] [--test "<command>"] [--build "<command>"] [--sortie <folder>]
#   out        folder that receives the built site (created; must not already hold an index.html)
#   project    project folder (or .csproj for .NET), relative to the current folder (the repository root); default .
#   --sans-tests   skips the tests; --test / --build replace the default commands; --sortie: built folder, relative to
#   the project folder, instead of the default one.
# Environment (set by the Build workflow; optional locally): BUILD_NUMBER, BUILD_BRANCH, BUILD_DATETIME.
set -euo pipefail

fail() {
  echo "::error::$*" >&2
  exit 1
}

parse_args() {
  OUT=""
  PROJECT="."
  RUN_TESTS=true
  TEST_COMMAND=""
  BUILD_COMMAND=""
  BUILT_FOLDER=""
  local vPositional=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --sans-tests) RUN_TESTS=false ;;
      --test) TEST_COMMAND=${2:?commande manquante après --test}; shift ;;
      --build) BUILD_COMMAND=${2:?commande manquante après --build}; shift ;;
      --sortie) BUILT_FOLDER=${2:?dossier manquant après --sortie}; shift ;;
      --*) fail "Option inconnue : $1." ;;
      *) vPositional+=("$1") ;;
    esac
    shift
  done
  [ ${#vPositional[@]} -ge 1 ] || fail "Dossier de sortie manquant : $(basename "$0") <sortie> [projet] [options]."
  [ ${#vPositional[@]} -le 2 ] || fail "Trop d'arguments : ${vPositional[*]}."
  OUT=$(realpath -m "${vPositional[0]}")
  PROJECT=${vPositional[1]:-.}
  [ -e "$PROJECT" ] || fail "Projet introuvable : $PROJECT."
  [ ! -f "$OUT/index.html" ] || fail "$OUT contient déjà un site."
  export BUILD_NUMBER=${BUILD_NUMBER:-0} BUILD_BRANCH=${BUILD_BRANCH:-local}
  echo "== ${BUILD_SCRIPT_NAME:-$(basename "$0" .sh)} : $PROJECT → $OUT"
}

# Project folder: PROJECT itself, or the folder of a project file.
project_folder() {
  if [ -f "$PROJECT" ]; then dirname "$PROJECT"; else printf '%s' "$PROJECT"; fi
}

run_tests() {
  if [ "$RUN_TESTS" = true ]; then
    echo "== Tests : ${TEST_COMMAND:-$1}"
    CI=true bash -c "${TEST_COMMAND:-$1}"
  else
    echo "== Tests : sautés"
  fi
}

run_build() {
  echo "== Build : ${BUILD_COMMAND:-$1}"
  bash -c "${BUILD_COMMAND:-$1}"
}

# Copies a built folder (relative to the current folder or absolute) to OUT.
copy_site() {
  local vSite=${BUILT_FOLDER:-$1}
  [ -f "$vSite/index.html" ] || fail "Pas d'index.html dans le dossier buildé ($vSite)."
  mkdir -p "$OUT"
  (cd "$vSite" && tar --exclude=./.git --exclude=./.github --exclude=./build.sh -cf - .) | tar -xf - -C "$OUT"
  echo "== Site : $vSite → $OUT"
}

# dotnet workload install, with sudo when the SDK folder is not writable (preinstalled SDK of the runner).
install_workload() {
  if ! dotnet workload install "$@"; then
    sudo -n dotnet workload install "$@" || fail "Installation du workload $* impossible."
  fi
}
