# Leçons du chantier du plugin nina

Ce qu'on a appris en construisant et en recettant le plugin (epic #6). Ces leçons ne
servent qu'à qui retouche le plugin : elles sont ici plutôt que dans
`.claude/rules/lessons.md`, qui est relu à chaque requête de chaque session des cinq
repos. À lire avant de toucher aux hooks, aux commandes ou à `bin/`.

## Sessions `claude -p` et recette d'un hook

- `claude -p ... --add-dir <dir> "prompt"` : l'option est variadique et avale le prompt
  (« Input must be provided »). Passer le prompt sur stdin : `echo … | claude -p …`.
- Les transcripts `-p` ne consignent un hook que s'il **échoue**
  (`hook_non_blocking_error`, `exitCode`) : son absence vaut sortie en 0.
- Un `grep -c hook_non_blocking_error` sur un transcript compte aussi les `CLAUDE.md` et
  `lessons.md` injectés en attachment `instructions` : api#58 a relevé 1 « erreur » par
  session, qui n'était que le texte de cette leçon. Filtrer avec `jq` sur
  `.type == "attachment"` et `.attachment.type` contenant `hook`.
- Une session `claude -p` n'a **ni l'outil Glob ni l'outil Grep** (ToolSearch ne les
  trouve pas non plus) : le modèle se rabat sur Bash, que la garde ne voit pas
  (workspace#18). Le volet Glob d'une garde ne se recette donc pas par prompt. Appeler
  directement le script installé,
  `~/.claude/plugins/cache/nina-fm/nina/<version>/hooks/guard-env.sh`, avec le JSON
  `{"tool_name":"Glob",…}` sur stdin, et relever sortie et code.
- Une session exporte le `env` de son `settings.json` à **toutes** ses commandes,
  `claude -p` imbriqués compris : lancé depuis le workspace, un `claude -p` dans
  nina.fm-api a `NINA_PROJECT=2` et affiche le plan du Project 2. Pour la recette d'un
  sous-repo, `env -u NINA_PROJECT` ou la valeur du repo devant `claude -p`.
- Déclarer un plugin (`extraKnownMarketplaces` + `enabledPlugins`) ne l'**installe** pas :
  après le merge de #19, la garde `.env` était inactive dans le workspace. La recette
  d'un plugin se rejoue après merge, sans `--plugin-dir`, sur un faux `.env` ;
  `claude plugin list` montre ce qui est réellement installé.

## Mode auto et self-modification

- `claude plugin install` est refusé par le classifieur du mode auto
  (`Self-Modification`), y compris noyé dans une commande composée : tout le bloc est
  rejeté, commit compris. Commiter à part, puis faire lancer l'install par Vincent avec
  `! claude plugin install …`. Entre le retrait d'une garde copiée et cette install, le
  repo n'a aucune garde : l'install passe avant toute autre action.
- Le classifieur refuse aussi l'écriture de `.claude/settings.json`
  (`Self-Modification`), parfois sans soumettre l'action à Vincent. Ne pas contourner
  par `sed` : relancer le même Edit/Write une fois que Vincent a dit qu'il validerait,
  et l'invite de validation apparaît.

## Projects et recette de mesure

- Qu'une issue d'un repo soit rangée dans un Project ne donne pas un Project **au repo** :
  les issues d'api#58 sont dans « Apps Workspace », mais nina.fm-api n'a pas de Project
  dédié, donc pas de `NINA_PROJECT`. Seuls les repos qui ont leur propre Project
  (`gh project list --owner nina-fm`, titre du repo) le posent.
- Une recette sur une PR ancienne mesure moins que prévu si elle touche des chemins
  **supprimés depuis** : `git check-attr` lit le `.gitattributes` de l'arbre de travail,
  pas celui des commits relus. mixtaper#16 supprimait `src/types/api/`, que plus rien ne
  déclare — d'où −63 % au lieu des −89 % attendus. Choisir pour la recette une PR sur la
  disposition du jour, ou rejouer la régénération sur `main`.
