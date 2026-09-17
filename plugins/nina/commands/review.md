---
description: Relire le diff de la branche ou d'une PR, et publier la review sur la PR si un numéro est donné
argument-hint: "[numéro de PR]"
---

Faire une review approfondie des changements.

$ARGUMENTS

Si `$ARGUMENTS` contient un numéro de PR (ex. `42`), relire le diff de cette PR et publier la review en commentaire à la fin. Sinon, relire le diff local de la branche courante, sans rien publier.

La review est rédigée en français.

---

### Étape 1 — Récupérer le diff

```bash
review-diff.sh        # la branche courante, contre la branche par défaut
review-diff.sh N      # la PR N du repo courant
```

Un seul appel rend l'entête, les commits, le récapitulatif de **tous** les fichiers modifiés, la liste de ceux qui sont écartés, et le diff à relire.

Le **contenu** des fichiers générés en est retiré — le repo les déclare `linguist-generated` dans son `.gitattributes`. Ce contenu n'est jamais un sujet de review, puisqu'on ne le modifie pas à la main ; le lire coûtait des dizaines de milliers de caractères, relus à chaque requête. Ce qui reste à vérifier sur eux est dans le récapitulatif : qu'ils aient changé, et en cohérence avec leur source. Si le script signale que le repo ne déclare aucun chemin généré, le dire dans la review.

Avec un numéro de PR, lire aussi sa description, qui porte le contexte et la recette :

```bash
gh pr view N --json title,body,url --jq '"\(.title)\n\(.url)\n\n\(.body)"'
```

Lire aussi le `CLAUDE.md` du repo (et ses parents) : ses conventions font partie des critères.

---

### Étape 2 — Checklist du repo

```bash
ls "$(git rev-parse --show-toplevel)/.claude/checklists/review.md" 2>/dev/null
```

S'il existe, le lire **avec l'outil Read** plutôt qu'avec `cat`, dont le hook rtk filtre la sortie sur certains fichiers : une case perdue en route ne serait pas vérifiée. Ses sections s'ajoutent alors à celles de l'étape 3 et s'appliquent aux fichiers qu'elles visent. Sans fichier, la checklist commune suffit.

---

### Étape 3 — Relire chaque fichier modifié

Parcourir les fichiers un à un, en appliquant les sections qui les concernent : celles ci-dessous, puis celles de la checklist du repo.

#### TypeScript
- [ ] Aucun `any` dans le nouveau code — `unknown` et type guards pour les données externes (API, events, localStorage)
- [ ] `catch (error: unknown)`, jamais `catch (error: any)`
- [ ] Types de retour explicites sur les fonctions et méthodes publiques
- [ ] `??` plutôt que `||` pour les valeurs par défaut
- [ ] `readonly` sur les dépendances injectées et les refs non mutables
- [ ] Aucune variable, import ou paramètre inutilisé
- [ ] Aucune valeur en dur qui relève d'une constante ou d'une variable d'environnement

#### Réutilisation
- [ ] Rien d'existant (hook, composable, service, composant, util) ne couvrait déjà le besoin
- [ ] Aucun fichier généré modifié à la main — ceux que l'étape 1 a écartés : la source est corrigée, et le fichier régénéré. Les chemins générés sont ceux que le `.gitattributes` du repo déclare, pas une liste tenue ici

#### Tests
- [ ] La logique métier, les cas d'erreur et les régressions connues ont leurs tests
- [ ] Nommage `it('should [comportement] when [condition]')`
- [ ] Factories pour les objets complexes (`createMockTrack()`…), pas de littéraux recopiés
- [ ] Mocks limités aux dépendances externes (DB, HTTP), pas à la logique métier
- [ ] Tests isolés, sans état mutable partagé entre les `it()`
- [ ] Aucun snapshot test

#### Sécurité et performance
- [ ] Aucune donnée sensible dans les logs ou les messages d'erreur
- [ ] Aucune lecture ni recopie de `.env` ; les secrets passent par l'environnement
- [ ] Aucune opération bloquante ou synchrone coûteuse sur un chemin chaud

#### Langue, livraison et recette
- [ ] Commentaires, docs et messages en français ; identifiants en anglais
- [ ] Commits conventionnels, description en français
- [ ] Changeset présent si commits `feat` ou `fix` et que le repo utilise Changesets, sans `[skip ci]` — à suggérer écrit à la main dans `.changeset/<nom>.md` (ou via `/nina:pr`), jamais `pnpm changeset`, qui est interactif
- [ ] La PR rapporte la recette : scénario du constat et chemin nominal, mesures avant / après
- [ ] Un défaut trouvé hors périmètre est consigné dans une issue, pas seulement dans la PR

---

### Étape 4 — Rédiger la review

Mettre en forme **exactement** ainsi :

---

## Review

**Branche :** `<branche>` → `<base>`
**Fichiers modifiés :** [n] | **Commits :** [n] | **Générés écartés du contenu :** [n]
**Checklist du repo :** `.claude/checklists/review.md` appliquée | aucune
**Verdict :** ✅ Prêt à merger | ⚠️ Points mineurs | ❌ Changements nécessaires

### Points forts
- [ce qui est particulièrement bien fait]

### Problèmes

| Gravité | Fichier | Problème | Suggestion |
|---------|---------|----------|------------|
| 🔴 Bloquant | `path/to/file.ts:42` | [problème] | [correction] |
| 🟡 Attention | `path/to/file.ts:42` | [problème] | [correction] |
| 🔵 Suggestion | `path/to/file.ts:42` | [amélioration] | [comment faire] |

_Sans problème : « Aucun problème relevé. »_

### Synthèse
[2–3 phrases : qualité, risques, prêt ou non à merger]

---

### Étape 5 — Publier sur la PR (si un numéro est donné)

Écrire la review dans un fichier par heredoc à guillemets simples, puis la publier — un corps passé en argument se casse sur les apostrophes et les backticks :

```bash
REVIEW=$(mktemp)
cat > "$REVIEW" <<'EOF'
[review de l'étape 4]
EOF
gh pr comment N --body-file "$REVIEW"
```

Répondre : « Review publiée sur la PR #N », avec l'URL du commentaire renvoyée par `gh`.
