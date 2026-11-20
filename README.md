# dguillaume17.github.io

Héberge les sites de mes repos : **[liste des sites publiés](https://dguillaume17.github.io/)**.

Le workflow *Build* d'un repo lance le `build.sh` d'une branche, dépose le résultat dans la branche `build/<branche>` du repo, et ce repo-ci le publie sur `https://dguillaume17.github.io/<repo>/<branche>/`. Supprimer `build/<branche>` supprime le site.

## Utilisation

- **Publier** : dans le repo, *Actions → Build → Run workflow*, choisir la branche (liste « Use workflow from », ou champ `branche`). Le site est en ligne une minute environ après la fin du build.
- **Mettre à jour** : relancer *Build* sur la même branche (`build/<branche>` est remplacée).
- **Dépublier** : supprimer la branche `build/<branche>` du repo.

Le build et ses logs restent dans le repo (privé ou non) ; seul le site buildé arrive ici.

## Brancher un repo

1. Ajouter `.github/workflows/build.yml` :

```yaml
name: Build
on:
  workflow_dispatch:
    inputs:
      branche:
        description: Branche à builder (vide = celle choisie ci-dessus)
  delete:
permissions:
  contents: write
jobs:
  build:
    uses: dguillaume17/dguillaume17.github.io/.github/workflows/build.yml@main
    secrets: inherit
```

2. Ajouter un `build.sh` à la racine de chaque branche à publier (voir ci-dessous) et, selon la techno, `.nvmrc`, `global.json` ou `.flutter-version`.
3. Ajouter le secret `PAGES_TOKEN` au repo (*Settings → Secrets and variables → Actions*) : jeton fine-grained limité à `dguillaume17.github.io`, permission *Contents: Read and write*.

## build.sh

Le workflow lance `bash ./build.sh <sortie>` à la racine de la branche ; sans `build.sh`, le build s'arrête. `build.sh` builde (tests compris) et remplit `<sortie>` :

- un `index.html` à la racine de `<sortie>` : un site, `…/<repo>/<branche>/` ;
- sinon, un sous-dossier par site, chacun avec son `index.html` (nom en minuscules, chiffres et tirets) : `…/<repo>/<branche>/<site>/`.

Les scripts génériques de [`.github/build/`](.github/build) font le travail ; la variable `BUILD_SCRIPTS` donne leur dossier :

```bash
#!/usr/bin/env bash
set -euo pipefail
"${BUILD_SCRIPTS:?Définir BUILD_SCRIPTS}/angular.sh" "$1"
```

Deux sites dans la même branche (solution .NET avec Blazor et Avalonia) :

```bash
#!/usr/bin/env bash
set -euo pipefail
"${BUILD_SCRIPTS:?Définir BUILD_SCRIPTS}/blazor.sh" "$1/blazor" src/MonApp.Blazor
"$BUILD_SCRIPTS/avalonia.sh" "$1/avalonia" src/MonApp.Browser --sans-tests
```

| Script | Fait | Site publié |
|---|---|---|
| `angular.sh` | `npm ci`, `npm test -- --watch=false`, `npm run build` | le seul `dist/*/browser` |
| `vite.sh` (React, Vue, Svelte…) | `npm ci`, `npm run test --if-present`, `npm run build -- --base=./` | `dist` |
| `blazor.sh` | `dotnet test` des projets de tests, `dotnet publish` (`--aot` : compilation AOT) | `wwwroot` |
| `avalonia.sh` (projet `.Browser`) | installe `wasm-tools`, puis comme `blazor.sh` | `wwwroot` |
| `flutter.sh` | `flutter pub get`, `flutter test` si `test/`, `flutter build web` | `build/web` |
| `static.sh` | rien (ou `--build`) | le dossier |

Arguments communs : `<sortie> [projet]` (dossier, ou `.csproj` ; par défaut la racine), `--sans-tests`, `--test "<commande>"`, `--build "<commande>"`, `--sortie <dossier buildé>`. Un `build.sh` peut aussi contenir ses propres commandes.

Versions des outils, installées par le workflow d'après le repo : Node si `.nvmrc` ou `.node-version`, .NET si `global.json`, Flutter si `.flutter-version` ; sinon, ceux de la machine GitHub.

En local : cloner ce repo-ci, puis `BUILD_SCRIPTS=<clone>/.github/build bash ./build.sh /tmp/site`.

## Contraintes du site

Le site doit fonctionner dans un sous-dossier : chemins relatifs, routage par `#`.

Build dans le code de l'application : attributs `data-build-version` (numéro), `data-build-branch` et `data-build-datetime` (date UTC ISO du build) de la balise `<html>`, présents dès le chargement (absents en local).

## Secrets

- `PAGES_TOKEN`, dans chaque repo : demande la publication à ce repo-ci.
- `SOURCES_TOKEN`, dans ce repo-ci : jeton fine-grained en lecture (*Contents: Read*) sur les repos privés, pour récupérer leurs branches `build/…`. Inutile pour les repos publics.
