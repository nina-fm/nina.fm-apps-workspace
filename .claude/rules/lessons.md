# Lessons — workspace

Ce fichier est injecté avant toute action et relu à chaque requête, dans les cinq repos.
Une leçon n'y est donc que si elle vaut pour **n'importe quelle session**. Ce qui ne
joue qu'au moment où une commande tourne vit dans son corps (`plugins/nina/commands/`),
ce qu'un outil peut appliquer vit dans le script qui l'applique, et les leçons du
chantier du plugin `nina` sont dans `plugins/nina/LESSONS.md`.

## Shell (zsh)

- Les tableaux commencent à **1** : `${arr[$((i-1))]}` décale tout d'un cran — une boucle `gh issue create` a ainsi collé chaque titre sur le corps suivant. Itérer sur les éléments (`for t in "${arr[@]}"`), pas sur des indices
- Un mot qui commence par `=` est une expansion (`=cmd` → chemin de `cmd`) : `echo "===== $f"` passe, mais `echo =====` sans guillemets échoue en `==== not found` et interrompt la commande composée. Mettre les séparateurs entre guillemets
- Une fonction shell qui porte le nom d'un alias zsh (`g`, `gp`…) échoue en `parse error` : `function nom { … }` avec un nom improbable

## rtk

Toute commande passe par le hook rtk, qui **filtre la sortie** — y compris quand elle est
redirigée. Un `cat eslint.config.mjs` amputé de son bloc `ignores` et de ses `files` a
fait croire à un `max-lines` coupé partout ; un `grep -v motif fichier > corps.md` a reçu
le résumé de rtk au lieu des lignes, et publié un corps de PR tronqué, attribution en
double. Lire un fichier avec l'outil Read ; pour transformer un fichier ou obtenir une
sortie brute, `rtk proxy <cmd>`, et contrôler (`wc -l`) avant publication.

## gh

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
