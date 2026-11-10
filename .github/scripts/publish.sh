#!/usr/bin/env bash
# Publishes or removes one site of a caller repository in this repository (dguillaume17.github.io), then pushes to main.
# Run by .github/workflows/publish.yml, from the root of a clone of this repository that can push.
#
# Usage:
#   publish.sh deploy <owner/repo> <branch> <site-dir>   site-dir: the built static site (with its index.html)
#   publish.sh remove <owner/repo> <branch>
#
# - A site lives in <repo>/<branch>/, both names slugged: lowercase, every run of other characters than a-z0-9 becomes "-".
# - deploy: replaces the folder with site-dir and writes its cache.json ({"buildVersion": <number>}); in its index.html:
#   - points <base href> to the folder;
#   - adds ?build=<number> to the local files it references (relative href/src without query): never served from cache;
#   - adds data-build-version, data-build-branch and data-build-datetime (UTC, ISO 8601) to <html>: the build
#     information, static in the page;
#   - adds <script src="/cache-verification.js"> before </head> (shared file at the root of this repository): reloads
#     the page when it comes from a cache;
#   - unless BADGE is false, adds before </body> a small fixed badge « n° <number> · <branch> ».
# - sites.json lists every published site (index.html displays it); each change updates it.
# - Cleanup: when EXISTING_BRANCHES_FILE names a file listing the caller's branches (one per line), the caller's sites
#   whose branch no longer exists are removed too. Only the caller's folder is ever touched.
# - Another run may push in the meantime: the change is applied again on the new main, a few times.
# Environment: PAGES_URL (site root, no trailing slash), COMMIT_SHA and BUILD_NUMBER (deploy), BADGE (deploy, true or
# false, default true), EXISTING_BRANCHES_FILE (optional), GITHUB_OUTPUT and GITHUB_STEP_SUMMARY (optional).
set -euo pipefail

slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# Build number, cache busting and build check in the index.html of the deployed site.
prepare_index() {
  local vIndex="$SITE_PATH/index.html"
  sed -i -E "s|<base href=\"[^\"]*\"|<base href=\"/$SITE_PATH/\"|" "$vIndex"
  BUILD_NUMBER=$BUILD_NUMBER perl -pi -e \
    's/(?<=\s)(href|src)="(?![a-zA-Z][a-zA-Z0-9+.-]*:|\/|#)([^"?#]+)"/$1="$2?build=$ENV{BUILD_NUMBER}"/g' "$vIndex"
  if grep -qiE '<html[ >]' "$vIndex" && grep -qi '</head>' "$vIndex" && grep -qi '</body>' "$vIndex"; then
    BUILD_NUMBER=$BUILD_NUMBER BRANCH=$BRANCH UPDATED_AT=$UPDATED_AT BADGE=$BADGE perl -0pi -e '
      sub escape { my $v = shift; $v =~ s/&/&amp;/g; $v =~ s/"/&quot;/g; $v =~ s/</&lt;/g; $v =~ s/>/&gt;/g; return $v }
      my $branch = escape($ENV{BRANCH});
      s/<html(?=[\s>])/<html data-build-version="$ENV{BUILD_NUMBER}" data-build-branch="$branch" data-build-datetime="$ENV{UPDATED_AT}"/i;
      s/<\/head>/  <script src="\/cache-verification.js"><\/script>\n  <\/head>/i;
      if ($ENV{BADGE} eq "true") {
        my $style = "position:fixed;right:8px;bottom:8px;z-index:2147483647;padding:2px 8px;border-radius:10px;"
          . "background:rgba(0,0,0,.6);color:#fff;font:11px\/1.6 system-ui,sans-serif;pointer-events:none";
        s/<\/body>/  <div data-build-badge style="$style">n° $ENV{BUILD_NUMBER} · $branch<\/div>\n  <\/body>/i;
      }' "$vIndex"
  else
    echo "::warning::index.html sans <html>, </head> ou </body> : pas d'informations de build ni de vérification du cache."
  fi
}

# Applies the change to the working tree.
apply_change() {
  [ -f sites.json ] || echo '[]' > sites.json

  if [ "$ACTION" = deploy ]; then
    rm -rf "$SITE_PATH"
    mkdir -p "$SITE_PATH"
    cp -a "$SITE_DIR"/. "$SITE_PATH"/
    prepare_index
    jq -n --argjson buildVersion "$BUILD_NUMBER" '{buildVersion: $buildVersion}' > "$SITE_PATH/cache.json"
    jq --arg path "$SITE_PATH" --arg repository "$REPOSITORY_SLUG" --arg source "$REPOSITORY" \
       --arg branch "$BRANCH" --arg url "$PAGES_URL/$SITE_PATH/" --arg commit "$COMMIT_SHA" \
       --argjson build "$BUILD_NUMBER" --arg updatedAt "$UPDATED_AT" \
       '[.[] | select(.path != $path)]
        + [{path: $path, repository: $repository, source: $source, branch: $branch, url: $url,
            commit: $commit, build: $build, updatedAt: $updatedAt}]
        | sort_by(.path)' sites.json > sites.json.tmp
    mv sites.json.tmp sites.json
  else
    rm -rf "$SITE_PATH"
  fi

  if [ -n "${EXISTING_BRANCHES_FILE:-}" ] && [ -s "$EXISTING_BRANCHES_FILE" ] && [ -d "$REPOSITORY_SLUG" ]; then
    local vExisting fFolder fBranch
    vExisting=$(while IFS= read -r fBranch; do slug "$fBranch"; echo; done < "$EXISTING_BRANCHES_FILE")
    for fFolder in "$REPOSITORY_SLUG"/*/; do
      fFolder=$(basename "$fFolder")
      if [ "$fFolder" != "$BRANCH_SLUG" ] && ! grep -qxF "$fFolder" <<< "$vExisting"; then
        echo "Branche disparue : suppression de $REPOSITORY_SLUG/$fFolder/"
        rm -rf "${REPOSITORY_SLUG:?}/$fFolder"
      fi
    done
  fi
  if [ -d "$REPOSITORY_SLUG" ]; then
    rmdir --ignore-fail-on-non-empty "$REPOSITORY_SLUG"
  fi

  # Drops the caller's entries whose folder no longer exists.
  local vPath vKept='[]'
  for vPath in $(jq -r --arg repository "$REPOSITORY_SLUG" '.[] | select(.repository == $repository) | .path' sites.json); do
    if [ -d "$vPath" ]; then
      vKept=$(jq -c --arg path "$vPath" '. + [$path]' <<< "$vKept")
    fi
  done
  jq --arg repository "$REPOSITORY_SLUG" --argjson kept "$vKept" \
     '[.[] | select(.repository != $repository or (.path as $p | $kept | index($p)))]' sites.json > sites.json.tmp
  mv sites.json.tmp sites.json
}

main() {
  ACTION=${1:?action manquante (deploy ou remove)}
  REPOSITORY=${2:?repo manquant (owner/repo)}
  BRANCH=${3:?branche manquante}
  case "$ACTION" in
    deploy)
      SITE_DIR=${4:?dossier du site manquant}
      : "${PAGES_URL:?PAGES_URL manquant}" "${COMMIT_SHA:?COMMIT_SHA manquant}"
      if ! [[ "${BUILD_NUMBER:-}" =~ ^[0-9]+$ ]]; then
        echo "::error::BUILD_NUMBER doit être un nombre : ${BUILD_NUMBER:-(vide)}."
        exit 1
      fi
      BADGE=${BADGE:-true}
      if [ "$BADGE" != true ] && [ "$BADGE" != false ]; then
        echo "::error::BADGE doit valoir true ou false : $BADGE."
        exit 1
      fi
      if [ ! -f "$SITE_DIR/index.html" ]; then
        echo "::error::Le site à publier n'a pas d'index.html à sa racine ($SITE_DIR)."
        exit 1
      fi
      ;;
    remove) ;;
    *)
      echo "::error::Action inconnue : $ACTION (deploy ou remove)."
      exit 1
      ;;
  esac

  REPOSITORY_SLUG=$(slug "${REPOSITORY#*/}")
  BRANCH_SLUG=$(slug "$BRANCH")
  if [ -z "$REPOSITORY_SLUG" ] || [ -z "$BRANCH_SLUG" ]; then
    echo "::error::Nom de repo ou de branche inutilisable dans une adresse : $REPOSITORY, $BRANCH."
    exit 1
  fi
  SITE_PATH="$REPOSITORY_SLUG/$BRANCH_SLUG"
  UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local vMessage
  if [ "$ACTION" = deploy ]; then
    vMessage="Publie $SITE_PATH, build n° $BUILD_NUMBER ($REPOSITORY@${COMMIT_SHA:0:7})"
  else
    vMessage="Supprime $SITE_PATH (branche $BRANCH de $REPOSITORY supprimée)"
  fi

  local fAttempt
  for fAttempt in 1 2 3 4 5; do
    apply_change
    git add -A
    if git diff --cached --quiet; then
      echo "Aucun changement à publier."
      break
    fi
    git commit -q -m "$vMessage"
    if git push -q origin HEAD:main; then
      break
    fi
    if [ "$fAttempt" = 5 ]; then
      echo "::error::Impossible de pousser sur main après $fAttempt essais."
      exit 1
    fi
    echo "main a changé entre-temps : nouvel essai ($fAttempt)."
    sleep $((fAttempt * 2))
    git fetch -q --depth=1 origin main
    git reset -q --hard origin/main
    git clean -qfd
  done

  if [ "$ACTION" = deploy ]; then
    echo "Site de la branche \`$BRANCH\` (build n° $BUILD_NUMBER) : $PAGES_URL/$SITE_PATH/" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
    echo "url=$PAGES_URL/$SITE_PATH/" >> "${GITHUB_OUTPUT:-/dev/null}"
  else
    echo "Site de la branche \`$BRANCH\` supprimé ($SITE_PATH/)." | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
  fi
}

# The whole script is read before running: the reset above may rewrite this very file.
main "$@"
exit
