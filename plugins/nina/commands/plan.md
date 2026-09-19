---
description: Revoir le plan du Project GitHub — monter, garder, descendre ou fermer chaque issue
argument-hint: "[consignes supplémentaires]"
---

Revoir le plan du Project de la session et trancher, issue par issue, ce qui monte, reste, descend ou se ferme.

## Consignes

$ARGUMENTS

Tout ce qui se lit est en français. Se lance au signal de `plan.sh` (« Maintenant » vide ou qui déborde) ou à la fermeture d'une epic. Sans `NINA_PROJECT`, s'arrêter : la session n'a pas de Project.

« Maintenant » est un engagement court : l'epic en cours, ou 2 ou 3 issues isolées. Les sous-issues suivent l'Horizon de leur epic et ne se trient pas une à une.

---

### Étape 1 — Lister

```bash
plan.sh list
```

Une ligne par issue ouverte de « Maintenant », « Ensuite » et « Plus tard » : Horizon, référence, dernière mise à jour, avancement des sous-issues d'une epic, parent, statut en cours, titre. La revue se fait **sur ce listing** : ne pas ouvrir les corps un à un, une revue de Mixtaper y laisserait des dizaines de milliers de tokens.

N'ouvrir le corps (`gh issue view N --json body,comments`) que d'une issue qu'on ne peut pas trancher sans : titre qui ne dit pas l'enjeu, ou issue qui semble périmée — pas touchée depuis longtemps, ou visée par un travail déjà mergé.

---

### Étape 2 — Proposer

Un seul tableau, les sous-issues rangées sous leur epic sans ligne propre :

| Issue | Horizon | Proposition | Pourquoi |
|-------|---------|-------------|----------|
| `#N` titre court | Ensuite | Monter en Maintenant | [une phrase] |

Propositions : **monter**, **garder**, **descendre** (vers quel Horizon), **fermer** (périmée, faite ailleurs, doublon — dire laquelle). Viser un « Maintenant » tenable : une epic, ou 2 ou 3 issues isolées ; une epic achevée (sous-issues toutes fermées) se ferme.

Demander à l'utilisateur de trancher, en un seul échange : il valide le tableau ou le corrige ligne par ligne.

---

### Étape 3 — Appliquer

Seulement ce que l'utilisateur a validé :

```bash
plan.sh move <url> <Horizon>      # une epic entraîne ses sous-issues ouvertes
```

Pour une issue à fermer, le motif en commentaire, écrit par heredoc `<<'EOF'` — `gh issue close` n'a pas de `--comment-file`, et `--comment` en argument casse sur les apostrophes :

```bash
gh issue comment <url> --body-file <fichier>
gh issue close <url> --reason "not planned"   # completed si faite ailleurs, duplicate --duplicate-of <url> pour un doublon
```

Chaque sortie de `plan.sh` nomme le Project visé : vérifier que c'est celui de la revue.

---

### Étape 4 — Rendre compte

Relancer `plan.sh` : le plan affiché ne doit plus porter de signal. Donner la répartition par Horizon avant et après, et l'issue à démarrer ensuite avec `/nina:task`.
