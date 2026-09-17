---
description: Leçons apprises — workspace Nina.fm (chargé automatiquement dans tous les repos)
---

# Lessons — workspace

_Les règles consolidées ont été déplacées dans `CLAUDE.md` du workspace._

- Le shell est zsh : les tableaux commencent à 1. `${arr[$((i-1))]}` décale tout d'un cran — une boucle `gh issue create` a ainsi collé chaque titre sur le corps suivant. Itérer sur les éléments (`for t in "${arr[@]}"`), pas sur des indices
- `cat` passe par le hook rtk, qui filtre la sortie : `eslint.config.mjs` affiché sans ses commentaires, son bloc `ignores` ni ses `files` a fait croire à un `max-lines` coupé partout. Lire un fichier de config avec Read ; `rtk proxy <cmd>` pour une sortie brute
- Une fonction shell qui porte le nom d'un alias zsh (`g`, `gp`…) échoue en `parse error` : `function nom { … }` avec un nom improbable
- `claude -p ... --add-dir <dir> "prompt"` : l'option est variadique et avale le prompt (« Input must be provided »). Passer le prompt sur stdin (`echo … | claude -p …`). Les transcripts `-p` ne consignent un hook que s'il échoue (`hook_non_blocking_error`, `exitCode`) : son absence vaut sortie en 0
- Déclarer un plugin (`extraKnownMarketplaces` + `enabledPlugins`) ne l'installe pas : après le merge de #19, la garde `.env` était inactive dans le workspace. La recette d'un plugin se rejoue après merge, sans `--plugin-dir`, sur un faux `.env` ; `claude plugin list` montre ce qui est réellement installé
- Corps de commentaire `gh` avec apostrophes ou backticks : un `'…'` rebouché à la main a fait exécuter des morceaux du texte par zsh et poster des corps vides. Écrire le corps dans un fichier par heredoc `<<'EOF'` et passer `--body-file`
- Un mot qui commence par `=` est une expansion zsh (`=cmd` → chemin de `cmd`) : `echo "===== $f"` passe, mais `echo =====` sans guillemets échoue en `==== not found` et interrompt la commande composée. Mettre les séparateurs entre guillemets
- Une session exporte le `env` de son `settings.json` à toutes ses commandes, `claude -p` imbriqués compris : lancé depuis le workspace, un `claude -p` dans nina.fm-api a `NINA_PROJECT=2` et affiche le plan du Project 2. Pour la recette d'un sous-repo, `env -u NINA_PROJECT` ou la valeur du repo devant `claude -p`
