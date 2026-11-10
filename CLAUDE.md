# dguillaume17.github.io

Site GitHub Pages personnel (servi depuis `main`, à la racine) qui héberge les sites de mes autres repos, et les workflows réutilisables qui les buildent et les publient. Le README explique ce que fait la publication et comment brancher un repo.

## Contenu

```
.github/workflows/publish.yml      workflow réutilisable commun (workflow_call) : deploy ou remove du site d'une branche du repo appelant
.github/workflows/<techno>.yml     workflow réutilisable par techno (angular.yml) : build puis publish.yml, ou remove, selon l'événement de l'appelant
.github/scripts/publish.sh         la publication elle-même (appelée par publish.yml) : dossier, index.html, build.json, sites.json, nettoyage, push
.github/scripts/build-check.html   injecté à la fin du <head> de chaque site : meta build-number, rechargement d'une page en cache, badge
index.html                         liste des sites, lue dans sites.json
sites.json                         un objet par site : path, repository, source, branch, url, commit, build, updatedAt
.nojekyll                          sans lui, GitHub ignore les dossiers commençant par _ (le _framework de Blazor)
<repo>/<branche>/                  sites publiés : écrits uniquement par publish.sh, jamais à la main
```

## Règles

- **Deux étages** : publish.yml ne contient rien de propre à une techno (il reçoit un dossier statique avec `index.html` en artefact) ; tout ce qui est propre à une techno va dans son `<techno>.yml`, qui a des valeurs par défaut pour un projet standard et des entrées pour le reste, et dont l'appelant ne fait que transmettre ses événements (push, delete) et son secret.
- Ce qui change un contrat (entrées d'un workflow, structure du site, champs de sites.json ou build.json) se reporte dans le README et dans les repos appelants.
- Les appelants utilisent `@main`, et les workflows de techno appellent `publish.yml@main` : un push sur `main` les change tous à leur prochaine exécution. Tester publish.sh localement avant (dépôt nu comme `origin`, deux clones pour un push concurrent ; un site servi en local pour build-check.html).
- Un déploiement ne touche que le dossier de son repo : `<repo>/<branche>/`, plus le nettoyage des branches disparues de ce même repo.
- Les commits de publication arrivent sur `main` en continu : `git pull` avant de modifier quoi que ce soit.
- Interface, messages et documentation en français ; code et commentaires en anglais.
