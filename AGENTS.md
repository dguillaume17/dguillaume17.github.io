# dguillaume17.github.io — instructions for agents

GitHub Pages user site, served from `main` at the root. Hosts the sites of the owner's other repositories, one per repository and branch, at `https://dguillaume17.github.io/<repo>/<branch>/`, and the reusable workflows that build and publish them. README.md is for humans (minimal: how to connect a repository, inputs); everything else is here. Workflow files have no comments: their behavior is documented here.

## Layout

```
.github/workflows/publish.yml      common reusable workflow (workflow_call): deploy or remove the site of one branch of the caller
.github/workflows/<tech>.yml       one per technology (angular, blazor, react, flutter): build then publish.yml, or remove, depending on the caller's event
.github/scripts/publish.sh         the publication itself, run by publish.yml
build-check.js                     shared script loaded by every published site (served at /build-check.js)
index.html                         list of the sites, rendered from sites.json
sites.json                         one object per site: path, repository, source, branch, url, commit, build, updatedAt
.nojekyll                          without it GitHub ignores folders starting with _ (Blazor's _framework)
<repo>/<branch>/                   published sites: written only by publish.sh, never by hand
```

## How publication works

- Two levels. publish.yml is technology-agnostic: it takes a static folder with an `index.html` (artifact `site`). Everything technology-specific lives in `<tech>.yml`, which has defaults for a standard project and inputs for the rest. The caller's `deploy.yml` only forwards its events (`push` on any branch, `delete`) and its `PAGES_TOKEN` secret.
- `<tech>.yml`: `build` job on `push`/`workflow_dispatch` (setup, install, tests, build, upload artifact `site`), then `publish` (publish.yml); `remove` job on `delete` of a branch (publish.yml with `action: remove`, `branch: ${{ github.event.ref }}`; on a delete event `github.ref_name` is the default branch, hence the explicit input). Technology workflows call `publish.yml@main` by full path, not `./`.
- publish.yml runs inside the caller's run: `github.repository`, `github.ref_name`, `github.run_number` (the build number: +1 per run of the caller's workflow, all branches), the artifacts and `GITHUB_TOKEN` are the caller's. Inputs: `action` (`deploy`/`remove`), `artifact` (`site`), `branch` (default: the run's), `badge` (`true`); secret `PAGES_TOKEN`; output `url`. Concurrency group per caller repository and branch.
- It clones this repository with `PAGES_TOKEN` (caller's secret: fine-grained PAT, Contents read and write on this repository only), lists the caller's branches with the caller's `GITHUB_TOKEN` (needs `contents: read`; on API error, no cleanup), and runs publish.sh.
- publish.sh (`deploy|remove <owner/repo> <branch> [site-dir]`; env `PAGES_URL`, `COMMIT_SHA`, `BUILD_NUMBER`, `BADGE`, `EXISTING_BRANCHES_FILE`):
  - folder `<repo>/<branch>/`, both slugged: lowercase, every run of characters other than `a-z0-9` becomes `-` (`feature/Form` → `feature-form`); two branches with the same slug share a folder;
  - deploy: replaces the folder, writes `build.json` (number, branch, commit, date); in `index.html`: `<base href>` → `/<repo>/<branch>/`, `?build=<number>` added to relative `href`/`src` without query, `data-index-version="<number>"` added to `<html>`, `<script src="/build-check.js" data-badge="true|false">` injected before `</head>`;
  - remove: deletes the folder;
  - both: removes the caller's folders whose branch no longer exists (only the caller's folder, never another repository's), updates `sites.json`, commits (« Publie <path>, build n° N (...) » / « Supprime <path> (...) ») and pushes to `main`; when `main` moved meanwhile, resets and applies again (5 attempts).
- build-check.js (one file for every site; a change applies to all of them without republishing, within the 10-minute cache): fetches `build.json?t=<ISO date-time>` without cache, sets `data-build-version` and `data-build-branch` on `<html>`; when `data-index-version` < `data-build-version` the page came from a cache: reloads once with `?build=<number>` (a URL never cached; if the URL already has it, keeps the page: no loop); otherwise shows a small fixed badge « n° <index version> · <branch> » bottom right unless `data-badge="false"`. `build.json` is fetched relative to the page's `<base href>`, i.e. the site's folder.
- Build number in an application: read `document.documentElement.dataset.indexVersion` (attribute `data-index-version`, present before the application starts; the version of the code running). `data-build-version` is the version online, set later (asynchronously). Absent locally (no publication): show e.g. `dev`. An application showing it should set `badge: false`.
- Cache: GitHub Pages serves everything with `max-age=600` (browser and CDN); headers cannot be changed. Only new URLs bypass it: `?build=` on assets, `sites.json?t=` in index.html. The first publication of a site, or a page cached before build-check.js was referenced, can stay stale up to ~10 minutes.
- Constraints on a published site: works under a subfolder (relative paths; `<base href>` is rewritten; absolute `/…` paths written in the code are not); GitHub Pages serves only the root `404.html`, so client-side routing by path breaks deep links: use `#` routing.

## Technology notes

- angular.yml: defaults fit `ng new` (Vitest, `npm test -- --watch=false`); output = the single `dist/*/browser` (else `output-path`). Angular emits relative paths.
- blazor.yml: `dotnet publish` of the single project using `Microsoft.NET.Sdk.BlazorWebAssembly` (else `project`); publishes `<out>/wwwroot`; passes MSBuild properties `BuildNumber` (run number) and `BuildBranch` (env) for an app that shows them; `-p:CompressionEnabled=false` (precompressed copies of index.html would miss publish.sh's changes; Pages compresses anyway); `aot: true` installs `wasm-tools` and sets `RunAOTCompilation` (faster code, heavier download, longer build).
- react.yml: Vite; `--base=./` makes Vite emit `./assets/…` instead of `/assets/…`; public files referenced as `/x` in code miss the subfolder (import them or use `import.meta.env.BASE_URL`); Create React App: `build-command: npm run build` and `"homepage": "."`. Tests run only if a `test` script exists (`CI=true` on Actions runs them once).
- flutter.yml: `subosito/flutter-action@v2` (stable, or `flutter-version`); tests only if `test/` exists; output `build/web`; `--pwa-strategy=none` avoids a service worker serving an old build. Not tested yet on a real repository.
- Tested locally: publish.sh (bare repo as origin), Angular, Blazor and React builds served under a subfolder with the badge. Live: Angular.

## Connecting a new repository

In a session that has the new repository (and this one, to read the workflows):

1. Find the technology's workflow. None: create `<tech>.yml` modeled on angular.yml (same build/publish/remove jobs, defaults for a standard project), test it locally, add it to the README (instruction and inputs table) and to Technology notes.
2. Check the repository against the workflow's defaults (project folder, test and build commands, output folder): run them in the session; they must pass and produce an `index.html`.
3. Check the site works under a subfolder (see constraints above); fix it in the repository if needed and say so.
4. Write `.github/workflows/deploy.yml` in the new repository: the README example with the technology's workflow, and under `with:` only the inputs that differ from the defaults. No build or publication logic in the repository.
5. Agents cannot create secrets: ask the user to add `PAGES_TOKEN` to the new repository (Settings → Secrets and variables → Actions) with the existing token. Without it, `publish` fails at the clone of this repository.
6. Push, then follow the run (GitHub Actions tools): `build` and `publish` succeed, a commit « Publie <repo>/<branch>, build n° N » lands on `main` here, `<repo>/<branch>/build.json` and the `sites.json` entry exist. Sessions often cannot reach `github.io`: ask the user to open `https://dguillaume17.github.io/<repo>/<branch>/` and check the badge.

A technology without a workflow can also call publish.yml directly: a `build` job uploads the static site as artifact `site`, then a job `uses: dguillaume17/dguillaume17.github.io/.github/workflows/publish.yml@main` with the `PAGES_TOKEN` secret, plus a `remove` job on `delete`. Prefer creating `<tech>.yml` as soon as a second repository uses the technology.

## Rules

- Callers use `@main`: a push to `main` changes every caller at its next run. Test publish.sh locally first (bare repo as `origin`, two clones for a concurrent push; build-check.js on a site served locally from the clone's root, with Playwright).
- Publication commits land on `main` continuously: `git pull` before any change.
- A change of contract (workflow inputs, site layout, fields of sites.json or build.json) goes into this file, the README when it lists it, and the caller repositories.
- Workflow files have no comments; their documentation is this file.
- User-facing text (README, index.html, workflow step names, error messages) in French; code and this file in English.
