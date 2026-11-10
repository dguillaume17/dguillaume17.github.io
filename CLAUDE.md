# dguillaume17.github.io

Site GitHub Pages personnel (servi depuis `main`, à la racine) qui héberge les sites de mes autres repos, et le workflow réutilisable qui les publie. Le README explique comment brancher un repo.

## Contenu

```
.github/workflows/publish.yml   workflow réutilisable (workflow_call) : deploy ou remove du site d'une branche du repo appelant
.github/scripts/publish.sh      la publication elle-même (appelée par publish.yml) : dossier, <base href>, sites.json, nettoyage, push
index.html                      liste des sites, lue dans sites.json
sites.json                      un objet par site : path, repository, source, branch, url, commit, updatedAt
.nojekyll                       sans lui, GitHub ignore les dossiers commençant par _ (le _framework de Blazor)
<repo>/<branche>/               sites publiés : écrits uniquement par publish.sh, jamais à la main
```

## Règles

- **Contrat** : le repo appelant builde avec ses outils et dépose un dossier statique (avec `index.html`) en artefact ; publish.yml ne contient rien de propre à une techno. Ce qui change le contrat (entrées de publish.yml, structure du site, champs de sites.json) se reporte dans le README et dans les repos appelants.
- Les appelants utilisent `publish.yml@main` : un push sur `main` les change tous à leur prochaine exécution. Tester publish.sh localement avant (dépôt nu comme `origin`, deux clones pour un push concurrent).
- Un déploiement ne touche que le dossier de son repo : `<repo>/<branche>/`, plus le nettoyage des branches disparues de ce même repo.
- Les commits de publication arrivent sur `main` en continu : `git pull` avant de modifier quoi que ce soit.
- Interface, messages et documentation en français ; code et commentaires en anglais.
