#!/usr/bin/env bash
# Builds the static site of one branch of a repository. Run by .github/workflows/build.yml, in the repository's own run.
#
# Usage:
#   build.sh detect <source-dir> <repository-name> <config-file>
#     Finds the project and its technology, merges the defaults and the repository's entry of the config file
#     (.github/builds.json), and writes the settings as key=value lines to GITHUB_OUTPUT (stdout without it).
#   build.sh run <source-dir> <output-dir>
#     Installs, tests and builds with the settings of detect (environment: TECHNO, PROJECT, TEST, BUILD, OUTPUT, AOT,
#     BUILD_NUMBER, BUILD_BRANCH), then copies the built site (with its index.html) to output-dir.
#
# Detection (in the configured project folder, else the whole repository, without node_modules, bin, obj, .git):
#   angular.json                                           angular
#   pubspec.yaml depending on flutter                      flutter
#   .csproj with Sdk Microsoft.NET.Sdk.BlazorWebAssembly   blazor
#   .csproj with Sdk Microsoft.NET.Sdk.WebAssembly and Avalonia.Browser   avalonia
#   package.json depending on vite                         vite (React, Vue, Svelte...)
#   package.json depending on react-scripts                cra
#   index.html, no other project                           static
# Exactly one project must be found, unless the config names it.
set -euo pipefail

PRUNE=(-name node_modules -o -name bin -o -name obj -o -name .git -o -name dist -o -name build)

fail() {
  echo "::error::$*"
  exit 1
}

# Lists the candidate projects under a folder, one "<techno> <path>" per line (path relative to the source).
candidates() {
  local vRoot=$1 fFile vDir
  while IFS= read -r fFile; do
    vDir=$(dirname "$fFile")
    case "$fFile" in
      */angular.json) echo "angular $vDir" ;;
      */pubspec.yaml) grep -qE '^\s+sdk:\s*flutter' "$fFile" && echo "flutter $vDir" ;;
      *.csproj)
        if grep -q 'Microsoft.NET.Sdk.BlazorWebAssembly' "$fFile"; then
          echo "blazor $fFile"
        elif grep -q 'Microsoft.NET.Sdk.WebAssembly' "$fFile" && grep -q 'Avalonia.Browser' "$fFile"; then
          echo "avalonia $fFile"
        fi
        ;;
      */package.json)
        if [ ! -f "$vDir/angular.json" ]; then
          if jq -e '(.dependencies // {}) + (.devDependencies // {}) | has("vite")' "$fFile" > /dev/null; then
            echo "vite $vDir"
          elif jq -e '(.dependencies // {}) + (.devDependencies // {}) | has("react-scripts")' "$fFile" > /dev/null; then
            echo "cra $vDir"
          fi
        fi
        ;;
    esac || true
  done < <(find "$vRoot" \( -type d \( "${PRUNE[@]}" \) -prune \) -o -type f \
             \( -name angular.json -o -name pubspec.yaml -o -name '*.csproj' -o -name package.json \) -print | sort)
}

detect() {
  local vSource=${1:?dossier source manquant} vRepository=${2:?nom du repo manquant} vConfig=${3:?config manquante}
  cd "$vSource"

  local vSettings
  vSettings=$(jq -c --arg repository "$vRepository" '.defaults + (.repositories[$repository] // {})' "$vConfig")
  setting() { jq -r --arg key "$1" '.[$key] // empty | tostring' <<< "$vSettings"; }

  local vTechno vProject vRoot vFound
  vTechno=$(setting techno)
  vProject=$(setting project)
  vRoot=${vProject:-.}
  [ -e "$vRoot" ] || fail "Projet $vRoot introuvable dans la branche (config .github/builds.json)."

  if [ -z "$vTechno" ] || [ -z "$vProject" ]; then
    if [ -f "$vRoot" ]; then
      vFound=$(candidates "$(dirname "$vRoot")" | awk -v p="$vRoot" '$2 == p')
    else
      vFound=$(candidates "$vRoot")
      if [ -z "$vFound" ] && [ -f "$vRoot/index.html" ]; then
        vFound="static $vRoot"
      fi
    fi
    vFound=$(sed 's| \./| |' <<< "$vFound")
    if [ -n "$vTechno" ]; then
      vFound=$(awk -v t="$vTechno" '$1 == t' <<< "$vFound")
    fi
    case "$(grep -c . <<< "$vFound" || true)" in
      1) ;;
      0) fail "Aucun projet publiable trouvé dans $vRoot (angular.json, package.json avec vite, .csproj WebAssembly, pubspec.yaml, index.html). Le préciser dans .github/builds.json." ;;
      *) fail "Plusieurs projets trouvés : $(tr '\n' ';' <<< "$vFound" | sed 's/;$//; s/;/ ; /g'). Préciser project (et techno) pour $vRepository dans .github/builds.json." ;;
    esac
    vTechno=${vFound%% *}
    vProject=${vFound#* }
  fi
  vProject=${vProject#./}

  local vTest vBuild vOutput vDir
  vDir=$vProject
  [ -f "$vProject" ] && vDir=$(dirname "$vProject")
  case "$vTechno" in
    angular)
      vTest="npm test -- --watch=false"
      vBuild="npm run build"
      vOutput="" ;;
    vite)
      vTest="npm run test --if-present"
      vBuild="npm run build -- --base=./"
      vOutput="dist" ;;
    cra)
      vTest="npm run test --if-present"
      vBuild="npm run build"
      vOutput="build" ;;
    blazor | avalonia)
      vTest=""
      while IFS= read -r fTests; do
        vTest+="${vTest:+ && }dotnet test \"$fTests\" -c Release"
      done < <(grep -rl --include='*.csproj' 'Microsoft.NET.Test.Sdk' . 2>/dev/null | sort || true)
      vBuild=""
      vOutput="" ;;
    flutter)
      vTest=""
      [ -d "$vDir/test" ] && vTest="flutter test"
      vBuild=""
      vOutput="build/web" ;;
    static)
      vTest=""
      vBuild=""
      vOutput="." ;;
    *) fail "Techno inconnue : $vTechno (angular, vite, cra, blazor, avalonia, flutter, static)." ;;
  esac
  if jq -e 'has("test")' <<< "$vSettings" > /dev/null; then vTest=$(setting test); fi
  if jq -e 'has("build")' <<< "$vSettings" > /dev/null; then vBuild=$(setting build); fi
  if jq -e 'has("output")' <<< "$vSettings" > /dev/null; then vOutput=$(setting output); fi

  local vDotnet vGlobalJson=""
  vDotnet=$(setting dotnet)
  if [ -f global.json ]; then
    vGlobalJson=global.json
  fi

  {
    echo "techno=$vTechno"
    echo "project=$vProject"
    echo "directory=$vDir"
    echo "lock_file=${vSource%/}$([ "$vDir" = . ] || printf '/%s' "$vDir")/package-lock.json"
    echo "test=$vTest"
    echo "build=$vBuild"
    echo "output=$vOutput"
    echo "node=$(setting node)"
    echo "dotnet=$vDotnet"
    echo "global_json=$vGlobalJson"
    echo "flutter=$(setting flutter)"
    echo "aot=$(setting aot)"
  } | tee -a "${GITHUB_OUTPUT:-/dev/null}"
  echo "Projet : $vProject ($vTechno)" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
}

run() {
  local vSource=${1:?dossier source manquant} vOut=${2:?dossier de sortie manquant}
  : "${TECHNO:?}" "${PROJECT:?}"
  vOut=$(realpath -m "$vOut")
  cd "$vSource"
  local vDir=$PROJECT
  [ -f "$PROJECT" ] && vDir=$(dirname "$PROJECT")

  local vSite=""
  case "$TECHNO" in
    angular | vite | cra)
      cd "$vDir"
      npm ci
      if [ -n "${TEST:-}" ]; then CI=true bash -c "$TEST"; fi
      bash -c "${BUILD:?}"
      if [ -n "${OUTPUT:-}" ]; then
        vSite=$OUTPUT
      else
        vSite=$(find dist -mindepth 2 -maxdepth 2 -type d -name browser 2>/dev/null)
        [ "$(grep -c . <<< "$vSite" || true)" = 1 ] || fail "Il faut exactement un dossier dist/*/browser (trouvé : ${vSite:-aucun}) ; sinon, préciser output dans .github/builds.json."
      fi
      ;;
    blazor | avalonia)
      if [ -n "${TEST:-}" ]; then bash -c "$TEST"; fi
      if [ -n "${BUILD:-}" ]; then
        cd "$vDir"
        bash -c "$BUILD"
        vSite=${OUTPUT:?output à préciser avec build dans .github/builds.json}
      else
        local vArgs=(-c Release -o "$RUNNER_TEMP_DIR/dotnet-publish" -p:CompressionEnabled=false
                     "-p:BuildNumber=${BUILD_NUMBER:-0}" "-p:BuildBranch=${BUILD_BRANCH:-}")
        [ "${AOT:-}" = true ] && vArgs+=(-p:RunAOTCompilation=true)
        dotnet publish "$PROJECT" "${vArgs[@]}"
        vSite=${OUTPUT:-$RUNNER_TEMP_DIR/dotnet-publish/wwwroot}
      fi
      ;;
    flutter)
      cd "$vDir"
      flutter pub get
      if [ -n "${TEST:-}" ]; then bash -c "$TEST"; fi
      if [ -n "${BUILD:-}" ]; then
        bash -c "$BUILD"
      elif flutter build web -h 2>/dev/null | grep -q -- '--pwa-strategy'; then
        flutter build web --release --pwa-strategy=none
      else
        flutter build web --release
      fi
      vSite=${OUTPUT:-build/web}
      ;;
    static)
      cd "$vDir"
      if [ -n "${BUILD:-}" ]; then bash -c "$BUILD"; fi
      vSite=${OUTPUT:-.}
      ;;
    *) fail "Techno inconnue : $TECHNO." ;;
  esac

  [ -f "$vSite/index.html" ] || fail "Pas d'index.html dans le dossier buildé ($vSite)."
  rm -rf "$vOut"
  mkdir -p "$vOut"
  (cd "$vSite" && tar --exclude=./.git --exclude=./.github -cf - .) | tar -xf - -C "$vOut"
  echo "Site buildé : $vSite → $vOut"
}

RUNNER_TEMP_DIR=${RUNNER_TEMP:-$(mktemp -d)}
case "${1:-}" in
  detect) shift; detect "$@" ;;
  run) shift; run "$@" ;;
  *) fail "Usage : build.sh detect|run ..." ;;
esac
