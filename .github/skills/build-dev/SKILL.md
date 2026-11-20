---
name: build-dev
description: "Builde et publie la branche courante (seulement les branches dev/…) avec le workflow Build du repo, attend la fin, puis donne l'adresse du site ou la cause de l'échec. À utiliser pour « /build-dev », « builde », « publie cette branche »."
---

# /build-dev

1. Branche = `git branch --show-current`. Si elle ne commence pas par `dev/` : répondre « /build-dev ne fonctionne que sur les branches dev/… » et s'arrêter.
2. Repo = `<owner>/<repo>` tiré de `git remote get-url origin`.
3. Outils à jour ? Comparer ce fichier (`.claude/skills/build-dev/SKILL.md`) à `.github/skills/build-dev/SKILL.md` du repo commun (`git clone -q --depth 1 https://github.com/dguillaume17/dguillaume17.github.io /tmp/commun` s'il n'est pas déjà là). S'ils diffèrent, ajouter à la réponse finale : « Une version plus récente des outils existe : /update-lab ». Ne pas bloquer le build pour autant.
4. Commits non poussés (`git status -sb`) : les pousser. Fichiers modifiés non committés : demander s'il faut les committer d'abord.
5. Lancer le build — outil GitHub `actions_run_trigger` : `method: run_workflow`, `owner`, `repo`, `workflow_id: build.yml`, `ref: main` (branche par défaut du repo), `inputs: {"branche": "<branche>"}`. Sans outils GitHub : `gh workflow run build.yml --ref main -f branche=<branche>`.
6. Retrouver l'exécution : `actions_list` `list_workflow_runs` sur `build.yml`, la plus récente intitulée « Build <branche> ». Attendre la fin (vérifier toutes les 30 s environ ; 1 à 3 minutes).
7. Si elle a réussi : dans `dguillaume17/dguillaume17.github.io` (workflow `publish.yml`), suivre de même l'exécution la plus récente intitulée « Publication <owner>/<repo> <branche> », jusqu'à la fin.
8. Répondre en une ou deux lignes :
   - succès : « Build n° <run_number> de `<branche>` publié : https://dguillaume17.github.io/<repo en slug>/<branche en slug>/ » (slug : minuscules, tout ce qui n'est pas a-z0-9 devient `-`, ex. `dev/Signals` → `dev-signals`) ; le site est en ligne une minute environ après ;
   - échec : l'étape en échec, les lignes utiles du log (`get_job_logs`, `failed_only: true`), le lien de l'exécution, et une piste de correction.
