# dguillaume17.github.io

Sites publiés par mes repos, un par repo et par branche : **[liste des sites publiés](https://dguillaume17.github.io/)**.

- Adresse d'un site : `https://dguillaume17.github.io/<repo>/<branche>/` (noms en minuscules, chaque suite d'autres caractères que `a-z0-9` devient `-` : `feature/Form` → `feature-form`).
- Chaque push d'un repo branché publie le site de sa branche ; la suppression d'une branche supprime son site.
- `sites.json` liste les sites publiés ; `index.html` l'affiche.

## Brancher un repo

Le repo builde son site avec ses propres outils, dépose le dossier statique obtenu (avec son `index.html` à la racine) comme artefact `site`, puis appelle le workflow commun `.github/workflows/publish.yml`, qui fait tout le reste.

1. Secret `PAGES_TOKEN` dans le repo (*Settings → Secrets and variables → Actions*) : un jeton fine-grained limité à `dguillaume17.github.io`, permission *Contents: Read and write*.
2. Workflow `.github/workflows/deploy.yml` dans le repo :

```yaml
name: Build et publication

on:
  push:
    branches: ['**']
  delete:

permissions:
  contents: read

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

Le site doit fonctionner sous un sous-dossier : le workflow remplace le `<base href>` de son `index.html` par `/<repo>/<branche>/` ; les autres chemins doivent être relatifs. GitHub Pages ne sert que le `404.html` de la racine : les adresses profondes d'une application à routage côté client ne fonctionnent pas (préférer un routage par `#`).

Exemple : [dguillaume17/code-lab](https://github.com/dguillaume17/code-lab) (Angular).
