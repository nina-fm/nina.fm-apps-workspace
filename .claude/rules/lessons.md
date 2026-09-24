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

- Un `workflow_call` se vérifie avant d'être appelé pour de bon : `actionlint` sur un appelant jetable qui le référence en chemin local (`uses: ./.github/workflows/x.yml`) valide inputs requis, inputs inconnus et outputs consommés. Le prouver en passant aussi un appelant fautif — sinon le « OK » ne dit rien. Il ne voit pas les types (`no-cache: oui` passe)
- Une `description:` d'input est évaluée comme n'importe quel champ : y documenter l'expression attendue de l'appelant en `${{ … }}` la fait rejeter (`context "inputs" is not allowed here`). L'écrire nue, sans les accolades
- `inputs.<x>` d'un input `type: boolean` est un **booléen** : `inputs.x == 'true'` est toujours faux, et quatre `deploy.yml` avaient ainsi un `no-cache` inopérant. Seul `github.event.inputs.<x>` est une chaîne
- `runs-on: ubuntu-latest` fait subir les bascules d'image : pinner (`ubuntu-24.04`) et monter volontairement

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

Une collection se lit avec `--paginate`, sans quoi on n'en voit que les 30 premiers.
`gh api … --paginate --jq` filtre page par page et rend plusieurs JSON à la suite ;
`--slurp` rend le tableau des pages, mais **refuse `--jq`** (« the `--slurp` option is
not supported with `--jq` ») : filtrer en aval, `… --paginate --slurp | jq '.[][]'`.

## Mutualiser

- Un modèle à recopier ne porte que le **commun** : « sur le modèle du workspace » a fait recopier `env.NINA_PROJECT=2` dans nina.fm-api (api#58), dont le `settings.json` mêle activation commune et valeur propre au repo. Ce qui est propre à chaque repo se décrit à part, avec ses valeurs
- Une case de checklist rangée sous un glob plus étroit que sa portée est sautée en silence : dans mixtaper#65, « `src/api/` n'est pas modifié à la main » était sous `src/features/**/*.api.ts`. Écrire d'abord ce que la case vise, le glob ensuite ; ce qui vise tout le repo va dans une section sans glob
