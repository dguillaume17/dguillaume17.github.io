# dguillaume17.github.io — instructions for agents

GitHub Pages user site, served from `main` at the root. Hosts the sites of the owner's other repositories, at `https://dguillaume17.github.io/<repo>/<branch>/` (or `<repo>/<branch>/<site>/` for a branch with several sites), and the workflows and generic build scripts that build and publish them. README.md is for humans (usage, connecting a repository, build.sh); everything else is here. Workflow files have no comments: their behavior is documented here.

## Layout

```
.github/workflows/build.yml        reusable workflow called by each repository's build.yml: runs the branch's build.sh, puts the result in build/<branch> of that repository, then asks for publication (or removal, on deletion of build/<branch>)
.github/workflows/publish.yml      runs here on repository_dispatch (deploy/remove) or by hand: copies build/<branch> of a repository into <repo>/<branch>/
.github/build/                     generic build scripts called by the repositories' build.sh (angular, vite, blazor, avalonia, flutter, static; lib.sh shared)
.github/scripts/publish.sh         the publication itself, run by publish.yml
cache-verification.js              shared script loaded by every published site (served at /cache-verification.js): only reloads a page served from a cache
index.html                         list of the sites, rendered from sites.json
sites.json                         one object per site: path, repository, source, branch, site, url, commit, build, updatedAt
.nojekyll                          without it GitHub ignores folders starting with _ (Blazor's _framework)
<repo>/<branch>/                   published sites: written only by publish.sh, never by hand
```

## Flow

1. In a repository, the user runs its *Build* workflow (`workflow_dispatch`) on a branch: input `branche`, else the branch picked in « Use workflow from ». The repository's `build.yml` is the README's: `workflow_dispatch` (input `branche`) and `delete` triggers, `permissions: contents: write`, one job `uses: dguillaume17/dguillaume17.github.io/.github/workflows/build.yml@main` with `secrets: inherit`. The reusable workflow reads `github.event.inputs.branche` from the caller's event (the `github` context of a called workflow is the caller's). Each branch to publish has a `build.sh` at its root.
2. build.yml, job `build` (any event but `delete`; runs in the repository's run: its minutes, its private logs; concurrency per repository and branch, cancel-in-progress; timeout 30 min):
   - refuses a `build/…` branch, fails when the branch does not exist (`git/matching-refs` API);
   - checks out `.github/build` of this repository (input `common-ref`, default `main`; public, no token) and the branch;
   - fails without `build.sh` at the root of the branch;
   - sets up tools from the branch's version files only: Node (`setup-node`, `node-version-file` `.nvmrc` or `.node-version`; npm cache when a `package-lock.json` exists), .NET (`setup-dotnet`, `global.json`), Flutter (`flutter-action`, stable channel, version from `.flutter-version`); otherwise the runner's preinstalled tools;
   - runs `bash ./build.sh "$RUNNER_TEMP/site"` from the branch root with `BUILD_SCRIPTS` (the checked-out `.github/build`), `BUILD_NUMBER`, `BUILD_BRANCH`, `BUILD_DATETIME`;
   - checks the output: an `index.html` at its root (one site), else subfolders holding an `index.html`, named `[a-z0-9]+(-[a-z0-9]+)*` (one site each);
   - writes `.build.json` (`repository`, `branch`, `commit`, `buildNumber` = `github.run_number` of the repository's Build workflow, `buildDatetime` = UTC ISO 8601 at the start of the build) and force-pushes the output as a single orphan commit to `build/<branch>` with the repository's `GITHUB_TOKEN` (no history: the repository does not grow with every build; a push by `GITHUB_TOKEN` triggers no workflow);
   - sends `repository_dispatch` `deploy` (`client_payload`: `repository` owner/name, `branch`) to this repository with `PAGES_TOKEN`.
3. build.yml, job `remove` (on `delete` of a `build/…` branch; the workflow runs from the repository's default branch): sends `repository_dispatch` `remove` with the branch without `build/`.
4. publish.yml here (`repository_dispatch` deploy/remove, or `workflow_dispatch`: `repository`, `branche`, `action` publier/supprimer; `permissions: contents: write`; concurrency per repository and branch, no cancel; timeout 10 min):
   - validates the parameters: repository of the owner only, valid branch name;
   - deploy: checks out `build/<branch>` of the repository with `SOURCES_TOKEN` (else `GITHUB_TOKEN`: public repositories only), reads and removes `.build.json` and `.git`;
   - lists the repository's `build/…` branches (same token; on API error, no cleanup);
   - runs publish.sh, which pushes to `main` with this repository's `GITHUB_TOKEN` (GitHub Pages deploys pushes made with `GITHUB_TOKEN`).
5. Agents publish by running the repository's Build workflow: GitHub tool `actions_run_trigger`, `run_workflow`, `workflow_id: build.yml`, `ref: <a branch that has the workflow, e.g. the default one>`, `inputs: {"branche": "<branch>"}`; then follow the run in the repository and publish.yml here, and give the URL(s). Unpublish: delete `build/<branch>` (git push `--delete`). Republish an existing build without rebuilding: publish.yml by hand.

## Generic build scripts (.github/build)

- Called by a repository's `build.sh` as `"$BUILD_SCRIPTS/<tech>.sh" <out> [project] [options]`, from the branch root. Locally, `BUILD_SCRIPTS` points to `.github/build` of a clone of this repository (no download fallback, owner's choice); `build.sh` fails clearly when it is missing (`${BUILD_SCRIPTS:?…}`).
- lib.sh (sourced): arguments `<out>` (created; must not already hold an `index.html`), `[project]` (folder or `.csproj`, default `.`), `--sans-tests`, `--test "<command>"`, `--build "<command>"`, `--sortie <built folder>`; `BUILD_NUMBER`/`BUILD_BRANCH` default to `0`/`local`; tests run with `CI=true`; the built folder is copied to `<out>` without `.git`, `.github` and a root `build.sh`; `install_workload` retries with `sudo -n` when the SDK folder is not writable (preinstalled SDK on runners).
- angular.sh: `npm ci`, `npm test -- --watch=false`, `npm run build`, the single `dist/*/browser`.
- vite.sh: `npm ci`, `npm run test --if-present`, `npm run build -- --base=./` (Vite emits `./assets/…` instead of `/assets/…`), `dist`. Create React App: `--build "npm run build" --sortie build` and `"homepage": "."`.
- blazor.sh: `dotnet test -c Release` of each `.csproj` referencing `Microsoft.NET.Test.Sdk` under the current folder (none: no tests), `dotnet publish <project> -c Release -p:CompressionEnabled=false -p:BuildNumber -p:BuildBranch` (precompressed copies of index.html would miss publish.sh's changes; Pages compresses anyway), `wwwroot` of the publication; `--aot` installs `wasm-tools` and sets `RunAOTCompilation`. With `--build`, `--sortie` is required.
- avalonia.sh: installs `wasm-tools` (required by `Avalonia.Browser`), then blazor.sh. Several .NET sites in one branch: `--sans-tests` on all but one call, or the tests run several times.
- flutter.sh: `flutter pub get`, `flutter test` if `test/`, `flutter build web --release` (+ `--pwa-strategy=none` when the option exists: no service worker serving an old build), `build/web`.
- static.sh: optional `--build`, then the folder.

## publish.sh

- `deploy|remove <owner/repo> <branch> [site-dir]`; env `PAGES_URL`, `COMMIT_SHA`, `BUILD_NUMBER`, `BUILD_DATETIME` (default now), `EXISTING_BRANCHES_FILE` (built branches, without `build/`).
- Folder `<repo>/<branch>/`, both slugged: lowercase, every run of characters other than `a-z0-9` becomes `-` (`feature/Form` → `feature-form`); two branches with the same slug share a folder.
- deploy: replaces the branch folder with site-dir. Sites: site-dir's root if it has an `index.html`, else each subfolder holding one (names checked as in build.yml). For each site: `cache.json` (`{"buildVersion": <number>}`, nothing else); in its `index.html`: `<base href>` → the site's folder, `?build=<number>` added to relative `href`/`src` without query, `data-build-version="<number>"`, `data-build-branch` (HTML-escaped) and `data-build-datetime` (the build's) added to `<html>`, `<script src="/cache-verification.js">` injected before `</head>`; one `sites.json` entry (`site`: `""` for a single site), after dropping every entry of the branch folder.
- remove: deletes the branch folder (all its sites).
- Both: removes the repository's branch folders whose `build/<branch>` no longer exists (only that repository's folder), drops the `sites.json` entries whose folder is gone, commits (« Publie <path>, build n° N (...) » / « Supprime <path> (...) ») and pushes to `main`; when `main` moved meanwhile, resets and applies again (5 attempts).

## Build information and cache

- Build number: `github.run_number` of the repository's Build workflow (+1 per run, all branches), the same for all sites of a build; increases for every site of the repository. Renaming the repository's `build.yml` restarts it at 1 (pages cached under a higher number then stay stale up to ~10 minutes).
- Publication adds nothing visible: it writes the build information as static attributes, and each application decides how to show it (e.g. its own badge component). Nothing is injected into the DOM after load (owner's choice).
- Build information in an application: read `document.documentElement.dataset` `buildVersion`, `buildBranch`, `buildDatetime`, synchronously at startup. Absent locally: show e.g. `dev`. .NET apps also get MSBuild properties `BuildNumber` and `BuildBranch`.
- cache-verification.js (one file for every site; a change applies to all of them within the 10-minute cache) only checks the cache, and never writes to the DOM: fetches `cache.json?t=<ISO date-time>` without cache (relative to the page's `<base href>`, i.e. the site's folder); when the page's `data-build-version` is lower than `buildVersion`, the page came from a cache: reloads once with `?build=<number>` (a URL never cached; if the URL already has it, keeps the page: no loop).
- GitHub Pages serves everything with `max-age=600` (browser and CDN); headers cannot be changed. Only new URLs bypass it: `?build=` on assets, `sites.json?t=` in index.html.
- Constraints on a published site: works under a subfolder (relative paths; `<base href>` is rewritten; absolute `/…` paths written in the code are not, e.g. Vite public files referenced as `/x`: import them or use `import.meta.env.BASE_URL`); GitHub Pages serves only the root `404.html`: use `#` routing.

## Secrets and tokens

- `PAGES_TOKEN` (each repository): fine-grained PAT, Contents read and write on this repository only; used for `repository_dispatch` here. Agents cannot create secrets: ask the user.
- `SOURCES_TOKEN` (this repository): fine-grained PAT, Contents read on the private repositories (all repositories, read-only, avoids editing it for each new one); used to check out `build/…` and list branches. Missing: only public repositories can be published.
- Writing here: this repository's `GITHUB_TOKEN`. The repository's `GITHUB_TOKEN` writes `build/<branch>`.

## Connecting a new repository

1. Write the branch's `build.sh` with the generic scripts (README examples) and the version files (`.nvmrc`, `global.json`, `.flutter-version`); run it locally with `BUILD_SCRIPTS` set: it must pass and produce one site or subfolders of sites.
2. Check the site works under a subfolder (see constraints); fix it in the repository if needed and say so.
3. Add the README's `build.yml` to the repository (on its default branch, so the Actions tab shows it); ask the user for the `PAGES_TOKEN` secret, and for `SOURCES_TOKEN` here when the repository is private and the token does not cover it.
4. Run Build (see Flow, 5) and follow both runs: `build/<branch>` exists in the repository, a commit « Publie <repo>/<branch>, build n° N » lands on `main` here, the sites' `cache.json` and `sites.json` entries exist. Sessions often cannot reach `github.io`: ask the user to open the site and check the build information it shows.

A new technology: add `<tech>.sh` to `.github/build` (with lib.sh), its tool setup to build.yml when it needs one (from a version file), test it locally on a sample, and document it here and in the README.

## Tests

- Tested locally (Linux, Node 22, .NET 10): build.sh with angular.sh (code-lab), vite.sh (Vite React), blazor.sh + avalonia.sh in one branch (two sites), static.sh; argument errors; publish.sh with a bare repository as `origin` (single and multi-site deploys, single ↔ multi on the same branch, remove, cleanup, two clones pushing at once); every site served from the clone's root renders under its folder (Playwright), index.html lists `branch · site`, cache-verification.js reloads with `?build=`. Live (code-lab, before the build.sh model): build.yml up to `build/<branch>` and the dispatch. Flutter: not tested (no SDK here).
- Before pushing to `main`: test the scripts and publish.sh the same way. A repository's Build workflow can test a branch of this repository with `uses: …/build.yml@<branch>` and `with: common-ref: <branch>`; publish.yml always runs from `main` for `repository_dispatch`.

## Rules

- Repositories use `@main`: a push to `main` changes every repository at its next build.
- Publication commits land on `main` continuously: `git pull` before any change.
- A change of contract (the repository's build.yml, the build.sh contract, the generic scripts' arguments, site layout, fields of sites.json, cache.json or .build.json, data-build-* attributes, dispatch payload) goes into this file, the README, and the repositories.
- Workflow files have no comments; their documentation is this file.
- User-facing text (README, index.html, workflow step names, error messages) in French; code and this file in English.
