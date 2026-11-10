# dguillaume17.github.io

Héberge les sites de mes repos : **[liste des sites publiés](https://dguillaume17.github.io/)**.

Chaque push d'un repo publie le site de sa branche sur `https://dguillaume17.github.io/<repo>/<branche>/`, avec son numéro de build en bas à droite ; supprimer la branche supprime son site.

## Brancher un repo

1. Ajouter le secret `PAGES_TOKEN` au repo (*Settings → Secrets and variables → Actions*) : un jeton fine-grained limité à `dguillaume17.github.io`, permission *Contents: Read and write*.
2. Ajouter `.github/workflows/deploy.yml`, avec le workflow de sa techno :

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

| Techno | Workflow |
|---|---|
| Angular | `angular.yml` |
| Blazor WebAssembly | `blazor.yml` |
| React (Vite) | `react.yml` |
| Flutter web | `flutter.yml` |

Les options de chaque workflow (`with:`) sont décrites en tête de son fichier, dans `.github/workflows/`.
