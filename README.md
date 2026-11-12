# dguillaume17.github.io

Héberge les sites de mes repos : **[liste des sites publiés](https://dguillaume17.github.io/)**.

Chaque push d'un repo (ou chaque lancement à la main) publie le site de sa branche sur `https://dguillaume17.github.io/<repo>/<branche>/` ; supprimer la branche supprime son site.

## Brancher un repo

1. Dans le repo, *Settings → Secrets and variables → Actions*, ajouter le secret `PAGES_TOKEN` : un jeton fine-grained limité à `dguillaume17.github.io`, permission *Contents: Read and write*.
2. Ajouter `.github/workflows/deploy.yml`, avec le workflow de la techno (`angular.yml`, `blazor.yml`, `react.yml` ou `flutter.yml`) :

```yaml
name: Build et publication
on:
  push:
    branches: ['**']
    paths: ['version.json']   # facultatif : build seulement quand ce fichier change
  workflow_dispatch:          # lancement à la main : Actions → Run workflow → branche
  delete:
permissions:
  contents: read
jobs:
  site:
    uses: dguillaume17/dguillaume17.github.io/.github/workflows/react.yml@main
    with:
      node-version: '24'   # facultatif : seulement ce qui change des valeurs par défaut
    secrets:
      PAGES_TOKEN: ${{ secrets.PAGES_TOKEN }}
```

Moins de builds : avec `paths`, un push ne publie que s'il modifie `version.json` (n'importe quel changement du fichier) ; sinon, lancer à la main (*Actions → Build et publication → Run workflow*, ou `gh workflow run deploy.yml --ref <branche>`). Sans `paths`, chaque push publie ; `[skip ci]` dans le message du dernier commit saute un push. Un nouveau push annule le build en cours de la même branche.

Le site doit fonctionner dans un sous-dossier : chemins relatifs, routage par `#`.

Build dans le code de l'application : attributs `data-build-version` (numéro), `data-build-branch` et `data-build-datetime` (date UTC ISO) de la balise `<html>`, présents dès le chargement (absents en local).

## Inputs (`with:`)

Tous facultatifs.

| Workflow | Input | Défaut |
|---|---|---|
| `angular.yml` | `working-directory` | `.` |
| | `node-version` | `22` |
| | `test-command` (vide : pas de tests) | `npm test -- --watch=false` |
| | `build-command` | `npm run build` |
| | `output-path` | le seul `dist/*/browser` |
| `blazor.yml` | `dotnet-version` | `10.0.x` |
| | `project` (.csproj) | le seul projet Blazor WebAssembly |
| | `test-command` (vide : pas de tests) | `dotnet test -c Release` |
| | `aot` (compilation AOT) | `false` |
| | `publish-args` | |
| `react.yml` (Vite) | `working-directory` | `.` |
| | `node-version` | `22` |
| | `test-command` (vide : pas de tests) | `npm run test --if-present` |
| | `build-command` | `npm run build -- --base=./` |
| | `output-path` | `dist`, sinon `build` |
| `flutter.yml` | `working-directory` | `.` |
| | `flutter-version` | dernière stable |
| | `test-command` (vide : pas de tests) | `flutter test` s'il y a un dossier `test` |
| | `build-command` | `flutter build web --release --pwa-strategy=none` |
