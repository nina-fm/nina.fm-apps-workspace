# Lessons — workspace

Ce fichier est injecté avant toute action et relu à chaque requête, dans les cinq repos.
Une leçon n'y est donc que si elle vaut pour **n'importe quelle session**. Ce qui ne
joue qu'au moment où une commande tourne vit dans son corps (`plugins/nina/commands/`),
ce qu'un outil peut appliquer vit dans le script qui l'applique, et les leçons du
chantier du plugin `nina` sont dans `plugins/nina/LESSONS.md`.

## Shell (zsh)

- Les tableaux commencent à **1** : `${arr[$((i-1))]}` décale tout d'un cran — une boucle `gh issue create` a ainsi collé chaque titre sur le corps suivant. Itérer sur les éléments (`for t in "${arr[@]}"`), pas sur des indices
- Un mot qui commence par `=` est une expansion (`=cmd` → chemin de `cmd`) : `echo "===== $f"` passe, mais `echo =====` sans guillemets échoue en `==== not found` et interrompt la commande composée. Mettre les séparateurs entre guillemets
- Un remplacement qui lit son texte dans une variable (`perl … $ENV{SEC}`) remplace par du vide quand la variable manque, sans rien signaler : une section de corps de PR a ainsi été effacée puis publiée. `open … or die` en tête, et relire le fichier (`grep` sur la section) avant publication
- Une fonction shell qui porte le nom d'un alias zsh (`g`, `gp`…) échoue en `parse error` : `function nom { … }` avec un nom improbable
- `$var:x` applique le modificateur zsh `:x` : `git show "$B:src/…"` est devenu `…/64-apiproperty-hors-interfacesoller.ts` (`:s` substitue). Accolades avant un deux-points : `"${B}:src/…"`
- zsh ne découpe **pas** une variable non quotée en mots : `set -- $spec` a mis `"repo 50"` entier dans `$1`, et six `gh api` ont répondu 404. Découper par expansion (`"${spec%%:*}"` / `"${spec##*:}"`) ou forcer avec `${=spec}`
- Exclure un fichier par `grep -v NOM` exclut tout nom qui **contient** le motif : `ls .changeset/*.md | grep -v README` écartait aussi un changeset `README-des-transitions.md`, dont le bump était perdu sans rien signaler. Filtrer sur le nom exact (`find … ! -name 'README.md'`)
- Sous `set -e`, `VAR=$(cmd)` arrête le script quand `cmd` échoue : une substitution qui a le droit de ne rien trouver se termine par `|| true`

## GitHub Actions

- Les appelants qui vérifient les `workflow_call` du workspace sont **committés** dans `.github/workflow-tests/` (un valide, un fautif), et `validate-workflows.yml` les rejoue sur chaque PR : on les met à jour quand le contrat change, on n'en crée plus à la main. `actionlint` y valide inputs requis, inputs inconnus, **secrets** requis et inconnus (rien sous `secrets: inherit`), et outputs consommés ; il ne voit ni les types (`no-cache: oui` passe), ni la casse des noms d'inputs, ni les `permissions` de l'appelant
- Exiger un code de sortie non nul ne prouve pas qu'une vérification mord : un témoin fautif renommé, vidé ou au YAML cassé en produit un aussi, et le contrôle passe en annonçant « 0 erreur ». Vérifier le **compte** attendu et la présence de **chaque** message
- Une `description:` d'input est évaluée comme n'importe quel champ : y documenter l'expression attendue de l'appelant en `${{ … }}` la fait rejeter (`context "inputs" is not allowed here`). L'écrire nue, sans les accolades
- `inputs.<x>` d'un input `type: boolean` est un **booléen** : `inputs.x == 'true'` est toujours faux, et quatre `deploy.yml` avaient ainsi un `no-cache` inopérant. Seul `github.event.inputs.<x>` est une chaîne
- Un `workflow_dispatch` lance tous les jobs dont le `if` ne regarde que la ref : dans auth#13, le dispatch « rollback » déployait aussi, et le dump pré-déploiement pris en parallèle devenait celui que le rollback restaurait. Un job propre à une valeur d'input, les autres l'excluent
- Un `actionlint` local vert n'annonce pas un CI vert, même à version égale : il délègue à **shellcheck**, qui n'est pas épinglé, et SC2002 (`useless cat`) est passé en option (`--list-optional` le nomme `useless-use-of-cat`) dans shellcheck 0.11.0 alors qu'il est actif sur l'image du runner. Un défaut de `node-validate.yml` est ainsi resté invisible en local
- Un ruleset ne peut pas donner de bypass à l'app GitHub Actions : `bypass_actors: [{actor_type: Integration, actor_id: 15368}]` est refusé en `422 … must be part of the ruleset source or owner organization`, l'app n'étant pas une installation de l'org. Un push fait avec `GITHUB_TOKEN` ne peut donc **pas** franchir un check requis : rendre un check obligatoire sur `main` casse tout `release.yml` qui y pousse son commit de version (website#65)
- `gh api repos/<repo>/actions/organization-secrets` liste les secrets d'org comme disponibles même là où ils ne sont **pas** transmis : nina-fm est en plan Free, où un repo privé n'y a pas accès. Une self-review s'y est fiée et a fait passer à tort à 7 le compte des secrets reçus dans mixtaper#73. Les secrets vivent donc dans chaque repo ; ceux de l'org, inutilisés, ont été supprimés le 2026-10-08
- `runs-on: ubuntu-latest` fait subir les bascules d'image : pinner (`ubuntu-24.04`) et monter volontairement
- Toucher un `deploy.yml` déploie pour de bon, `docker compose pull` compris : le simple pin des runners d'auth (auth#9) a fait tirer `supertokens-postgresql:latest` 12.2.0, qui a refusé de démarrer faute de migration manuelle — 10 min de 502 sur l'auth de toutes les apps. Avant de merger un changement de CI, vérifier que les images du compose de prod sont épinglées

## rtk

Toute commande passe par le hook rtk, qui **filtre la sortie** — y compris quand elle est
redirigée. Un `cat eslint.config.mjs` amputé de son bloc `ignores` et de ses `files` a
fait croire à un `max-lines` coupé partout ; un `grep -v motif fichier > corps.md` a reçu
le résumé de rtk au lieu des lignes, et publié un corps de PR tronqué, attribution en
double. Lire un fichier avec l'outil Read ; pour transformer un fichier ou obtenir une
sortie brute, `rtk proxy <cmd>`, et contrôler (`wc -l`) avant publication.

`curl`, `diff`, `ps`, `pnpm` et `cat` ne sont plus réécrits (`exclude_commands` de
`~/Library/Application Support/rtk/config.toml`, qui ne compare que le premier mot) :
un `curl` rendait un schéma au lieu du JSON, `ps` masquait des processus en cours, et
`pnpm lint` devenait `rtk lint`, qui perd les chemins du script et lint `dist/`. Les
autres commandes (`grep`, `git`, `gh`, `npx`…) restent filtrées ; `rtk rewrite "<cmd>"`
dit ce que le hook en fera.

## Chercher dans les fronts

Le code ne vit pas au même endroit partout : faceb (Nuxt) est dans `app/`, mixtaper dans `src/`. Un `grep … src` sur tous les repos a conclu que faceb n'utilisait pas les types `*OrmEntity`, alors que 21 de ses fichiers les importent. Chercher depuis la racine du repo (`git ls-files | xargs grep`).

## gh

`gh api … -f champ=123` envoie une **chaîne** : `POST …/sub_issues -f sub_issue_id=…` est
refusé en `not of type integer`. `-F` type la valeur.

Un corps de commentaire, d'issue ou de PR se passe par `--body-file`, écrit par heredoc
`<<'EOF'` : en argument, zsh exécute les backticks et casse sur les apostrophes — un
`'…'` rebouché à la main a fait poster des corps vides.

Un `Closes #N` dans un **message de commit** ferme l'issue au squash, quoi que dise le corps
de la PR : #55, dont une moitié vivait dans un autre repo, a été fermée par le merge de #58
alors que le corps n'en portait qu'un `Refs`. Retirer le mot-clé des deux endroits, et
fermer à la main ce qu'une PR ne solde pas — une référence cross-repo ne ferme jamais.

Une collection se lit avec `--paginate`, sans quoi on n'en voit que les 30 premiers.
`gh api … --paginate --jq` filtre page par page et rend plusieurs JSON à la suite ;
`--slurp` rend le tableau des pages, mais **refuse `--jq`** (« the `--slurp` option is
not supported with `--jq` ») : filtrer en aval, `… --paginate --slurp | jq '.[][]'`.

## Mutualiser

- Un modèle à recopier ne porte que le **commun** : « sur le modèle du workspace » a fait recopier `env.NINA_PROJECT=2` dans nina.fm-api (api#58), dont le `settings.json` mêle activation commune et valeur propre au repo. Ce qui est propre à chaque repo se décrit à part, avec ses valeurs
- Une case de checklist rangée sous un glob plus étroit que sa portée est sautée en silence : dans mixtaper#65, « `src/api/` n'est pas modifié à la main » était sous `src/features/**/*.api.ts`. Écrire d'abord ce que la case vise, le glob ensuite ; ce qui vise tout le repo va dans une section sans glob
