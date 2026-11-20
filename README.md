# dguillaume17.github.io

Héberge les sites de mes repos : **[liste des sites publiés](https://dguillaume17.github.io/)**.

Le workflow *Build* d'un repo lance le `build.sh` d'une branche, dépose le résultat dans la branche `build/<branche>` du repo, et ce repo-ci le publie sur `https://dguillaume17.github.io/<repo>/<branche>/`. Supprimer la branche (ou seulement `build/<branche>`) supprime le site.

Ce repo-ci : `main` contient les workflows, le script de publication, le skill `build-dev` et les fichiers communs du site (`.github/pages/`) ; les sites publiés sont sur la branche `builds`, servie par GitHub Pages (*Settings → Pages → Branch : `builds`*).

## Utilisation

- **Publier** : dans le repo, *Actions → Build → Run workflow*, choisir la branche (liste « Use workflow from », ou champ `branche`). Le site est en ligne une minute environ après la fin du build.
- **Mettre à jour** : relancer *Build* sur la même branche (`build/<branche>` est remplacée).
- **Dépublier** : supprimer la branche : `build/<branche>` et le site sont supprimés en cascade. Supprimer seulement `build/<branche>` supprime le site et garde la branche.

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

   Facultatif : `run-name` (titre de chaque exécution) et `with: branch-prefix: dev/` (seules les branches `dev/…` peuvent être buildées) ; voir le `build.yml` de [code-lab](https://github.com/dguillaume17/code-lab).
2. Ajouter un `build.sh` à la racine de chaque branche à publier (voir ci-dessous) et, selon la techno, `.nvmrc`, `global.json` ou `.flutter-version`.
3. Ajouter le secret `PAGES_TOKEN` au repo (*Settings → Secrets and variables → Actions*) : jeton fine-grained limité à `dguillaume17.github.io`, permission *Contents: Read and write*.

## build.sh

Le workflow lance `bash ./build.sh <sortie>` à la racine de la branche ; sans `build.sh`, le build s'arrête. `build.sh` builde (tests compris) et remplit `<sortie>` :

- un `index.html` à la racine de `<sortie>` : un site, `…/<repo>/<branche>/` ;
- sinon, un sous-dossier par site, chacun avec son `index.html` (nom en minuscules, chiffres et tirets) : `…/<repo>/<branche>/<site>/`.

`build.sh` contient tout ce qu'il faut : tests (en une passe, sans interaction), build, puis copie du site statique dans `<sortie>`. Il tourne sur la machine Linux de GitHub ; `BUILD_NUMBER`, `BUILD_BRANCH` et `BUILD_DATETIME` lui sont fournis. Exemple (Angular) :

```bash
#!/usr/bin/env bash
set -euo pipefail
npm ci
npm test -- --watch=false
npm run build
cp -R dist/*/browser/. "$1"
```

Versions des outils, installées par le workflow d'après le repo : Node si `.nvmrc` ou `.node-version`, .NET si `global.json`, Flutter si `.flutter-version` ; sinon, ceux de la machine GitHub.

En local : `bash ./build.sh /tmp/site`.

## Contraintes du site

Le site doit fonctionner dans un sous-dossier : chemins relatifs, routage par `#`.

Build dans le code de l'application : attributs `data-build-version` (numéro), `data-build-branch` et `data-build-datetime` (date UTC ISO du build) de la balise `<html>`, présents dès le chargement (absents en local).

## Skill Claude Code

[`.github/skills/build-dev`](.github/skills/build-dev/SKILL.md) : `/build-dev` builde et publie la branche `dev/…` courante, puis donne l'adresse du site. À copier dans `.claude/skills/` d'un repo (code-lab le fait avec ses skills `create-lab` et `update-lab`).

## Secrets

- `PAGES_TOKEN`, dans chaque repo : demande la publication à ce repo-ci.
- `SOURCES_TOKEN`, dans ce repo-ci : jeton fine-grained en lecture (*Contents: Read*) sur les repos privés, pour récupérer leurs branches `build/…`. Inutile pour les repos publics.
