# dguillaume17.github.io

Site GitHub Pages personnel (servi depuis `main`, à la racine) qui héberge les sites de mes autres repos, et les workflows réutilisables qui les buildent et les publient. Le README, minimal, explique comment brancher un repo ; le reste (options, contrat, usage direct de publish.yml) est en tête de chaque workflow et de publish.sh.

## Contenu

```
.github/workflows/publish.yml      workflow réutilisable commun (workflow_call) : deploy ou remove du site d'une branche du repo appelant
.github/workflows/<techno>.yml     workflow réutilisable par techno (angular, blazor, react, flutter) : build puis publish.yml, ou remove, selon l'événement de l'appelant
.github/scripts/publish.sh         la publication elle-même (appelée par publish.yml) : dossier, index.html, build.json, sites.json, nettoyage, push
.github/scripts/build-check.html   injecté à la fin du <head> de chaque site : meta build-number, rechargement d'une page en cache, badge
index.html                         liste des sites, lue dans sites.json
sites.json                         un objet par site : path, repository, source, branch, url, commit, build, updatedAt
.nojekyll                          sans lui, GitHub ignore les dossiers commençant par _ (le _framework de Blazor)
<repo>/<branche>/                  sites publiés : écrits uniquement par publish.sh, jamais à la main
```

## Brancher un nouveau repo

Pour une session Claude qui a le nouveau repo (et celui-ci, pour lire les workflows) :

1. **Techno** : trouver son workflow dans `.github/workflows/` (tableau du README). Sans workflow pour cette techno : en créer un sur le modèle de `angular.yml` (mêmes jobs build / publish / remove, entrées avec valeurs par défaut d'un projet standard), le tester, l'ajouter au tableau du README.
2. **Lire l'en-tête du workflow** et vérifier le repo contre ses valeurs par défaut : dossier du projet, commandes de tests et de build, dossier produit. Lancer ces commandes dans la session : elles doivent passer et produire un `index.html`.
3. **Le site doit marcher dans un sous-dossier** (`/<repo>/<branche>/`) : chemins relatifs (le `<base href>` est réécrit), pas de chemin absolu `/…` dans le code, pas de routage par chemin (GitHub Pages ne sert que le 404.html de la racine : routage par `#`). Le corriger dans le repo si besoin, en le disant.
4. **Écrire `.github/workflows/deploy.yml`** dans le nouveau repo : le modèle du README, avec le workflow de la techno et, sous `with:`, seulement les entrées qui s'écartent des valeurs par défaut. Rien d'autre : pas de logique de build ni de publication dans le repo.
5. **Secret `PAGES_TOKEN`** : Claude ne peut pas le créer. Demander à l'utilisateur de l'ajouter au nouveau repo (*Settings → Secrets and variables → Actions*), avec le jeton déjà utilisé (fine-grained, limité à `dguillaume17.github.io`, *Contents: Read and write*) ; sans lui, le job publish échoue au clone de dguillaume17.github.io.
6. **Pousser, puis suivre l'exécution** (outils GitHub Actions) : jobs build et publish réussis, commit « Publie <repo>/<branche>, build n° N » sur `main` ici, `<repo>/<branche>/build.json` et l'entrée de `sites.json`. Le réseau des sessions bloque souvent `github.io` : demander à l'utilisateur d'ouvrir `https://dguillaume17.github.io/<repo>/<branche>/` (badge du numéro de build en bas à droite ; jusqu'à 10 minutes de cache au premier déploiement).

## Règles

- **Deux étages** : publish.yml ne contient rien de propre à une techno (il reçoit un dossier statique avec `index.html` en artefact) ; tout ce qui est propre à une techno va dans son `<techno>.yml`, qui a des valeurs par défaut pour un projet standard et des entrées pour le reste, et dont l'appelant ne fait que transmettre ses événements (push, delete) et son secret.
- Ce qui change un contrat (entrées d'un workflow, structure du site, champs de sites.json ou build.json) se reporte dans les commentaires de tête, dans le README s'il en parle, et dans les repos appelants.
- Les appelants utilisent `@main`, et les workflows de techno appellent `publish.yml@main` : un push sur `main` les change tous à leur prochaine exécution. Tester publish.sh localement avant (dépôt nu comme `origin`, deux clones pour un push concurrent ; un site servi en local pour build-check.html).
- Un déploiement ne touche que le dossier de son repo : `<repo>/<branche>/`, plus le nettoyage des branches disparues de ce même repo.
- Les commits de publication arrivent sur `main` en continu : `git pull` avant de modifier quoi que ce soit.
- Interface, messages et documentation en français ; code et commentaires en anglais.
