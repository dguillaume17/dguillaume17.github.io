# dguillaume17.github.io — instructions for agents

GitHub Pages user site, served from `main` at the root. Hosts the sites of the owner's other repositories, one per repository and built branch, at `https://dguillaume17.github.io/<repo>/<branch>/`, and the workflows that build and publish them. README.md is for humans (minimal: usage, connecting a repository, configuration); everything else is here. Workflow files have no comments: their behavior is documented here.

## Layout

```
.github/workflows/build.yml        reusable workflow called by each repository's build.yml: builds a branch into build/<branch> of that repository, then asks for publication (or removal, on deletion of build/<branch>)
.github/workflows/publish.yml      runs here on repository_dispatch (deploy/remove) or by hand: copies build/<branch> of a repository into <repo>/<branch>/
.github/scripts/build.sh           project detection and build, run by build.yml
.github/scripts/publish.sh         the publication itself, run by publish.yml
.github/builds.json                build configuration: defaults and per-repository overrides
cache-verification.js              shared script loaded by every published site (served at /cache-verification.js): only reloads a page served from a cache
index.html                         list of the sites, rendered from sites.json
sites.json                         one object per site: path, repository, source, branch, url, commit, build, updatedAt
.nojekyll                          without it GitHub ignores folders starting with _ (Blazor's _framework)
<repo>/<branch>/                   published sites: written only by publish.sh, never by hand
```

## Flow

1. In a repository, the user runs its *Build* workflow (`workflow_dispatch`) on a branch: input `branche`, else the branch picked in « Use workflow from ». The repository's `build.yml` is the README's: `workflow_dispatch` (input `branche`) and `delete` triggers, `permissions: contents: write`, one job `uses: dguillaume17/dguillaume17.github.io/.github/workflows/build.yml@main` with `secrets: inherit`. Nothing else in the repository. The reusable workflow reads `github.event.inputs.branche` from the caller's event (the `github` context of a called workflow is the caller's).
2. build.yml, job `build` (any event but `delete`; runs in the repository's run: its minutes, its private logs; concurrency per repository and branch, cancel-in-progress; timeout 30 min):
   - refuses a `build/…` branch, fails when the branch does not exist (`git/matching-refs` API);
   - checks out this repository (input `common-ref`, default `main`; public, no token) for build.sh and builds.json, and the branch;
   - `build.sh detect`: project and technology, settings = `defaults` + `repositories.<repo name>` of builds.json;
   - sets up Node (`setup-node`, npm cache), .NET (`setup-dotnet`, the repository's `global.json` if any, else `dotnet`), `wasm-tools` (Avalonia, or `aot`), Flutter (`flutter-action`, stable or `flutter`);
   - `build.sh run`: install, tests, build, copy of the built folder (with its `index.html`) to `$RUNNER_TEMP/site`;
   - writes `.build.json` (`repository`, `branch`, `commit`, `buildNumber` = `github.run_number` of the repository's Build workflow, `buildDatetime` = UTC ISO 8601 at the start of the build) and force-pushes the folder as a single orphan commit to `build/<branch>` with the repository's `GITHUB_TOKEN` (no history: the repository does not grow with every build; a push by `GITHUB_TOKEN` triggers no workflow);
   - sends `repository_dispatch` `deploy` (`client_payload`: `repository` owner/name, `branch`) to this repository with `PAGES_TOKEN`.
3. build.yml, job `remove` (on `delete` of a `build/…` branch; the workflow runs from the repository's default branch): sends `repository_dispatch` `remove` with the branch without `build/`.
4. publish.yml here (`repository_dispatch` deploy/remove, or `workflow_dispatch`: `repository`, `branche`, `action` publier/supprimer; `permissions: contents: write`; concurrency per repository and branch, no cancel; timeout 10 min):
   - validates the parameters: repository of the owner only, valid branch name;
   - deploy: checks out `build/<branch>` of the repository with `SOURCES_TOKEN` (else `GITHUB_TOKEN`: public repositories only), reads and removes `.build.json` and `.git`;
   - lists the repository's `build/…` branches (same token; on API error, no cleanup);
   - runs publish.sh, which pushes to `main` with this repository's `GITHUB_TOKEN` (GitHub Pages deploys pushes made with `GITHUB_TOKEN`).
5. Agents publish by running the repository's Build workflow: GitHub tool `actions_run_trigger`, `run_workflow`, `workflow_id: build.yml`, `ref: <a branch that has the workflow, e.g. the default one>`, `inputs: {"branche": "<branch>"}`; then follow the run in the repository and publish.yml here, and give the URL. Unpublish: delete `build/<branch>` (git push `--delete`). Republish an existing build without rebuilding: publish.yml by hand.

## build.sh

- `detect <source> <repo name> <config>`: in `project` (folder or `.csproj`) if configured, else the whole branch (without `node_modules`, `bin`, `obj`, `.git`, `dist`, `build`): `angular.json` → `angular`; `pubspec.yaml` with `sdk: flutter` → `flutter`; `.csproj` with `Microsoft.NET.Sdk.BlazorWebAssembly` → `blazor`; `.csproj` with `Microsoft.NET.Sdk.WebAssembly` and `Avalonia.Browser` → `avalonia`; `package.json` (not next to `angular.json`) with `vite` → `vite`, `react-scripts` → `cra`; nothing but an `index.html` at the root → `static`. Exactly one candidate (a configured `techno` filters them), else an error listing them. Writes `techno`, `project`, `directory`, `test`, `build`, `output`, `node`, `dotnet`, `global_json`, `lock_file` (path of package-lock.json for the npm cache), `flutter`, `aot` to `GITHUB_OUTPUT`.
- Defaults per technology: angular `npm test -- --watch=false`, `npm run build`, the single `dist/*/browser`; vite `npm run test --if-present`, `npm run build -- --base=./`, `dist`; cra `npm run test --if-present`, `npm run build`, `build`; blazor/avalonia `dotnet test -c Release` of each `.csproj` referencing `Microsoft.NET.Test.Sdk`, `dotnet publish -c Release -p:CompressionEnabled=false -p:BuildNumber -p:BuildBranch [-p:RunAOTCompilation=true]`, `<out>/wwwroot`; flutter `flutter test` if `test/`, `flutter build web --release` (`--pwa-strategy=none` when supported), `build/web`; static: the folder. Config keys `test`, `build`, `output` replace them (`test: ""` skips tests; with `build` for .NET, `output` is required). npm tools run with `CI=true` for tests and `npm ci` (a lock file is required).
- `run <source> <out>`: environment from detect (`TECHNO`, `PROJECT`, `TEST`, `BUILD`, `OUTPUT`, `AOT`, `BUILD_NUMBER`, `BUILD_BRANCH`); copies the built folder without `.git`/`.github`.

## publish.sh

- `deploy|remove <owner/repo> <branch> [site-dir]`; env `PAGES_URL`, `COMMIT_SHA`, `BUILD_NUMBER`, `BUILD_DATETIME` (default now), `EXISTING_BRANCHES_FILE` (built branches, without `build/`).
- Folder `<repo>/<branch>/`, both slugged: lowercase, every run of characters other than `a-z0-9` becomes `-` (`feature/Form` → `feature-form`); two branches with the same slug share a folder.
- deploy: replaces the folder, writes `cache.json` (`{"buildVersion": <number>}`, nothing else); in `index.html`: `<base href>` → `/<repo>/<branch>/`, `?build=<number>` added to relative `href`/`src` without query, `data-build-version="<number>"`, `data-build-branch` (HTML-escaped) and `data-build-datetime` (the build's) added to `<html>`, `<script src="/cache-verification.js">` injected before `</head>`.
- remove: deletes the folder.
- Both: removes the repository's folders whose `build/<branch>` no longer exists (only that repository's folder), updates `sites.json` (`updatedAt` = build date-time), commits (« Publie <path>, build n° N (...) » / « Supprime <path> (...) ») and pushes to `main`; when `main` moved meanwhile, resets and applies again (5 attempts).

## Build information and cache

- Build number: `github.run_number` of the repository's Build workflow (+1 per run, all branches); increases for every site of the repository. Renaming the repository's `build.yml` restarts it at 1 (pages cached under a higher number then stay stale up to ~10 minutes).
- Publication adds nothing visible: it writes the build information as static attributes, and each application decides how to show it (e.g. its own badge component). Nothing is injected into the DOM after load (owner's choice).
- Build information in an application: read `document.documentElement.dataset` `buildVersion`, `buildBranch`, `buildDatetime`, synchronously at startup. Absent locally: show e.g. `dev`. Blazor/Avalonia also get MSBuild properties `BuildNumber` and `BuildBranch`.
- cache-verification.js (one file for every site; a change applies to all of them within the 10-minute cache) only checks the cache, and never writes to the DOM: fetches `cache.json?t=<ISO date-time>` without cache (relative to the page's `<base href>`); when the page's `data-build-version` is lower than `buildVersion`, the page came from a cache: reloads once with `?build=<number>` (a URL never cached; if the URL already has it, keeps the page: no loop).
- GitHub Pages serves everything with `max-age=600` (browser and CDN); headers cannot be changed. Only new URLs bypass it: `?build=` on assets, `sites.json?t=` in index.html.
- Constraints on a published site: works under a subfolder (relative paths; `<base href>` is rewritten; absolute `/…` paths written in the code are not, e.g. Vite public files referenced as `/x`: import them or use `import.meta.env.BASE_URL`); GitHub Pages serves only the root `404.html`: use `#` routing.

## Secrets and tokens

- `PAGES_TOKEN` (each repository): fine-grained PAT, Contents read and write on this repository only; used for `repository_dispatch` here. Agents cannot create secrets: ask the user.
- `SOURCES_TOKEN` (this repository): fine-grained PAT, Contents read on the private repositories (all repositories, read-only, avoids editing it for each new one); used to check out `build/…` and list branches. Missing: only public repositories can be published.
- Writing here: this repository's `GITHUB_TOKEN`. The repository's `GITHUB_TOKEN` writes `build/<branch>`.

## Connecting a new repository

1. Run detection and build locally on the repository (`build.sh detect`, then `build.sh run` with its output as environment): they must pass and produce an `index.html`; when several projects or non-default commands, add an entry in builds.json.
2. Check the site works under a subfolder (see constraints); fix it in the repository if needed and say so.
3. Add the README's `build.yml` to the repository (on its default branch, so the Actions tab shows it); ask the user for the `PAGES_TOKEN` secret, and for `SOURCES_TOKEN` here when the repository is private and the token does not cover it.
4. Run Build (see Flow, 5) and follow both runs: `build/<branch>` exists in the repository, a commit « Publie <repo>/<branch>, build n° N » lands on `main` here, `<repo>/<branch>/cache.json` and the `sites.json` entry exist. Sessions often cannot reach `github.io`: ask the user to open the site and check the build information it shows.

A new technology: add its detection and build to build.sh, its toolchain setup to build.yml, test it locally on a sample, and document it here and in the README.

## Tests

- Tested locally (Linux, Node 22, .NET 10): detection and build of Angular (code-lab), Vite React, Blazor WebAssembly, Avalonia browser (with `wasm-tools`), static; ambiguous Blazor + Avalonia branch refused, resolved by `project`; publish.sh with a bare repository as `origin` (deploy, remove, cleanup, two clones pushing at once); every site served from the clone's root renders under its subfolder (Playwright), cache-verification.js reloads with `?build=`. Flutter: not tested (no SDK here).
- Before pushing to `main`: test build.sh and publish.sh the same way. A repository's Build workflow can test a branch of this repository with `uses: …/build.yml@<branch>` and `with: common-ref: <branch>`; publish.yml always runs from `main` for `repository_dispatch`.

## Rules

- Repositories use `@main`: a push to `main` changes every repository at its next build.
- Publication commits land on `main` continuously: `git pull` before any change.
- A change of contract (the repository's build.yml, builds.json keys, site layout, fields of sites.json, cache.json or .build.json, data-build-* attributes, dispatch payload) goes into this file, the README, and the repositories.
- Workflow files have no comments; their documentation is this file.
- User-facing text (README, index.html, workflow step names, error messages) in French; code and this file in English.
