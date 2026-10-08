---
description: Mesurer ce que le harnais charge à chaque session, trier ses lignes et le ramener sous son budget
argument-hint: "[fichier ou section à revoir en priorité]"
---

Ramener ce qui se charge à chaque session sous son budget, sans perdre une leçon : chaque ligne reste, change de place, se condense, ou sort pour une raison qu'on peut vérifier.

## Consignes

$ARGUMENTS

Tout ce qui se lit est en français. Le périmètre est le repo de la session (`git rev-parse --show-toplevel`) : son `CLAUDE.md`, ses `.claude/rules/`, et la mémoire automatique de la session. Le workspace se revoit depuis le workspace ; `~/.claude/` ne se propose qu'à Vincent, sans l'appliquer d'office.

---

### Étape 1 — Mesurer

```bash
harnais.sh "$(git rev-parse --show-toplevel)"
```

Depuis le workspace, le lancer aussi sur chacun des cinq repos (`nina.fm-*`) : ce que le workspace charge se paye dans les cinq.

Chaque ligne donne les caractères d'un fichier chargé, puis le total, estimé en tokens, contre le budget (`HARNAIS_BUDGET`, 18 000 caractères par défaut pour une session entière). Les règles à `paths:` sont listées à part : elles ne coûtent qu'à la lecture d'un fichier qui correspond. Garder la sortie : c'est le « avant » de la PR.

---

### Étape 2 — Classer

Lire chaque fichier du périmètre avec l'outil Read (rtk filtre `cat`), et donner une destination à chaque leçon, ou à chaque section d'un `CLAUDE.md` :

| Destination | Quand | Ce qu'il faut prouver |
|---|---|---|
| **Garder** | Peut servir à n'importe quel moment, et aucun outil ne l'applique | — |
| **Condenser** | L'énoncé est noyé dans l'histoire (dates, chiffres de l'incident) | L'issue citée porte l'histoire : la règle garde son énoncé et `(repo#N)` |
| **Scoper** | Ne sert qu'en touchant certains fichiers | Le glob matche les fichiers visés (`git ls-files \| grep`) ; voir les limites ci-dessous |
| **Déplacer** | Ne sert que pendant une commande, en retouchant le plugin, ou au-dessus d'un code précis | La destination : `plugins/nina/commands/<cmd>.md`, `plugins/nina/LESSONS.md`, commentaire dans le script |
| **Supprimer** | Un outil l'applique, elle est obsolète, ou elle double une autre source | Pour un outil : la règle de lint, le test ou la CI qui échoue sans elle, constaté. Pour l'obsolète : ce qui l'a rendue caduque. Pour un doublon : où vit l'original |

Limites d'une règle à `paths:` :

- elle se charge quand Read, Write ou Edit touche un fichier qui correspond, pas sur `gh`, `cat` ni sur un fichier lu par Bash : une leçon sur des logs CI ou une réponse d'API ne se scope pas ;
- un glob d'une règle du workspace matche aussi depuis un sous-repo (`.github/**` se déclenche sur `nina.fm-website/.github/workflows/ci.yml`, #79) ;
- seul `paths` est lu dans un frontmatter : un `description:` ne sert à rien et se retire ;
- dans un glob, `[` ouvre une classe de caractères : `\[uid\]` pour une route dynamique.

Relever au passage deux leçons qui se contredisent, ou une leçon qui contredit une commande : le signaler dans le tableau, ne pas trancher seul.

---

### Étape 3 — Proposer

Un seul tableau, une ligne par leçon ou section, dans l'ordre des fichiers :

| Leçon (début) | Fichier | Destination | Où / preuve | Gain |
|---|---|---|---|---|
| `inputs.<x>` d'un boolean… | `rules/lessons.md` | Scoper | `rules/github-actions.md`, `.github/**` | 214 |

Puis l'estimation : total avant, total après, budget. Si le budget n'est pas atteint, dire ce qu'il faudrait de plus, sans forcer un tri qui perdrait une leçon utile : le budget se discute aussi.

Demander à Vincent de trancher, en un seul échange : il valide le tableau ou le corrige ligne par ligne.

---

### Étape 4 — Appliquer

Seulement ce qui est validé, sur une branche (`/nina:task` d'abord si le tri a son issue). Une règle scopée s'écrit :

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

Le total doit être celui annoncé à l'étape 3 ; chaque ligne supprimée doit avoir sa preuve dans le tableau. Pour une règle scopée nouvelle, vérifier qu'elle se charge pour de bon :

```bash
echo "Lis <fichier qui matche> avec Read, puis cite le titre de chaque règle .claude/rules chargée depuis." | claude -p --allowedTools Read
```

Le tableau validé, le avant et le après vont dans le corps de la PR (`/nina:pr`).
