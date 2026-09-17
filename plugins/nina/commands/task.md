---
description: Analyser le code et présenter un plan d'implémentation pour une issue ou une description
argument-hint: "#N | URL d'issue | type(scope): description"
---

Analyser le code et présenter un plan d'implémentation détaillé pour : $ARGUMENTS

## Consignes

Tu es en **mode plan** : explorer le code, comprendre le contexte, présenter un plan structuré. Ne rien modifier — ni code, ni fichier, ni branche — avant que l'utilisateur ait approuvé le plan explicitement.

Tout ce que tu écris à l'utilisateur est en français, plan compris.

---

### Étape 0 — Si `$ARGUMENTS` est une issue (`#N` ou son URL)

La lire d'abord, avec ses commentaires, son epic et ses bloqueurs : les décisions qui y sont consignées font partie de la spec.

`{owner}/{repo}` est remplacé par `gh` d'après le repo courant. Pour l'URL d'un autre repo, remplacer par le `nina-fm/<repo>` de l'URL et ajouter `-R nina-fm/<repo>` à `gh issue view`.

```bash
gh issue view N --comments
# son epic : sans parent, l'API répond 404 et gh écrit le corps de l'erreur sur la sortie standard, d'où le filtre
gh api repos/{owner}/{repo}/issues/N/parent --jq '"#\(.number) \(.title)"' 2>/dev/null | grep '^#' || echo "pas d'epic"
gh api repos/{owner}/{repo}/issues/N/dependencies/blocked_by --jq '.[] | "\(.html_url) \(.state)"'
```

Si une issue ouverte la bloque, le dire et s'arrêter. Sinon, en tirer la tâche : le titre donne la description, le label `bug` le type `fix`. La PR portera `Closes #N`.

---

### Étape 1 — Recette de constat

Avant de prendre le ticket (voir « Recette » dans le `CLAUDE.md` du workspace) : reproduire le défaut, ou constater l'absence de la fonctionnalité, sur la branche par défaut à jour. Suivre le protocole du repo s'il en a un (commande `/recette`, section du `CLAUDE.md`).

```bash
DEFAULT=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
git fetch origin "$DEFAULT"
git rev-parse HEAD "origin/$DEFAULT"; git status --short
```

Si `HEAD` n'est pas `origin/$DEFAULT`, ou s'il reste des modifications, ne pas changer de branche : constater dans un worktree détaché (`git worktree add --detach <dossier temporaire> "origin/$DEFAULT"`), retiré à la fin du constat (`git worktree remove`).

Mesurer plutôt qu'observer, et garder les valeurs pour la PR. Un ticket qui ne se reproduit plus se commente et se ferme : le dire à l'utilisateur, et s'arrêter.

---

### Étape 2 — Explorer le code

Avant d'écrire quoi que ce soit :
- Lire `CLAUDE.md` (et les `CLAUDE.md` parents) pour connaître les conventions en vigueur
- Chercher les fichiers concernés : hooks, composables, services, composants, types existants
- Repérer les modèles à suivre dans les implémentations voisines
- Vérifier que rien d'existant ne couvre déjà une partie du besoin

---

### Étape 3 — Checklist du repo

```bash
ls "$(git rev-parse --show-toplevel)/.claude/checklists/task.md" 2>/dev/null
```

S'il existe, le lire **avec l'outil Read** plutôt qu'avec `cat`, dont le hook rtk filtre la sortie sur certains fichiers : une étape perdue en route ne serait pas déroulée. Dérouler ses étapes maintenant. Chaque section de plan qu'il demande s'ajoute au plan de l'étape 5, avant « Fichiers à créer ». Sans fichier, passer.

---

### Étape 4 — Nommer la branche

La branche est proposée dans le plan et créée seulement après approbation (étape 7).

Choisir le type conventionnel :
- préfixe de `$ARGUMENTS` s'il y en a un (`feat`, `fix`, `refactor`, `chore`, `docs`, `test`) ;
- pour une issue : label `bug` → `fix`, documentation ou outillage → `docs` ou `chore`, sinon `feat` ;
- sinon `feat`.

Écrire le slug à la main, à partir du titre ou de la description : minuscules ASCII sans accents, mots séparés par des tirets, 50 caractères au plus, précédé du numéro pour une issue (`feat/14-commandes-communes-plugin`). Ne pas slugifier `#N` : on obtiendrait `feat/-14`.

---

### Étape 5 — Présenter le plan

Structurer le plan **exactement** ainsi :

---

**Tâche :** $ARGUMENTS
**Branche proposée :** `<type>/<slug>`

**Recette de constat :** [ce qui a été reproduit ou constaté, avec les mesures]

#### Résumé
[2–3 phrases : ce qui sera construit, corrigé ou changé, pourquoi, et ce que ça change pour l'utilisateur ou le développeur]

[Sections demandées par `.claude/checklists/task.md`, s'il existe]

#### Fichiers à créer
| Fichier | Rôle |
|---------|------|
| `src/...` | [description] |

#### Fichiers à modifier
| Fichier | Changements |
|---------|-------------|
| `src/...` | [ce qui change et pourquoi] |

#### Tests à écrire
| Fichier | Scénarios |
|---------|-----------|
| `src/....test.ts` | [cas principaux] |

#### Impact sur les autres repos
[Changements nécessaires dans `nina.fm-api` ou dans une autre app — ou **Aucun**]

#### Questions ouvertes
[Ambiguïtés ou décisions à prendre par l'utilisateur — ou **Aucune**]

#### Estimation
[ ] Petit (< 2h) [ ] Moyen (2–4h) [ ] Grand (> 4h)

---

### Étape 6 — Attendre l'approbation

Terminer la réponse par exactement cette ligne :

> ✅ Plan prêt — je lance l'implémentation ?

N'écrire aucun code, ne créer ni fichier ni branche, et ne rien modifier avant que l'utilisateur ait approuvé (« go », « oui », « ok » ou équivalent).

---

### Étape 7 — Après approbation : créer la branche

Premier geste de l'implémentation, avec le nom retenu (corrigé s'il a été discuté) :

```bash
DEFAULT=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
git status --short    # s'il reste des modifications, le signaler avant de changer de branche
git fetch origin "$DEFAULT" && git checkout --no-track -b <type>/<slug> "origin/$DEFAULT"
```

La branche part de `origin/$DEFAULT` fraîchement récupérée : c'est le « sync avant de tirer une branche », et ça marche aussi dans un worktree, où la branche par défaut est souvent déjà extraite ailleurs.
