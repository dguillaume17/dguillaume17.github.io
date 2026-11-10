# dguillaume17.github.io

Sites publiés par mes repos, un par repo et par branche : **[liste des sites publiés](https://dguillaume17.github.io/)**.

- Adresse d'un site : `https://dguillaume17.github.io/<repo>/<branche>/` (noms en minuscules, chaque suite d'autres caractères que `a-z0-9` devient `-` : `feature/Form` → `feature-form`).
- Chaque push d'un repo branché publie le site de sa branche ; la suppression d'une branche supprime son site.
- `sites.json` liste les sites publiés ; `index.html` l'affiche.

## Ce que fait la publication, pour toutes les technos

- **Numéro de build** : le numéro d'exécution du workflow du repo appelant (+1 à chaque exécution, toutes branches confondues). Il est écrit dans `build.json` (avec branche, commit et date) et dans `<meta name="build-number">` du site, affiché dans la liste des sites et, sauf `badge: false`, dans un petit badge en bas à droite du site. Une application qui veut l'afficher elle-même lit cette meta ou `build.json`.
- **Cache** : GitHub Pages laisse les navigateurs garder une page jusqu'à 10 minutes (Safari sur iOS parfois plus). Les fichiers locaux référencés par `index.html` reçoivent `?build=<numéro>`, et un script injecté relit `build.json` sans cache : s'il annonce un autre build, la page se recharge une fois avec `?build=<numéro>`, une adresse jamais mise en cache.
- **Sous-dossier** : le `<base href>` de `index.html` devient `/<repo>/<branche>/` ; les autres chemins du site doivent être relatifs. GitHub Pages ne sert que le `404.html` de la racine : les adresses profondes d'une application à routage côté client ne fonctionnent pas (préférer un routage par `#`).

## Brancher un repo

Dans tous les cas : secret `PAGES_TOKEN` dans le repo (*Settings → Secrets and variables → Actions*), un jeton fine-grained limité à `dguillaume17.github.io` avec la permission *Contents: Read and write*.

### Techno qui a son workflow ici (Angular)

Le workflow de la techno builde puis publie (`push`), ou supprime le site (`delete`) ; le repo n'a que `.github/workflows/deploy.yml` :

```yaml
name: Build et publication

on:
  push:
    branches: ['**']
  delete:

permissions:
  contents: read

jobs:
  site:
    uses: dguillaume17/dguillaume17.github.io/.github/workflows/angular.yml@main
    secrets:
      PAGES_TOKEN: ${{ secrets.PAGES_TOKEN }}
```

| Workflow | Pour | Entrées (toutes facultatives) |
|---|---|---|
| `angular.yml` | un projet créé par `ng new` | `working-directory` (`.`), `node-version` (`22`), `test-command` (`npm test -- --watch=false`, vide : pas de tests), `build-command` (`npm run build`), `output-path` (le seul `dist/*/browser`), `badge` (`true`) |

Exemple : [dguillaume17/code-lab](https://github.com/dguillaume17/code-lab).

### Autre techno

Le repo builde lui-même, dépose le dossier statique obtenu (avec son `index.html` à la racine) comme artefact `site`, puis appelle `publish.yml` (entrées : `action` `deploy` ou `remove`, `artifact` `site`, `branch`, `badge` `true`) :

```yaml
jobs:
  build:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # … build propre à la techno, qui produit le dossier dist/ …
      - uses: actions/upload-artifact@v4
        with:
          name: site
          path: dist/

  publish:
    needs: build
    uses: dguillaume17/dguillaume17.github.io/.github/workflows/publish.yml@main
    secrets:
      PAGES_TOKEN: ${{ secrets.PAGES_TOKEN }}

  remove:
    if: github.event_name == 'delete' && github.event.ref_type == 'branch'
    uses: dguillaume17/dguillaume17.github.io/.github/workflows/publish.yml@main
    with:
      action: remove
      branch: ${{ github.event.ref }}
    secrets:
      PAGES_TOKEN: ${{ secrets.PAGES_TOKEN }}
```

Quand un deuxième repo utilise la même techno, en faire un workflow ici sur le modèle de `angular.yml`.
