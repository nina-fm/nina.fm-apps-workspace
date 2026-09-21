---
description: Lancer les vérifications, ajouter le changeset si besoin, pousser la branche et créer la PR
argument-hint: "[consignes supplémentaires]"
---

Lancer les vérifications et créer la pull request de la branche courante.

## Consignes

$ARGUMENTS

Tout ce qui se lit est en français : titre et corps de la PR, changeset, messages de commit après le préfixe conventionnel.

`$BRANCH` et `$BASE` ne survivent pas d'une commande à l'autre : les redéfinir au début de chaque commande, ou écrire les valeurs en clair une fois qu'on les connaît.

---

### Étape 1 — Contexte

```bash
BRANCH=$(git branch --show-current)
BASE=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
echo "Branche : $BRANCH → $BASE"
git fetch origin "$BASE"
git status --short
git log "origin/$BASE..HEAD" --oneline
gh pr list --head "$BRANCH" --state open --json url --jq '.[0].url // empty'   # une PR ouverte existe déjà ?
```

- Branche courante égale à `$BASE` : s'arrêter, une PR part d'une branche.
- Aucun commit d'avance et rien à commiter : s'arrêter, il n'y a rien à proposer.
- Modifications non commitées : demander à l'utilisateur s'il faut les commiter avant de continuer. Un en-tête de commit tient en 100 caractères : commitlint refuse au-delà (`header-max-length`), et le titre de la PR, qui devient celui du squash, suit la même limite. Un commit refusé laisse l'index en place, et le commit suivant de la chaîne l'embarque : un `fix` refusé est ainsi parti sous le `chore:` du changeset, et a été poussé en l'état (api#70). Un commit par commande, `git log -1` pour vérifier qu'il existe avant le suivant.
- Une PR ouverte existe déjà : lancer quand même les vérifications (étape 2), puis pousser la branche (étape 5), mettre à jour le corps de la PR s'il ne reflète plus les commits (`gh pr edit --body-file`), et donner son URL, sans en créer une autre. Une PR fermée ou mergée sur le même nom de branche ne compte pas.

---

### Étape 2 — Vérifications

Les scripts se déduisent du `package.json` à la racine du repo :

```bash
jq -r '.scripts | keys[]' package.json 2>/dev/null
```

Lancer dans l'ordre ceux qui existent : `lint`, `type-check`, puis `test:run` s'il existe, sinon `test`. Chaque script passe par son propre `rtk proxy`, le chaînage restant à l'extérieur :

```bash
rtk proxy pnpm lint && rtk proxy pnpm type-check && rtk proxy pnpm test
```

Sans `rtk proxy`, le hook réécrit `pnpm lint` en `eslint -f json .`, qui lint tout le dossier au lieu des chemins du script : dans nina.fm-api, ce lint tournait encore après 10 min, et il est passé en quelques secondes une fois relancé sous `rtk proxy`. Et le chaînage ne rentre pas dans les quotes — `rtk proxy 'pnpm lint && pnpm type-check'` passe `&& pnpm type-check` en arguments littéraux à `pnpm lint`, au lieu de lancer deux commandes.

Si le script retenu lance un runner en mode watch (`vitest` ou `jest --watch` sans `run`), ajouter `--run` : sans ça, la commande ne rend jamais la main.

Sans `package.json`, lancer les vérifications que documentent le `CLAUDE.md` du repo (ou `WORKSPACE.md` dans le workspace).

Si une vérification échoue :
1. Dire laquelle, avec la sortie d'erreur
2. Corriger, sauf si l'échec est antérieur à la branche et sans rapport avec elle : le signaler alors dans la PR
3. Relancer jusqu'à ce que tout passe

---

### Étape 3 — Contenu de la PR

```bash
git log "origin/$BASE..HEAD" --format='%s'
git diff "origin/$BASE...HEAD" --stat
```

Lire les commits et le diff pour savoir ce que la PR contient.

---

### Étape 4 — Changeset

Seulement si le repo utilise Changesets (`.changeset/config.json` existe) ; sinon passer.

- Commits `feat` ou `fix` : changeset **obligatoire**. `refactor` : `patch`. `chore`, `docs`, `test` seuls : aucun, sauf changement visible de l'utilisateur.
- Ne compter que les changesets **propres à la branche**. Un changeset déjà publié peut survivre au merge de `$BASE` dans la branche : il apparaît alors comme ajouté, mais `$BASE` l'a supprimé en le publiant. Celui-là se retire (`git rm`), il rejouerait l'entrée de changelog et le bump.

```bash
for f in $(git diff "origin/$BASE...HEAD" --name-only --diff-filter=A -- '.changeset/*.md'); do
  if git log "origin/$BASE" --diff-filter=D --oneline -1 -- "$f" | grep -q .; then
    echo "déjà publié : $f"
  else
    echo "propre à la branche : $f"
  fi
done
jq -r .name package.json
```

S'il en faut un et qu'il n'y en a pas, écrire `.changeset/<nom-court>.md` à la main — jamais `pnpm changeset`, qui est interactif :

```markdown
---
"<name du package.json>": patch
---

type(scope): description en français
```

Bump : `patch` (correctif, amélioration mineure), `minor` (fonctionnalité rétrocompatible), `major` (rupture).

```bash
git add .changeset/<nom-court>.md
git commit -m "chore: ajouter le changeset de <description courte>"
```

Jamais `[skip ci]` dans ce commit : le squash propagerait le tag au commit de `$BASE`.

---

### Étape 5 — Pousser la branche

```bash
git push --set-upstream origin "$BRANCH"
git rev-parse --abbrev-ref '@{u}'   # doit afficher origin/<branche>
```

La forme longue est voulue : rtk retire `-u`, et sans upstream `gh pr create` échoue.

---

### Étape 6 — Créer la PR

- **Titre** : `type(scope): description`, en français, tiré de la branche et des commits (ex. `fix(transitions): aligner le fondu sur le BPM`)
- **Base** : `$BASE`
- **Corps** : modèle ci-dessous, écrit dans un fichier par heredoc à guillemets simples (`<<'EOF'`) — un corps passé en argument se casse sur les apostrophes et les backticks

Si la branche part d'une issue (numéro dans le nom de branche, ou issue de départ de la session), le corps commence par `Closes #N` : l'issue passe à Done dans le Project au merge. Pour une issue d'un autre repo : `Closes nina-fm/<repo>#N`.

```bash
BODY=$(mktemp)
cat > "$BODY" <<'EOF'
Closes #N

## Résumé

- [ce qui change]
- [...]

## Recette

Scénario du constat et chemin nominal, rejoués sur la branche.

| Mesure | Avant | Après |
|--------|-------|-------|
| [...] | [...] | [...] |

## Vérifications

- [ ] [chaque vérification lancée à l'étape 2, avec son résultat]
- [ ] Changeset ajouté si commits `feat` ou `fix` (`.changeset/*.md`)
EOF
gh pr create --base "$BASE" --head "$BRANCH" --title "type(scope): description" --body-file "$BODY"
```

Adapter le corps : retirer ce qui ne s'applique pas (pas de Changesets, pas de mesure possible), ajouter la ligne d'attribution demandée par la session s'il y en a une.

---

### Étape 7 — Rendre compte

Si la PR ferme une issue, vérifier si c'est la dernière sous-issue ouverte d'une epic : GitHub ne ferme pas l'epic avec elle. Un seul appel, qui ne sort rien dans le cas courant (remplacer `{owner}/{repo}` par `nina-fm/<repo>` pour une issue d'un autre repo) :

```bash
# sans parent, l'API répond 404 et gh écrit le corps de l'erreur sur la sortie standard, d'où le filtre
gh api repos/{owner}/{repo}/issues/N/parent --jq 'select(.sub_issues_summary.total - .sub_issues_summary.completed == 1) | .html_url' 2>/dev/null | grep '^https' || true
```

Donner :
- l'URL de la PR
- branche → base
- le nombre de commits inclus
- l'epic que la PR achève, si l'appel ci-dessus en a sorti une : la fermer après le merge, puis lancer `/nina:plan` pour choisir la suite
- les avertissements : vérification sautée ou échouée hors périmètre, corrections automatiques du lint, changeset absent
