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
# gh api <chemin> sert le fichier $GH_API/<chemin, / devenus _> ; sans fichier, un 404
# dont le corps part sur la sortie standard, comme le vrai gh.
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
  "api "*)
    file="$GH_API/$(tr / _ <<<"$2")"
    if [ ! -f "$file" ]; then echo '{"message":"Not Found","status":"404"}'; exit 1; fi
    out=$(cat "$file")
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

# Sous-issues de l'epic #46 : deux ouvertes, dont une dans l'API, et une fermée
cat >"$work/api/repos_nina-fm_nina.fm-mixtaper_issues_46_sub_issues" <<EOF
[{"html_url":"$MIX/38","state":"open"},{"html_url":"$API/56","state":"open"},{"html_url":"$MIX/37","state":"closed"}]
EOF
echo "{\"html_url\":\"$MIX/46\"}" >"$work/api/repos_nina-fm_nina.fm-mixtaper_issues_38_parent"

# items <ligne>… : un item-list fait de ces items, rangés en Maintenant et ouverts
items() {
  local IFS=,
  echo "{\"items\":[$*]}" >"$work/items-signal.json"
}
issue() { echo "{\"status\":\"Todo\",\"horizon\":\"Maintenant\",\"content\":{\"repository\":\"nina-fm/nina.fm-mixtaper\",\"number\":$1,\"title\":\"T$1\",\"url\":\"$MIX/$1\"}}"; }
epic() { echo "{\"status\":\"Todo\",\"horizon\":\"Maintenant\",\"labels\":[\"epic\"],\"content\":{\"repository\":\"nina-fm/nina.fm-mixtaper\",\"number\":$1,\"title\":\"E$1\",\"url\":\"$MIX/$1\"}}"; }

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
  [[ $code -eq 2 && "$err" == *NINA_PROJECT* && ! -s "$GH_CALLS" ]] || fail "${cmd%% *} sans NINA_PROJECT : attendu un refus qui nomme NINA_PROJECT, obtenu code $code, erreur « $err »"
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

run start "$MIX/38"
[[ $code -eq 0 && "$out" == *"$MIX/46 → Maintenant"* ]] || fail "start sous-issue : attendu l'epic nommée, obtenu code $code, sortie « $out », erreur « $err »"
for item in nina.fm-mixtaper_46 nina.fm-api_56; do
  grep -q -- "--id ITEM_$item --field-id F_horizon --single-select-option-id O_now" "$GH_CALLS" || fail "start sous-issue : ITEM_$item non passé en Maintenant"
done
grep -q -- "--id ITEM_nina.fm-mixtaper_46 --field-id F_status" "$GH_CALLS" && fail "start sous-issue : le Status de l'epic ne doit pas bouger"

if [[ $failures -gt 0 ]]; then
  echo "$failures cas en échec"
  exit 1
fi
echo "Tous les cas passent"
