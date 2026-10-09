#!/usr/bin/env bash
# Signale les tags `X.Y.Z` des apps qui n'ont pas de GitHub Release (apps-workspace#52).
#
# `release.yml` pousse le tag et l'image avant de publier les notes : un échec à cette
# étape laisse une version livrée mais absente de l'onglet Releases, et le `::warning::`
# du run ne parle qu'à qui le regarde. Ce contrôle tient une issue unique dans le
# workspace : ouverte (ou mise à jour) tant qu'un écart existe, fermée quand il est résorbé.
#
# Sont écartés :
# - les tags antérieurs à la première release du repo, hors dispositif (`website 2.0.0`,
#   `faceb 0.6.6`) : sans ce filtre, le contrôle naît avec deux faux positifs permanents ;
# - les tags de moins de GRACE_HOURS heures, dont la release est peut-être en cours ou à relancer.
#
# Un repo illisible arrête le script en erreur : le compter pour zéro tag masquerait tout.
#
# Environnement :
#   REPOS        dépôts contrôlés, séparés par des espaces (owner/name)
#   ISSUE_REPO   dépôt où vit l'issue de suivi
#   READ_TOKEN   jeton de lecture des REPOS (défaut : l'authentification de gh)
#   GRACE_HOURS  âge minimal d'un tag pour être signalé (défaut : 24)
#   NOW          horodatage epoch de référence (défaut : maintenant), pour les tests
#   DRY_RUN=1    affiche les écarts sans toucher à l'issue
# shellcheck disable=SC2016 # backticks Markdown et variables GraphQL, entre guillemets simples à dessein
set -euo pipefail

: "${REPOS:?REPOS est requis}"
: "${ISSUE_REPO:?ISSUE_REPO est requis}"
GRACE_HOURS=${GRACE_HOURS:-24}
NOW=${NOW:-$(date +%s)}
TITLE='Releases manquantes : tags sans GitHub Release'

read_gh() {
  if [ -n "${READ_TOKEN:-}" ]; then GH_TOKEN="$READ_TOKEN" gh "$@"; else gh "$@"; fi
}

TAGS_QUERY='query($owner: String!, $name: String!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    refs(refPrefix: "refs/tags/", first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes { name target { ... on Commit { committedDate } ... on Tag { tagger { date } } } }
    }
  }
}'

# missing <owner/name> : une ligne `repo<TAB>version<TAB>date du tag` par tag sans release
missing() {
  local repo=$1 tags releases
  tags=$(read_gh api graphql --paginate -f owner="${repo%%/*}" -f name="${repo##*/}" -f query="$TAGS_QUERY" |
    jq -c '.data.repository.refs.nodes[] | {name, date: (.target.committedDate // .target.tagger.date)}' | jq -s .) ||
    { echo "::error::Tags de $repo illisibles." >&2; return 1; }
  releases=$(read_gh api "repos/$repo/releases" --paginate |
    jq -c '.[] | select(.draft | not) | {tag: .tag_name, date: .published_at}' | jq -s .) ||
    { echo "::error::Releases de $repo illisibles." >&2; return 1; }

  jq -rn --arg repo "$repo" --argjson tags "$tags" --argjson releases "$releases" \
    --argjson limit "$((NOW - GRACE_HOURS * 3600))" '
    ($releases | map(.tag)) as $released
    | ($releases | map(.date | fromdateiso8601) | min) as $first
    | if $first == null then empty else
        $tags[]
        | select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
        | (.date | fromdateiso8601) as $d
        | select($d >= $first and $d <= $limit)
        | select(.name as $n | $released | index($n) | not)
        | [$repo, .name, .date] | @tsv
      end'
}

gaps=''
for repo in $REPOS; do
  found=$(missing "$repo")
  [ -n "$found" ] && gaps+="$found"$'\n'
done
gaps=${gaps%$'\n'}

if [ -n "$gaps" ]; then
  while IFS=$'\t' read -r repo version date; do
    echo "::warning::$repo $version (tag du $date) n'a pas de GitHub Release."
  done <<<"$gaps"
else
  echo "Aucun tag sans release dans : $REPOS"
fi

[ "${DRY_RUN:-}" = 1 ] && exit 0

issue=$(gh issue list -R "$ISSUE_REPO" --state open --limit 200 --json number,title |
  jq -r --arg t "$TITLE" 'map(select(.title == $t)) | first | .number // empty')
body=$(mktemp)
trap 'rm -f "$body"' EXIT

if [ -n "$gaps" ]; then
  {
    echo '## Tags sans GitHub Release'
    echo
    echo "Relevé du $(date -u -r "$NOW" +%F 2>/dev/null || date -u -d "@$NOW" +%F), tags de plus de ${GRACE_HOURS} h postérieurs à la première release de leur repo."
    echo
    echo '| Repo | Version | Date du tag |'
    echo '|---|---|---|'
    while IFS=$'\t' read -r repo version date; do
      echo "| \`$repo\` | \`$version\` | ${date%%T*} |"
    done <<<"$gaps"
    echo
    echo '## Rattrapage'
    echo
    echo 'Notes reprises de la section de la version dans le `CHANGELOG.md` du repo, au tag.'
    echo '`--latest=false` est indispensable : sans lui, une vieille version reprend le badge `Latest`.'
    echo
    echo '```bash'
    while IFS=$'\t' read -r repo version _; do
      echo "gh release create $version -R $repo --title 'Release $version' --notes-file notes.md --latest=false"
    done <<<"$gaps"
    echo '```'
    echo
    echo "Cette issue est tenue par \`.github/workflows/releases-check.yml\` : elle se ferme d'elle-même au premier passage sans écart."
  } >"$body"
  if [ -n "$issue" ]; then
    gh issue edit "$issue" -R "$ISSUE_REPO" --body-file "$body" >/dev/null
    echo "Issue #$issue mise à jour."
  else
    gh issue create -R "$ISSUE_REPO" --title "$TITLE" --body-file "$body"
  fi
elif [ -n "$issue" ]; then
  echo 'Toutes les versions taguées ont désormais leur GitHub Release.' >"$body"
  gh issue comment "$issue" -R "$ISSUE_REPO" --body-file "$body" >/dev/null
  gh issue close "$issue" -R "$ISSUE_REPO" --reason completed >/dev/null
  echo "Issue #$issue fermée."
fi
