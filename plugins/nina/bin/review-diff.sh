#!/usr/bin/env bash
# Le diff que /nina:review relit, sans le contenu des fichiers générés.
#
#   review-diff.sh        la branche courante, contre la branche par défaut
#   review-diff.sh N      la PR N du repo courant
#
# Un fichier est généré si le repo le déclare `linguist-generated` dans son
# .gitattributes. Le marqueur est celui de GitHub, qui replie déjà ces fichiers
# dans la vue PR : une seule déclaration sert les deux. Les lockfiles le sont
# d'office — ils sont générés partout, les déclarer n'apprendrait rien —, sauf si
# le repo dit explicitement le contraire (`-linguist-generated`).
#
# Les générés restent dans le récapitulatif et dans la liste des fichiers : ce qui
# compte est qu'ils aient changé, et en cohérence avec leur source. Leur contenu,
# lui, n'est jamais un sujet de review, puisque le CLAUDE.md du workspace interdit
# de les modifier à la main. Le lire coûtait des dizaines de milliers de
# caractères, relus à chaque requête de la review.
set -euo pipefail

LOCKFILES="pnpm-lock.yaml package-lock.json yarn.lock"

is_lockfile() {
  local name=${1##*/} lock
  for lock in $LOCKFILES; do
    [ "$name" = "$lock" ] && return 0
  done
  return 1
}

pr=${1:-}
if [ -n "$pr" ]; then
  case "$pr" in
    *[!0-9]*) echo "usage : review-diff.sh [numéro de PR]" >&2; exit 2 ;;
  esac
  # La base d'époque (`baseRefOid`), pas la branche de base d'aujourd'hui : c'est
  # celle dont GitHub tire le diff de la PR. Un merge sans squash pose la tête de
  # la PR dans l'historique de la base, et `origin/<base>...<tête>` est alors
  # vide — la review n'aurait rien eu à relire, sans rien pour le signaler.
  read -r base_sha base < <(gh pr view "$pr" --json baseRefOid,baseRefName \
    --jq '"\(.baseRefOid) \(.baseRefName)"')
  # La base d'abord, la tête ensuite : FETCH_HEAD retient le dernier fetch, et la
  # PR se relit ainsi sans créer de ref locale qu'il faudrait penser à retirer.
  git fetch --quiet origin "$base_sha"
  git fetch --quiet origin "refs/pull/$pr/head"
  head=$(git rev-parse FETCH_HEAD)
  label="PR #$pr"
else
  base=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
  git fetch --quiet origin "$base"
  base_sha="origin/$base"
  head=HEAD
  label=$(git rev-parse --abbrev-ref HEAD)
fi

range="$base_sha...$head"
changed=$(git diff --name-only "$range")

# `git check-attr` rend « set » pour un attribut nu, « true » pour une valeur
# explicite, « unset » pour une exclusion : n'en reconnaître qu'un seul écarterait
# la moitié des repos en silence, sans que rien ne le signale.
generated=()
if [ -n "$changed" ]; then
  while IFS= read -r line; do
    file=${line%%: linguist-generated:*}
    case "$line" in
      *": linguist-generated: set"|*": linguist-generated: true")
        generated+=("$file") ;;
      *": linguist-generated: unset")
        : ;;  # le repo l'a explicitement dit relisible : sa déclaration prime
      *)
        is_lockfile "$file" && generated+=("$file") ;;
    esac
  done < <(printf '%s\n' "$changed" | git check-attr --stdin linguist-generated)
fi

excludes=()
for file in ${generated[@]+"${generated[@]}"}; do
  excludes+=(":(literal,exclude)$file")
done

total=$(printf '%s\n' "$changed" | grep -c . || true)
echo "Review de $label → $base"
echo "Fichiers modifiés : $total | Écartés du contenu, car générés : ${#generated[@]}"

echo
echo "--- Commits ---"
git log "$base_sha..$head" --oneline

echo
echo "--- Récapitulatif, tous fichiers ---"
git diff "$range" --stat

echo
echo "--- Fichiers générés, écartés du contenu ---"
if [ ${#generated[@]} -gt 0 ]; then
  printf '%s\n' "${generated[@]}"
  echo "Leur contenu n'est pas relu : vérifier qu'ils ont été régénérés depuis la source, pas édités."
else
  echo "Aucun."
fi
if ! grep -q linguist-generated "$(git rev-parse --show-toplevel)/.gitattributes" 2>/dev/null; then
  echo "Ce repo ne déclare aucun chemin généré. Pour en déclarer, dans son .gitattributes :"
  echo "  src/api/** linguist-generated=true"
  echo "  src/api/fetcher.ts -linguist-generated   # écrit à la main, au milieu du généré"
fi

echo
echo "--- Diff à relire ---"
git diff "$range" -- . ${excludes[@]+"${excludes[@]}"}
