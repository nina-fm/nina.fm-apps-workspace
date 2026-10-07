#!/usr/bin/env bash
# Test de non-régression de plan.sh : bash plugins/nina/bin/plan.test.sh
# gh est remplacé par un faux qui sert des données fixes et consigne ses appels.

script="$(cd "$(dirname "$0")" && pwd)/plan.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "ÉCHEC $1"
  failures=$((failures + 1))
}

mkdir -p "$work/bin" "$work/repo" "$work/api"
# gh api <chemin> sert le fichier $GH_API/<chemin, / devenus _>, qui contient les pages
# de la réponse, une par élément : --slurp les rend telles quelles, --paginate les
# concatène, sinon la première seule — et --jq avec --slurp est refusé, comme le vrai gh.
# Sans fichier, un 404 dont le corps part sur la sortie standard, comme le vrai gh.
# gh api graphql -f owner= -f repo= -F n= sert $GH_API/resource_<owner>_<repo>_issues_<n> ;
# sans fichier, une issue sans epic ni Project. Le numéro 99999 n'est pas une issue :
# comme le vrai gh, le corps JSON sur la sortie standard, le message en code 1.
# L'item d'une issue est ITEM_<repo>_<numéro>, pour voir lesquels sont modifiés.
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_CALLS"
[ -z "${GH_FAIL:-}" ] || exit 1
case "$1 $2 $3" in
  "project view 1") out='{"id":"PVT_1","title":"Mixtaper","url":"https://github.com/orgs/nina-fm/projects/1"}' ;;
  "project view 2") out='{"id":"PVT_2","title":"Apps Workspace","url":"https://github.com/orgs/nina-fm/projects/2"}' ;;
  "project item-list "*) out=$(cat "$GH_ITEMS") ;;
  "project field-list "*) out='{"fields":[
    {"id":"F_status","name":"Status","options":[{"id":"O_todo","name":"Todo"},{"id":"O_progress","name":"In Progress"},{"id":"O_done","name":"Done"}]},
    {"id":"F_horizon","name":"Horizon","options":[{"id":"O_now","name":"Maintenant"},{"id":"O_next","name":"Ensuite"},{"id":"O_later","name":"Plus tard"}]}]}' ;;
  "project item-add "*)
    url=$(sed 's/.*--url \([^ ]*\).*/\1/' <<<"$*")
    repo=${url%/issues/*}
    out="{\"id\":\"ITEM_${repo##*/}_${url##*/}\"}"
    ;;
  "api graphql -f")
    owner=$(sed -n 's/.*-f owner=\([^ ]*\).*/\1/p' <<<"$*")
    repo=$(sed -n 's/.*-f repo=\([^ ]*\).*/\1/p' <<<"$*")
    n=$(sed -n 's/.*-F n=\([^ ]*\).*/\1/p' <<<"$*")
    file="$GH_API/resource_${owner}_${repo}_issues_$n"
    if [ "$n" = 99999 ]; then
      echo '{"data":{"repository":{"issue":null}},"errors":[{"type":"NOT_FOUND"}]}'
      echo "gh: Could not resolve to an Issue with the number of $n." >&2; exit 1
    elif [ -f "$file" ]; then out=$(jq -c '.[0]' "$file")
    else out='{"data":{"repository":{"issue":{"projectItems":{"nodes":[]},"parent":null}}}}'; fi
    ;;
  "api "*)
    file="$GH_API/$(tr / _ <<<"$2")"
    if [ ! -f "$file" ]; then echo '{"message":"Not Found","status":"404"}'; exit 1; fi
    case "$*" in
      *--slurp*--jq*|*--jq*--slurp*) echo "the \`--slurp\` option is not supported with \`--jq\` or \`--template\`" >&2; exit 1 ;;
      *--slurp*) out=$(jq -c . "$file") ;;
      *--paginate*) out=$(jq -c add "$file") ;;
      *) out=$(jq -c '.[0]' "$file") ;;
    esac
    ;;
  *) out='' ;;
esac
jq_filter=""
while [ $# -gt 0 ]; do
  [ "$1" = --jq ] && jq_filter=$2
  shift
done
if [ -n "$jq_filter" ]; then jq -r "$jq_filter" <<<"$out"; else printf '%s\n' "$out"; fi
EOF
chmod +x "$work/bin/gh"

MIX=https://github.com/nina-fm/nina.fm-mixtaper/issues
API=https://github.com/nina-fm/nina.fm-api/issues

cat >"$work/items.json" <<EOF
{"items":[
  {"status":"Todo","horizon":"Maintenant","content":{"repository":"nina-fm/nina.fm-mixtaper","number":38,"title":"Bug local","url":"$MIX/38"}},
  {"status":"In Progress","horizon":"Maintenant","labels":["epic"],"content":{"repository":"nina-fm/nina.fm-mixtaper","number":46,"title":"Epic locale","url":"$MIX/46"}},
  {"status":"Todo","horizon":"Maintenant","content":{"repository":"nina-fm/nina.fm-api","number":56,"title":"Contrat API","url":"$API/56"}},
  {"status":"Done","horizon":"Maintenant","content":{"repository":"nina-fm/nina.fm-mixtaper","number":1,"title":"Terminée","url":"$MIX/1"}},
  {"status":"Todo","horizon":"Ensuite","content":{"repository":"nina-fm/nina.fm-mixtaper","number":39,"title":"Suite","url":"$MIX/39"}},
  {"status":"Todo","horizon":"Ensuite","content":{"type":"DraftIssue","title":"Idée en vrac","body":""}},
  {"status":"Todo","horizon":"Plus tard","content":{"repository":"nina-fm/nina.fm-mixtaper","number":40,"title":"Plus tard","url":"$MIX/40"}},
  {"status":"Todo","horizon":"Au fil de l'eau","content":{"repository":"nina-fm/nina.fm-mixtaper","number":41,"title":"Fil","url":"$MIX/41"}},
  {"status":"Todo","content":{"repository":"nina-fm/nina.fm-mixtaper","number":42,"title":"Oubliée","url":"$MIX/42"}}
]}
EOF

# Sous-issues de l'epic #46, sur deux pages : deux ouvertes, dont une dans l'API,
# et une fermée — la seconde page n'est lue que si l'appel pagine
cat >"$work/api/repos_nina-fm_nina.fm-mixtaper_issues_46_sub_issues" <<EOF
[[{"html_url":"$MIX/38","state":"open"},{"html_url":"$MIX/37","state":"closed"}],
 [{"html_url":"$API/56","state":"open"}]]
EOF

# resource <issue> <epic ou ""> <Projects de l'epic> [Projects de l'issue] : ce que la
# requête de resolve_project rend. Numéros séparés par des espaces, suffixés de « a »
# pour un item archivé, de « f » pour un Project fermé, de « x » pour un autre owner
resource() {
  local nodes='def nodes: [splits(" ") | select(. != "") | {isArchived: test("a"),
    project: {number: (sub("[afx]+$"; "") | tonumber), closed: test("f"), owner: {login: (if test("x") then "autre" else "nina-fm" end)}}}];'
  jq -nc --arg epic "$2" --arg ep "$3" --arg ip "${4:-}" "$nodes"'
    [{data: {repository: {issue: {projectItems: {nodes: ($ip | nodes)},
      parent: (if $epic == "" then null else {url: $epic, projectItems: {nodes: ($ep | nodes)}} end)}}}}]' \
    >"$work/api/resource_$(tr / _ <<<"${1#https://github.com/}")"
}

# items <ligne>… : un item-list fait de ces items, rangés en Maintenant et ouverts
items() {
  local IFS=,
  echo "{\"items\":[$*]}" >"$work/items-signal.json"
}
issue() { echo "{\"status\":\"Todo\",\"horizon\":\"Maintenant\",\"content\":{\"repository\":\"nina-fm/nina.fm-mixtaper\",\"number\":$1,\"title\":\"T$1\",\"url\":\"$MIX/$1\"}}"; }
epic() { echo "{\"status\":\"Todo\",\"horizon\":\"Maintenant\",\"labels\":[\"epic\"],\"content\":{\"repository\":\"nina-fm/nina.fm-mixtaper\",\"number\":$1,\"title\":\"E$1\",\"url\":\"$MIX/$1\"}}"; }
api_issue() { echo "{\"status\":\"Todo\",\"horizon\":\"Maintenant\",\"content\":{\"repository\":\"nina-fm/nina.fm-api\",\"number\":$1,\"title\":\"A$1\",\"url\":\"$API/$1\"}}"; }

git -C "$work/repo" init -q
git -C "$work/repo" remote add origin git@github.com:nina-fm/nina.fm-mixtaper.git

export PATH="$work/bin:$PATH" GH_CALLS="$work/calls" GH_ITEMS="$work/items.json" GH_API="$work/api"

# run <args…> : exécute plan.sh depuis le faux repo, remplit $out, $err et $code
run() {
  : >"$GH_CALLS"
  out=$(cd "$work/repo" && bash "$script" "$@" 2>"$work/err")
  code=$?
  err=$(cat "$work/err")
}

# signal : la ligne « Signal » de l'affichage, vide s'il n'y en a pas
signal() {
  GH_ITEMS="$work/items-signal.json" run
  sig=$(grep '^Signal' <<<"$out")
}

# --- Affichage

unset NINA_PROJECT
run
[[ $code -eq 0 && -z "$out" && ! -s "$GH_CALLS" ]] || fail "sans NINA_PROJECT : attendu muet en code 0 sans appel à gh, obtenu code $code, sortie « $out »"

export NINA_PROJECT=1
GH_FAIL=1 run
[[ $code -eq 0 && -z "$out" && -z "$err" ]] || fail "gh en échec : attendu muet en code 0, obtenu code $code, sortie « $out », erreur « $err »"

run
expected="Plan Mixtaper — https://github.com/orgs/nina-fm/projects/1
Maintenant :
  - #46 [epic] Epic locale (en cours)
  - #38 Bug local
  - api#56 Contrat API
Ensuite :
  - #39 Suite
  - [brouillon] Idée en vrac
Plus tard : 1 · Différé : 0 · Au fil de l'eau : 1
Sans horizon : 1 — à ranger"
[[ $code -eq 0 && "$out" == "$expected" ]] || fail "affichage : attendu
$expected
obtenu (code $code)
$out"
grep -q -- "project item-list 1 --owner nina-fm" "$GH_CALLS" || fail "affichage : le Project de NINA_PROJECT n'est pas celui interrogé"

# --- Signal

items "$(issue 39 | sed 's/Maintenant/Ensuite/')"
signal
[[ $sig == "Signal : Maintenant est vide"* ]] || fail "signal vide : attendu « Maintenant est vide », obtenu « $sig »"
grep -q -- "^api " "$GH_CALLS" && fail "signal vide : aucune epic, les sous-issues n'ont pas à être lues"

items "$(epic 46)" "$(epic 47)"
signal
[[ $sig == "Signal : Maintenant déborde, 2 epics"* ]] || fail "signal 2 epics : attendu un débordement, obtenu « $sig »"

items "$(issue 1)" "$(issue 2)" "$(issue 3)"
signal
[[ -z $sig ]] || fail "signal 3 issues : attendu aucun signal, obtenu « $sig »"

items "$(issue 1)" "$(issue 2)" "$(issue 3)" "$(issue 4)"
signal
[[ $sig == "Signal : Maintenant déborde, 4 issues isolées"* ]] || fail "signal 4 issues : attendu un débordement, obtenu « $sig »"

items "$(epic 46)" "$(issue 38)" "$(issue 1)" "$(issue 2)" "$(issue 3)"
signal
[[ -z $sig ]] || fail "signal sous-issues : #38 appartient à l'epic, 3 isolées ne débordent pas, obtenu « $sig »"

items "$(epic 46)" "$(issue 38)" "$(api_issue 56)" "$(issue 1)" "$(issue 2)" "$(issue 3)"
signal
[[ -z $sig ]] || fail "signal sous-issue en seconde page : api#56 appartient à l'epic, 3 isolées ne débordent pas, obtenu « $sig »"

items "$(epic 46)" "$(issue 38)" "$(issue 1)" "$(issue 2)" "$(issue 3)" "$(issue 4)"
signal
[[ $sig == "Signal : Maintenant déborde, 4 issues isolées"* ]] || fail "signal epic + 4 isolées : attendu un débordement, obtenu « $sig »"

items "$(epic 47)" "$(issue 1)" "$(issue 2)" "$(issue 3)" "$(issue 4)"
signal
[[ $code -eq 0 && -z $sig && -z $err ]] || fail "signal sous-issues illisibles : attendu aucun signal ni erreur, obtenu code $code, « $sig », erreur « $err »"

# --- list : deux pages (--slurp), tri par Horizon puis ancienneté, sans Done ni Au fil de l'eau

node() { echo "{\"horizon\":{\"name\":\"$1\"},\"status\":{\"name\":\"$2\"},\"content\":{\"url\":\"$3\",\"title\":\"$4\",\"state\":\"$5\",\"updatedAt\":\"$6T10:00:00Z\",\"parent\":$7,\"subIssuesSummary\":{\"total\":$8,\"completed\":$9},\"labels\":{\"nodes\":[${10}]}}}"; }
page() { echo "{\"data\":{\"organization\":{\"projectV2\":{\"items\":{\"nodes\":[$1]}}}}}"; }
cat >"$work/api/graphql" <<EOF
[$(page "$(node Ensuite Todo "$MIX/39" Suite OPEN 2026-09-11 null 0 0 '')","$(node Maintenant "In Progress" "$MIX/38" "Bug local" OPEN 2026-09-12 "{\"url\":\"$MIX/46\"}" 0 0 '')"),
 $(page "$(node Maintenant Todo "$MIX/46" "Epic locale" OPEN 2026-09-15 null 5 2 '{"name":"epic"}')","$(node Maintenant Done "$MIX/1" Fermée CLOSED 2026-09-01 null 0 0 '')","$(node "Au fil de l'eau" Todo "$API/9" Fil OPEN 2026-09-01 null 0 0 '')")]
EOF
export NINA_PROJECT=1
run list
expected="Maintenant · #38 · 2026-09-12 · sous-issue de #46 · en cours · Bug local
Maintenant · #46 · 2026-09-15 · epic 2/5 · Epic locale
Ensuite · #39 · 2026-09-11 · Suite"
[[ $code -eq 0 && "$out" == "$expected" ]] || fail "list : attendu
$expected
obtenu (code $code, erreur « $err »)
$out"
grep -q -- "--paginate --slurp -F n=1" "$GH_CALLS" || fail "list : le Project de NINA_PROJECT n'est pas celui interrogé, ou sans pagination"

# --- Refus

unset NINA_PROJECT
for cmd in "add $MIX/70 Maintenant" "start $MIX/70" "move $MIX/70 Ensuite"; do
  run $cmd
  grep -q "^project" "$GH_CALLS" && fail "${cmd%% *} sans NINA_PROJECT : aucun Project ne doit être touché"
  [[ $code -eq 2 && "$err" == *NINA_PROJECT* ]] || fail "${cmd%% *} sans NINA_PROJECT : attendu un refus qui nomme NINA_PROJECT, obtenu code $code, erreur « $err »"
done

export NINA_PROJECT=2
run start 70
[[ $code -eq 2 && "$err" == "URL d'issue attendue"* && ! -s "$GH_CALLS" ]] || fail "start sans URL : attendu un refus, obtenu code $code, erreur « $err »"
run move "$MIX/70"
[[ $code -eq 2 && "$err" == "usage : plan.sh move"* ]] || fail "move sans Horizon : attendu l'usage, obtenu code $code, erreur « $err »"

# --- add

run add "$MIX/70" Jamais
[[ $code -eq 1 && "$err" == *"attendu : Maintenant, Ensuite"* ]] || fail "add horizon inconnu : attendu code 1 et la liste des horizons, obtenu code $code, erreur « $err »"
grep -q -- "item-add" "$GH_CALLS" && fail "add horizon inconnu : l'issue a été ajoutée au Project malgré le refus"

run add "$MIX/70" Ensuite
[[ $code -eq 0 && "$out" == "$MIX/70 → Ensuite (Project 2 Apps Workspace)" ]] || fail "add : attendu code 0 et le Project visé nommé, obtenu code $code, sortie « $out », erreur « $err »"
grep -q -- "project item-add 2 --owner nina-fm --url $MIX/70" "$GH_CALLS" || fail "add : l'issue n'est pas ajoutée au Project 2"
grep -q -- "--project-id PVT_2 --id ITEM_nina.fm-mixtaper_70 --field-id F_status --single-select-option-id O_todo" "$GH_CALLS" || fail "add : Status Todo non posé"
grep -q -- "--project-id PVT_2 --id ITEM_nina.fm-mixtaper_70 --field-id F_horizon --single-select-option-id O_next" "$GH_CALLS" || fail "add : Horizon Ensuite non posé"

# --- move

run move "$MIX/70" "Plus tard"
[[ $code -eq 0 && "$out" == "$MIX/70 → Plus tard (Project 2 Apps Workspace)" ]] || fail "move : attendu une ligne, obtenu code $code, sortie « $out », erreur « $err »"
grep -q -- "--id ITEM_nina.fm-mixtaper_70 --field-id F_horizon --single-select-option-id O_later" "$GH_CALLS" || fail "move : Horizon Plus tard non posé"
grep -q -- "F_status" "$GH_CALLS" && fail "move : le Status ne doit pas bouger"

run move "$MIX/70" Jamais
[[ $code -eq 1 && "$err" == *"attendu : Maintenant, Ensuite, Plus tard"* ]] || fail "move horizon inconnu : attendu code 1 et la liste des horizons, obtenu code $code, erreur « $err »"

run move "$MIX/46" Ensuite
[[ $code -eq 0 ]] || fail "move epic : attendu code 0, obtenu $code, erreur « $err »"
for item in nina.fm-mixtaper_46 nina.fm-mixtaper_38 nina.fm-api_56; do
  grep -q -- "--id ITEM_$item --field-id F_horizon --single-select-option-id O_next" "$GH_CALLS" || fail "move epic : ITEM_$item non passé en Ensuite"
done
grep -q -- "ITEM_nina.fm-mixtaper_37" "$GH_CALLS" && fail "move epic : une sous-issue fermée ne bouge pas"

# --- start

run start "$MIX/70"
[[ $code -eq 0 && "$out" == "$MIX/70 → In Progress, Maintenant (Project 2 Apps Workspace)" ]] || fail "start sans epic : attendu une ligne, obtenu code $code, sortie « $out », erreur « $err »"
grep -q -- "--id ITEM_nina.fm-mixtaper_70 --field-id F_status --single-select-option-id O_progress" "$GH_CALLS" || fail "start : Status In Progress non posé"
grep -q -- "--id ITEM_nina.fm-mixtaper_70 --field-id F_horizon --single-select-option-id O_now" "$GH_CALLS" || fail "start : Horizon Maintenant non posé"

run start "$MIX/99999"
[[ $code -eq 1 && "$err" == *"Could not resolve to an Issue"* ]] || fail "pas une issue (PR ou introuvable) : attendu l'erreur de gh, obtenu code $code, erreur « $err »"
grep -q -- "^project" "$GH_CALLS" && fail "pas une issue : aucun Project ne doit être touché"
grep -q -- "-f owner=nina-fm -f repo=nina.fm-mixtaper -F n=99999" "$GH_CALLS" || fail "requête : l'issue n'est pas lue par owner, repo et numéro"

# --- Issue sans epic déjà rangée : son Project, pas celui de la session (#68)

resource "$MIX/46" "" "" "1"
run move "$MIX/46" Ensuite
[[ $code -eq 0 && "$out" == "$MIX/46 → Ensuite (Project 1 Mixtaper)"* ]] || fail "move epic rangée ailleurs : attendu son Project 1, obtenu code $code, sortie « $out », erreur « $err »"
grep -q -- "item-add 2" "$GH_CALLS" && fail "move epic rangée ailleurs : ni l'epic ni ses sous-issues n'entrent dans le Project 2 de la session"
grep -q -- "project item-add 1 --owner nina-fm --url $API/56" "$GH_CALLS" || fail "move epic rangée ailleurs : la sous-issue api#56 ne suit pas dans le Project 1"
grep -q -- "isArchived project { number closed" "$GH_CALLS" || fail "requête : l'archivage des items et la fermeture des Projects ne sont pas lus"

resource "$MIX/46" "" "" "1 3"
run move "$MIX/46" Ensuite
[[ $code -eq 1 && "$err" == "$MIX/46 rangée dans plusieurs Projects (1 3)"* ]] || fail "issue dans deux Projects : attendu un refus qui les nomme, obtenu code $code, erreur « $err »"

resource "$MIX/46" "" "" "1 2a 3f 4x"
run move "$MIX/46" Ensuite
[[ $code -eq 0 && "$out" == "$MIX/46 → Ensuite (Project 1 Mixtaper)"* ]] || fail "issue rangée en 1, archivée en 2, en Project fermé 3 et chez un autre owner : attendu le Project 1, obtenu code $code, sortie « $out », erreur « $err »"
rm "$work/api/resource_nina-fm_nina.fm-mixtaper_issues_46"

# --- Sous-issue : le Project de son epic, quel que soit celui de la session (#68)

resource "$MIX/38" "$MIX/46" 1
run start "$MIX/38"
[[ $code -eq 0 && "$out" == "$MIX/38 → In Progress, Maintenant (Project 1 Mixtaper)"* && "$out" == *"$MIX/46 → Maintenant (Project 1 Mixtaper)"* ]] \
  || fail "start sous-issue : attendu l'issue et son epic dans le Project 1 de l'epic, obtenu code $code, sortie « $out », erreur « $err »"
for url in "$MIX/38" "$MIX/46" "$API/56"; do
  grep -q -- "project item-add 1 --owner nina-fm --url $url" "$GH_CALLS" || fail "start sous-issue : $url non rangée dans le Project 1 de l'epic"
done
grep -q -- "item-add 2" "$GH_CALLS" && fail "start sous-issue : rien ne doit entrer dans le Project 2 de la session"
grep -q -- "--project-id PVT_1 --id ITEM_nina.fm-api_56 --field-id F_horizon --single-select-option-id O_now" "$GH_CALLS" || fail "start sous-issue : la sœur api#56 non passée en Maintenant"
grep -q -- "--id ITEM_nina.fm-mixtaper_46 --field-id F_status" "$GH_CALLS" && fail "start sous-issue : le Status de l'epic ne doit pas bouger"
[[ -z "$err" ]] || fail "start sous-issue bien rangée : attendu aucun avertissement, obtenu « $err »"

run add "$MIX/38" Ensuite
[[ $code -eq 0 && "$out" == "$MIX/38 → Ensuite (Project 1 Mixtaper)" ]] || fail "add sous-issue : attendu le Project 1 de l'epic, obtenu code $code, sortie « $out », erreur « $err »"

unset NINA_PROJECT
run move "$MIX/38" Ensuite
[[ $code -eq 0 && "$out" == "$MIX/38 → Ensuite (Project 1 Mixtaper)" ]] || fail "move sous-issue sans NINA_PROJECT : attendu le Project 1 de l'epic, obtenu code $code, sortie « $out », erreur « $err »"
export NINA_PROJECT=2

resource "$MIX/38" "$MIX/46" 1 "1 2 4"
run start "$MIX/38"
[[ $code -eq 0 && "$err" == "$MIX/38 aussi rangée hors du Project de son epic, à en retirer : 2 4" ]] \
  || fail "start sous-issue mal rangée : attendu un avertissement qui nomme les Projects 2 et 4, obtenu code $code, erreur « $err »"
grep -q -- "item-delete" "$GH_CALLS" && fail "start sous-issue mal rangée : rien ne se retire tout seul"

resource "$MIX/38" "$MIX/46" "2a 1" "1 2a"
run start "$MIX/38"
[[ $code -eq 0 && "$out" == "$MIX/38 → In Progress, Maintenant (Project 1 Mixtaper)"* && -z "$err" ]] \
  || fail "epic archivée en 2, active en 1 : attendu le Project 1 sans avertissement, obtenu code $code, sortie « $out », erreur « $err »"

resource "$MIX/38" "$MIX/46" "1a"
run start "$MIX/38"
[[ $code -eq 0 && "$out" == "$MIX/38 → In Progress, Maintenant (Project 1 Mixtaper)"* ]] \
  || fail "epic fermée, archivée dans le seul Project 1 : attendu le Project 1, obtenu code $code, sortie « $out », erreur « $err »"

resource "$MIX/38" "$MIX/46" ""
run start "$MIX/38"
[[ $code -eq 1 && "$err" == "epic $MIX/46 rangée dans aucun Project"* ]] || fail "epic sans Project : attendu un refus qui nomme l'epic, obtenu code $code, erreur « $err »"
grep -q -- "^project" "$GH_CALLS" && fail "epic sans Project : aucun Project ne doit être touché"

resource "$MIX/38" "$MIX/46" "1 3"
run start "$MIX/38"
[[ $code -eq 1 && "$err" == "epic $MIX/46 rangée dans plusieurs Projects (1 3)"* ]] || fail "epic dans deux Projects : attendu un refus qui les nomme, obtenu code $code, erreur « $err »"
grep -q -- "^project" "$GH_CALLS" && fail "epic dans deux Projects : aucun Project ne doit être touché"

if [[ $failures -gt 0 ]]; then
  echo "$failures cas en échec"
  exit 1
fi
echo "Tous les cas passent"
