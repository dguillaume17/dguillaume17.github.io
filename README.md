# dguillaume17.github.io

Héberge les sites de mes repos : **[liste des sites publiés](https://dguillaume17.github.io/)**.

Le workflow *Build* d'un repo builde une branche, dépose le résultat dans la branche `build/<branche>` du repo, et ce repo-ci le publie sur `https://dguillaume17.github.io/<repo>/<branche>/`. Supprimer `build/<branche>` supprime le site.

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

2. Ajouter le secret `PAGES_TOKEN` au repo (*Settings → Secrets and variables → Actions*) : jeton fine-grained limité à `dguillaume17.github.io`, permission *Contents: Read and write*.
3. Rien d'autre si le repo n'a qu'un projet web : la techno est détectée. Sinon, ou pour changer une commande, ajouter le repo dans [`.github/builds.json`](.github/builds.json) ici.

Le site doit fonctionner dans un sous-dossier : chemins relatifs, routage par `#`.

Build dans le code de l'application : attributs `data-build-version` (numéro), `data-build-branch` et `data-build-datetime` (date UTC ISO du build) de la balise `<html>`, présents dès le chargement (absents en local).

## Technos détectées

| Fichier trouvé | Techno | Build | Dossier publié |
|---|---|---|---|
| `angular.json` | `angular` | `npm test -- --watch=false`, `npm run build` | le seul `dist/*/browser` |
| `package.json` avec `vite` | `vite` (React, Vue, Svelte…) | `npm run test --if-present`, `npm run build -- --base=./` | `dist` |
| `package.json` avec `react-scripts` | `cra` | `npm run test --if-present`, `npm run build` | `build` |
| `.csproj` `Microsoft.NET.Sdk.BlazorWebAssembly` | `blazor` | `dotnet test` des projets de tests, `dotnet publish` | `wwwroot` |
| `.csproj` `Microsoft.NET.Sdk.WebAssembly` + `Avalonia.Browser` | `avalonia` | idem, avec `wasm-tools` | `wwwroot` |
| `pubspec.yaml` (Flutter) | `flutter` | `flutter test` si `test/`, `flutter build web` | `build/web` |
| `index.html` seul | `static` | aucun | le dossier |

Il faut exactement un projet dans la branche, sinon le préciser dans `.github/builds.json`.

## Configuration (`.github/builds.json`)

```json
{
  "defaults": { "node": "22", "dotnet": "10.0.x" },
  "repositories": {
    "mon-repo": { "project": "src/MonApp.Browser/MonApp.Browser.csproj", "techno": "avalonia" }
  }
}
```

Clés d'un repo (toutes facultatives) : `project` (dossier ou `.csproj`), `techno`, `test` (commande ; `""` : pas de tests), `build` (commande), `output` (dossier publié, relatif au projet), `node`, `dotnet` (sinon `global.json` du repo), `flutter` (version), `aot` (`true` : compilation AOT .NET).

## Secrets

- `PAGES_TOKEN`, dans chaque repo : demande la publication à ce repo-ci.
- `SOURCES_TOKEN`, dans ce repo-ci : jeton fine-grained en lecture (*Contents: Read*) sur les repos privés, pour récupérer leurs branches `build/…`. Inutile pour les repos publics.
