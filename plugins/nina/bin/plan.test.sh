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

mkdir -p "$work/bin" "$work/repo"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_CALLS"
[ -z "${GH_FAIL:-}" ] || exit 1
case "$1 $2" in
  "project view") out='{"id":"PVT_1","title":"Mixtaper","url":"https://github.com/orgs/nina-fm/projects/1"}' ;;
  "project item-list") out=$(cat "$GH_ITEMS") ;;
  "project field-list") out='{"fields":[
    {"id":"F_status","name":"Status","options":[{"id":"O_todo","name":"Todo"},{"id":"O_done","name":"Done"}]},
    {"id":"F_horizon","name":"Horizon","options":[{"id":"O_now","name":"Maintenant"},{"id":"O_next","name":"Ensuite"}]}]}' ;;
  "project item-add") out='{"id":"ITEM_1"}' ;;
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

cat >"$work/items.json" <<'EOF'
{"items":[
  {"status":"Todo","horizon":"Maintenant","content":{"repository":"nina-fm/nina.fm-mixtaper","number":38,"title":"Bug local"}},
  {"status":"In Progress","horizon":"Maintenant","labels":["epic"],"content":{"repository":"nina-fm/nina.fm-mixtaper","number":46,"title":"Epic locale"}},
  {"status":"Todo","horizon":"Maintenant","content":{"repository":"nina-fm/nina.fm-api","number":56,"title":"Contrat API"}},
  {"status":"Done","horizon":"Maintenant","content":{"repository":"nina-fm/nina.fm-mixtaper","number":1,"title":"Terminée"}},
  {"status":"Todo","horizon":"Ensuite","content":{"repository":"nina-fm/nina.fm-mixtaper","number":39,"title":"Suite"}},
  {"status":"Todo","horizon":"Plus tard","content":{"repository":"nina-fm/nina.fm-mixtaper","number":40,"title":"Plus tard"}},
  {"status":"Todo","horizon":"Au fil de l'eau","content":{"repository":"nina-fm/nina.fm-mixtaper","number":41,"title":"Fil"}},
  {"status":"Todo","content":{"repository":"nina-fm/nina.fm-mixtaper","number":42,"title":"Oubliée"}}
]}
EOF

git -C "$work/repo" init -q
git -C "$work/repo" remote add origin git@github.com:nina-fm/nina.fm-mixtaper.git

export PATH="$work/bin:$PATH" GH_CALLS="$work/calls" GH_ITEMS="$work/items.json"

# run <args…> : exécute plan.sh depuis le faux repo, remplit $out, $err et $code
run() {
  : >"$GH_CALLS"
  out=$(cd "$work/repo" && bash "$script" "$@" 2>"$work/err")
  code=$?
  err=$(cat "$work/err")
}

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
Plus tard : 1 · Différé : 0 · Au fil de l'eau : 1
Sans horizon : 1 — à ranger"
[[ $code -eq 0 && "$out" == "$expected" ]] || fail "affichage : attendu
$expected
obtenu (code $code)
$out"
grep -q -- "project item-list 1 --owner nina-fm" "$GH_CALLS" || fail "affichage : le Project de NINA_PROJECT n'est pas celui interrogé"

unset NINA_PROJECT
run add https://github.com/nina-fm/nina.fm-mixtaper/issues/70 Maintenant
[[ $code -ne 0 && "$err" == *NINA_PROJECT* && ! -s "$GH_CALLS" ]] || fail "add sans NINA_PROJECT : attendu un refus qui nomme NINA_PROJECT, obtenu code $code, erreur « $err »"

export NINA_PROJECT=2
run add https://github.com/nina-fm/nina.fm-mixtaper/issues/70 Jamais
[[ $code -eq 1 && "$err" == *"attendu : Maintenant, Ensuite"* ]] || fail "add horizon inconnu : attendu code 1 et la liste des horizons, obtenu code $code, erreur « $err »"

run add https://github.com/nina-fm/nina.fm-mixtaper/issues/70 Ensuite
[[ $code -eq 0 ]] || fail "add : attendu code 0, obtenu $code, erreur « $err »"
grep -q -- "project item-add 2 --owner nina-fm --url https://github.com/nina-fm/nina.fm-mixtaper/issues/70" "$GH_CALLS" || fail "add : l'issue n'est pas ajoutée au Project 2"
grep -q -- "--id ITEM_1 --field-id F_status --single-select-option-id O_todo" "$GH_CALLS" || fail "add : Status Todo non posé"
grep -q -- "--id ITEM_1 --field-id F_horizon --single-select-option-id O_next" "$GH_CALLS" || fail "add : Horizon Ensuite non posé"

if [[ $failures -gt 0 ]]; then
  echo "$failures cas en échec"
  exit 1
fi
echo "Tous les cas passent"
