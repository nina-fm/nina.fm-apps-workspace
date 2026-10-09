#!/usr/bin/env bash
# Test de non-régression de releases-manquantes.sh : bash .github/scripts/releases-manquantes.test.sh
# Un faux `gh` sert des réponses brutes de l'API (les filtres jq du script sont donc
# éprouvés) depuis un dossier de fixtures, et consigne ses appels.

# shellcheck disable=SC2016 # backticks Markdown attendus dans le corps
script="$(cd "$(dirname "$0")" && pwd)/releases-manquantes.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "ÉCHEC $1"
  failures=$((failures + 1))
}

mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
# GH_LOG_TOKEN=1 préfixe chaque appel du jeton qu'il reçoit
if [ -n "${GH_LOG_TOKEN:-}" ]; then echo "[${GH_TOKEN:-}] $*"; else echo "$*"; fi >>"$GH_CALLS"
# un corps passé par --body-file est recopié, pour que le test le relise
prev=''
for a in "$@"; do
  [ "$prev" = --body-file ] && cp "$a" "$GH_BODY"
  prev=$a
done
case "$1 $2" in
  "api graphql")
    for a in "$@"; do case "$a" in name=*) name=${a#name=} ;; esac; done
    cat "$FIXTURES/$name.tags" 2>/dev/null || { echo 'HTTP 404: Not Found' >&2; exit 1; }
    ;;
  "api repos/"*)
    name=${2#repos/*/}
    name=${name%/releases}
    cat "$FIXTURES/$name.releases" 2>/dev/null || { echo 'HTTP 404: Not Found' >&2; exit 1; }
    ;;
  "issue list") cat "$FIXTURES/issues.json" ;;
  "issue create") echo "https://github.com/o/ws/issues/99" ;;
esac
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GH_CALLS="$work/calls" GH_BODY="$work/body" FIXTURES="$work/fixtures"

# Référence : 2026-10-09T12:00:00Z
export NOW=1791547200 ISSUE_REPO=o/ws GRACE_HOURS=24
unset READ_TOKEN DRY_RUN

# tags <repo> <nom:date>... : réponse GraphQL d'une page de tags
tags() {
  local name=$1 nodes='' t
  shift
  for t in "$@"; do
    nodes+="{\"name\":\"${t%%=*}\",\"target\":{\"committedDate\":\"${t#*=}\"}},"
  done
  printf '{"data":{"repository":{"refs":{"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[%s]}}}}' \
    "${nodes%,}" >"$FIXTURES/$name.tags"
}

# releases <repo> <tag=date|tag=draft>... : réponse REST, en deux pages comme --paginate les enchaîne
releases() {
  local name=$1 items='' t
  shift
  for t in "$@"; do
    if [ "${t#*=}" = draft ]; then
      items+="{\"tag_name\":\"${t%%=*}\",\"published_at\":null,\"draft\":true},"
    else
      items+="{\"tag_name\":\"${t%%=*}\",\"published_at\":\"${t#*=}\",\"draft\":false},"
    fi
  done
  printf '[%s]\n[]\n' "${items%,}" >"$FIXTURES/$name.releases"
}

reset() {
  rm -rf "$FIXTURES" "$GH_CALLS" "$GH_BODY"
  mkdir -p "$FIXTURES"
  echo '[]' >"$FIXTURES/issues.json"
  touch "$GH_CALLS"
}

run() {
  out=$(REPOS="$1" bash "$script" 2>&1)
  status=$?
}

# --- Un tag ancien sans release est signalé, une issue s'ouvre
reset
tags app 1.0.0=2026-01-01T00:00:00Z 1.0.1=2026-02-01T00:00:00Z
releases app 1.0.0=2026-01-01T01:00:00Z
run o/app
[ "$status" -eq 0 ] || fail "tag sans release : sortie $status ($out)"
grep -qF '::warning::o/app 1.0.1' <<<"$out" || fail "tag sans release : pas d'avertissement ($out)"
grep -q '^issue create' "$GH_CALLS" || fail "tag sans release : aucune issue créée"
grep -qF '| `o/app` | `1.0.1` | 2026-02-01 |' "$GH_BODY" || fail "tag sans release : ligne absente du corps"
grep -qF 'gh release create 1.0.1 -R o/app' "$GH_BODY" || fail "tag sans release : commande de rattrapage absente"
grep -qF -- '--latest=false' "$GH_BODY" || fail "tag sans release : --latest=false absent"

# --- Les tags écartés : antérieur à la 1re release, trop récent, hors format, brouillon
reset
tags app 0.9.0=2025-12-01T00:00:00Z 1.0.0=2026-01-01T00:00:00Z \
  1.1.0=2026-10-09T00:00:00Z v1.2.0=2026-03-01T00:00:00Z 1.3.0=2026-04-01T00:00:00Z
# un brouillon n'est pas une release publiée : 1.3.0 doit rester signalé
releases app 1.0.0=2026-01-01T01:00:00Z 1.3.0=draft
run o/app
[ "$(grep -c '::warning::' <<<"$out")" -eq 1 ] || fail "filtres : un seul tag attendu ($out)"
grep -qF '::warning::o/app 1.3.0' <<<"$out" || fail "filtres : brouillon pris pour une release ($out)"
grep -qF '0.9.0' <<<"$out" && fail "filtres : tag antérieur à la 1re release signalé"
grep -qF '1.1.0' <<<"$out" && fail "filtres : tag de moins de 24 h signalé"
grep -qF 'v1.2.0' <<<"$out" && fail "filtres : tag hors format signalé"

# --- Un repo sans aucune release, et un repo sans tag, ne signalent rien
reset
tags app 1.0.0=2026-01-01T00:00:00Z
releases app
tags vide
releases vide
run "o/app o/vide"
[ "$status" -eq 0 ] || fail "sans release : sortie $status ($out)"
grep -q '::warning::' <<<"$out" && fail "sans release : avertissement inattendu ($out)"
grep -qE '^issue (create|edit|comment|close)' "$GH_CALLS" && fail "sans écart ni issue : écriture inattendue"

# --- Un repo illisible arrête le script sans toucher à l'issue
reset
tags app 1.0.0=2026-01-01T00:00:00Z
releases app 1.0.0=2026-01-01T01:00:00Z
echo '[{"number":7,"title":"Releases manquantes : tags sans GitHub Release"}]' >"$FIXTURES/issues.json"
run "o/app o/prive"
[ "$status" -ne 0 ] || fail "repo illisible : sortie 0"
grep -qF '::error::Tags de o/prive illisibles' <<<"$out" || fail "repo illisible : message absent ($out)"
grep -q '^issue' "$GH_CALLS" && fail "repo illisible : l'issue a été touchée"

# --- Une issue déjà ouverte est mise à jour, pas doublée
reset
tags app 1.0.0=2026-01-01T00:00:00Z 1.0.1=2026-02-01T00:00:00Z
releases app 1.0.0=2026-01-01T01:00:00Z
echo '[{"number":3,"title":"Autre chose"},{"number":7,"title":"Releases manquantes : tags sans GitHub Release"}]' >"$FIXTURES/issues.json"
run o/app
grep -q '^issue edit 7 ' "$GH_CALLS" || fail "issue ouverte : pas de mise à jour de #7"
grep -q '^issue create' "$GH_CALLS" && fail "issue ouverte : une seconde issue a été créée"

# --- Plus d'écart : l'issue ouverte est commentée puis fermée
reset
tags app 1.0.0=2026-01-01T00:00:00Z
releases app 1.0.0=2026-01-01T01:00:00Z
echo '[{"number":7,"title":"Releases manquantes : tags sans GitHub Release"}]' >"$FIXTURES/issues.json"
run o/app
grep -q '^issue comment 7 ' "$GH_CALLS" || fail "écart résorbé : pas de commentaire"
grep -q '^issue close 7 .*--reason completed' "$GH_CALLS" || fail "écart résorbé : issue non fermée"

# --- DRY_RUN signale sans écrire
reset
tags app 1.0.0=2026-01-01T00:00:00Z 1.0.1=2026-02-01T00:00:00Z
releases app 1.0.0=2026-01-01T01:00:00Z
out=$(DRY_RUN=1 REPOS=o/app bash "$script" 2>&1)
grep -qF '::warning::o/app 1.0.1' <<<"$out" || fail "DRY_RUN : pas d'avertissement"
grep -q '^issue' "$GH_CALLS" && fail "DRY_RUN : l'issue a été touchée"

# --- READ_TOKEN sert aux lectures des repos, pas à l'issue
reset
tags app 1.0.0=2026-01-01T00:00:00Z
releases app 1.0.0=2026-01-01T01:00:00Z
out=$(GH_LOG_TOKEN=1 READ_TOKEN=lecture GH_TOKEN=issues REPOS=o/app bash "$script" 2>&1)
grep -q '^\[lecture\] api graphql' "$GH_CALLS" || fail "READ_TOKEN : tags lus sans le jeton de lecture"
grep -q '^\[lecture\] api repos/o/app/releases' "$GH_CALLS" || fail "READ_TOKEN : releases lues sans le jeton de lecture"
grep -q '^\[issues\] issue list' "$GH_CALLS" || fail "READ_TOKEN : l'issue lue avec le mauvais jeton"

if [ "$failures" -gt 0 ]; then
  echo "$failures échec(s)"
  exit 1
fi
echo "OK"
