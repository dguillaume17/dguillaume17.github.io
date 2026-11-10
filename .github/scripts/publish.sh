#!/usr/bin/env bash
# Publishes or removes one site of a caller repository in this repository (dguillaume17.github.io), then pushes to main.
# Run by .github/workflows/publish.yml, from the root of a clone of this repository that can push.
#
# Usage:
#   publish.sh deploy <owner/repo> <branch> <site-dir>   site-dir: the built static site (with its index.html)
#   publish.sh remove <owner/repo> <branch>
#
# - A site lives in <repo>/<branch>/, both names slugged: lowercase, every run of other characters than a-z0-9 becomes "-".
# - deploy: replaces the folder with site-dir, and points <base href> of its index.html to the folder.
# - sites.json lists every published site (index.html displays it); each change updates it.
# - Cleanup: when EXISTING_BRANCHES_FILE names a file listing the caller's branches (one per line), the caller's sites
#   whose branch no longer exists are removed too. Only the caller's folder is ever touched.
# - Another run may push in the meantime: the change is applied again on the new main, a few times.
# Environment: PAGES_URL (site root, no trailing slash), COMMIT_SHA (deploy), EXISTING_BRANCHES_FILE (optional),
# GITHUB_OUTPUT and GITHUB_STEP_SUMMARY (optional).
set -euo pipefail

slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# Applies the change to the working tree.
apply_change() {
  [ -f sites.json ] || echo '[]' > sites.json

  if [ "$ACTION" = deploy ]; then
    rm -rf "$SITE_PATH"
    mkdir -p "$SITE_PATH"
    cp -a "$SITE_DIR"/. "$SITE_PATH"/
    if [ -f "$SITE_PATH/index.html" ]; then
      sed -i -E "s|<base href=\"[^\"]*\"|<base href=\"/$SITE_PATH/\"|" "$SITE_PATH/index.html"
    fi
    jq --arg path "$SITE_PATH" --arg repository "$REPOSITORY_SLUG" --arg source "$REPOSITORY" \
       --arg branch "$BRANCH" --arg url "$PAGES_URL/$SITE_PATH/" --arg commit "$COMMIT_SHA" \
       --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '[.[] | select(.path != $path)]
        + [{path: $path, repository: $repository, source: $source, branch: $branch, url: $url,
            commit: $commit, updatedAt: $updatedAt}]
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

  local vMessage
  if [ "$ACTION" = deploy ]; then
    vMessage="Publie $SITE_PATH ($REPOSITORY@${COMMIT_SHA:0:7})"
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
    echo "Site de la branche \`$BRANCH\` : $PAGES_URL/$SITE_PATH/" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
    echo "url=$PAGES_URL/$SITE_PATH/" >> "${GITHUB_OUTPUT:-/dev/null}"
  else
    echo "Site de la branche \`$BRANCH\` supprimé ($SITE_PATH/)." | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
  fi
}

# The whole script is read before running: the reset above may rewrite this very file.
main "$@"
exit
