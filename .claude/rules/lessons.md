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
- `claude plugin install` est refusé par le classifieur du mode auto (`Self-Modification`), y compris noyé dans une commande composée : tout le bloc est rejeté, commit compris. Commiter à part, puis faire lancer l'install par Vincent avec `! claude plugin install …`. Entre le retrait d'une garde copiée et cette install, le repo n'a aucune garde : l'install passe avant toute autre action
- Une session `claude -p` n'a ni l'outil Glob ni l'outil Grep (ToolSearch ne les trouve pas non plus) : le modèle se rabat sur Bash, que la garde ne voit pas (workspace#18). Le volet Glob d'une garde ne se recette donc pas par prompt. Appeler directement le script installé, `~/.claude/plugins/cache/nina-fm/nina/<version>/hooks/guard-env.sh`, avec le JSON `{"tool_name":"Glob",…}` sur stdin, et relever sortie et code
- « Sur le modèle du workspace » a fait recopier `env.NINA_PROJECT=2` dans nina.fm-api (api#58) : le `settings.json` du workspace mêle activation commune et valeurs propres au repo. Un modèle à recopier ne porte que le commun ; le propre à chaque repo se décrit à part, avec les valeurs par repo
- Qu'une issue d'un repo soit rangée dans un Project ne donne pas un Project au repo : les issues d'api#58 sont dans « Apps Workspace », mais nina.fm-api n'a pas de Project dédié, donc pas de `NINA_PROJECT`. Seuls les repos qui ont leur propre Project (`gh project list --owner nina-fm`, titre du repo) le posent
- Un `grep -c hook_non_blocking_error` sur un transcript compte aussi les CLAUDE.md et lessons injectés en attachment `instructions` : api#58 a relevé 1 « erreur » par session, qui n'était que le texte de cette leçon. Filtrer avec jq sur `.type=="attachment"` et `.attachment.type` contenant `hook`
- Le classifieur du mode auto refuse aussi l'écriture de `.claude/settings.json` (`Self-Modification`), parfois sans soumettre l'action à Vincent. Ne pas contourner par `sed` : relancer le même Edit/Write une fois que Vincent a dit qu'il validerait, et l'invite de validation apparaît
