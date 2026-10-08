---
description: Mesurer ce que le harnais coûte (instructions, agents, commandes, sorties d'outils), trier et le ramener sous son budget
argument-hint: "[fichier ou section à revoir en priorité]"
---

Réduire ce que le harnais coûte sans perdre en pertinence : chaque leçon, agent ou étape de commande reste, change de place, se condense, ou sort pour une raison qu'on peut vérifier. On ne retire que ce qui est prouvé inutilisé ou redondant ; une lecture lourde se déplace dans un sous-agent, elle ne se supprime pas.

## Consignes

$ARGUMENTS

Tout ce qui se lit est en français. Le périmètre est le repo de la session (`git rev-parse --show-toplevel`) : son `CLAUDE.md`, ses `.claude/rules/`, et sa mémoire automatique (`~/.claude/projects/<repo>/memory/`). Le workspace (plugin compris) se revoit depuis le workspace ; le reste de `~/.claude/` (`CLAUDE.md`, `RTK.md`, `rules/`) se propose à Vincent sans être appliqué d'office.

---

### Étape 1 — Mesurer

```bash
harnais.sh "$(git rev-parse --show-toplevel)"
```

Depuis le workspace, le lancer aussi sur chacun des cinq repos (`nina.fm-*`) : ce que le workspace charge se paye dans les cinq.

Chaque ligne donne les caractères d'un fichier chargé, puis le total, estimé en tokens, contre le budget d'instructions (`HARNAIS_BUDGET`, 18 000 caractères par défaut, tous niveaux confondus). Ne sont pas comptées la sortie des hooks SessionStart (`plan.sh`, de 500 à 1 600 caractères) ni les descriptions des commandes, skills et agents. Les règles à `paths:` sont listées à part : elles ne coûtent qu'à la lecture d'un fichier qui correspond. Garder la sortie : c'est le « avant » de la PR.

Puis la consommation réelle, lue dans les transcripts :

```bash
harnais-conso.sh 14 "$(git rev-parse --show-toplevel)"
```

Elle donne le contexte de départ et le maximum atteint par session, les tokens relus, écrits et générés (session principale et sous-agents, par modèle), les sorties d'outils par outil et par commande Bash, les commandes lancées, les agents appelés, et **les agents définis jamais appelés**. La relecture du contexte à chaque requête fait l'essentiel du coût : ce qui grossit le contexte de départ ou le fait croître pendant la session est la cible, à proportion de sa fréquence.

---

### Étape 2 — Classer

Lire chaque fichier du périmètre avec l'outil Read (rtk filtre `cat`), et donner une destination à chaque leçon, chaque section d'un `CLAUDE.md`, chaque agent (`.claude/agents/`, `plugins/nina/agents/`) et chaque étape de commande qui lit beaucoup :

| Destination | Quand | Ce qu'il faut prouver |
|---|---|---|
| **Garder** | Peut servir à n'importe quel moment, et aucun outil ne l'applique | — |
| **Condenser** | L'énoncé est noyé dans l'histoire (dates, chiffres de l'incident) | L'issue citée porte l'histoire : la règle garde son énoncé et `(repo#N)` |
| **Scoper** | Ne sert qu'en touchant certains fichiers | Le glob matche les fichiers visés (`git ls-files \| grep`) ; voir les limites ci-dessous |
| **Déplacer** | Ne sert que pendant une commande, en retouchant le plugin, ou au-dessus d'un code précis | La destination : `plugins/nina/commands/<cmd>.md`, `plugins/nina/LESSONS.md`, commentaire dans le script |
| **Agent → règle** | Agent jamais appelé qui porte du savoir de code (patterns, conventions d'un dossier) : ce savoir ne se charge jamais | Une règle `paths:` sur les fichiers qu'il vise, où ce savoir arrive au bon moment ; sa description quitte le contexte |
| **Agent → commande** | Agent utile mais que rien n'appelle | La commande qui l'appelle, à l'étape où il sert, avec un brief autonome (il ne voit pas la conversation) |
| **Déléguer** | Une étape de commande lit beaucoup (diff, exploration) et seule sa conclusion sert | `context: fork` pour la commande entière (comme `/nina:review`), ou un agent `Explore` à cette étape (comme `/nina:task`) ; préciser `model:` à chaque délégation — `opus` là où la qualité de lecture fait la valeur, `sonnet` pour une exploration : sans lui, un sous-agent prend `CLAUDE_CODE_SUBAGENT_MODEL` s'il est posé (réglage personnel), sinon le modèle de la session |
| **Supprimer** | Un outil l'applique, elle est obsolète, ou elle double une autre source (relire un `CLAUDE.md` déjà chargé, par exemple) | Pour un outil : la règle de lint, le test ou la CI qui échoue sans elle, constaté. Pour l'obsolète : ce qui l'a rendue caduque. Pour un doublon : où vit l'original |

Limites d'une règle à `paths:` :

- elle se charge quand Read, Write ou Edit touche un fichier qui correspond, pas sur `gh`, `cat` ni sur un fichier lu par Bash. Une leçon se scope si elle sert **en lisant ou en écrivant** ces fichiers ; celle qui sert au merge, en review (`review-diff.sh` passe par Bash), sur une réponse d'API ou des logs CI reste chargée sans condition, ou passe dans la commande où elle sert ;
- un glob d'une règle du workspace matche aussi depuis un sous-repo (`.github/**` se déclenche sur `nina.fm-website/.github/workflows/ci.yml`, #79) ;
- seul `paths` est lu dans un frontmatter : un `description:` ne sert à rien et se retire ;
- dans un glob, `[` ouvre une classe de caractères : `\[uid\]` pour une route dynamique.

Relever au passage deux leçons qui se contredisent, ou une leçon qui contredit une commande : le signaler dans le tableau, ne pas trancher seul.

---

### Étape 3 — Proposer

Un seul tableau, une ligne par leçon ou section, dans l'ordre des fichiers :

| Élément (début) | Fichier | Destination | Où / preuve | Gain |
|---|---|---|---|---|
| `inputs.<x>` d'un boolean… | `rules/lessons.md` | Scoper | `rules/github-actions.md`, `.github/**` | 214 |

Puis l'estimation : total avant, total après, budget. Si le budget n'est pas atteint, dire ce qu'il faudrait de plus, sans forcer un tri qui perdrait une leçon utile : le budget se discute aussi.

Demander à Vincent de trancher, en un seul échange : il valide le tableau ou le corrige ligne par ligne.

---

### Étape 4 — Appliquer

Seulement ce qui est validé. La mesure de l'étape 1 tient lieu de recette de constat ; puis `/nina:task` si le tri a son issue, et la branche. Une règle scopée s'écrit :

```markdown
---
paths:
  - ".github/**"
---

# <Sujet>

- <règle> (repo#N)
```

Réécrire un fichier d'instructions, c'est le réécrire en entier avec Write, après l'avoir lu : un `sed` ou un `perl` sur du texte à guillemets, backticks et `…` rate en silence.

---

### Étape 5 — Vérifier et rendre compte

```bash
harnais.sh "$(git rev-parse --show-toplevel)"
```

Le total doit être celui annoncé à l'étape 3 ; chaque ligne supprimée doit avoir sa preuve dans le tableau. Pour une règle scopée nouvelle, vérifier dans le transcript qu'elle se charge pour de bon : ce que le modèle dit de son contexte ne prouve rien.

```bash
ID=$(echo "Lis <fichier qui matche> avec Read, et réponds OK." | claude -p --allowedTools Read --output-format json | jq -r .session_id)
grep -c '<phrase propre à la règle>' ~/.claude/projects/"$(pwd -P | sed 's/[^A-Za-z0-9]/-/g')"/"$ID".jsonl   # au moins 1
```

Pour une commande déléguée, rejouer la même commande avant et après sur le même cas, en `claude -p --plugin-dir plugins/nina --output-format json`, avec la lecture seule ouverte et la publication fermée (pour `/nina:review N` : `--allowedTools "Bash Read Glob Grep" --disallowedTools "Edit Write Bash(gh pr comment:*) Bash(gh pr review:*) Bash(git push:*) Bash(git commit:*) Bash(git checkout:*)"`), lire le JSON de sortie avec `printf '%s'`, pas `echo`, et comparer les tokens de la session principale et des `subagents/*.jsonl` du transcript, ainsi que le résultat : la pertinence se vérifie autant que le gain.

Le tableau validé, le avant et le après vont dans le corps de la PR (`/nina:pr`).
