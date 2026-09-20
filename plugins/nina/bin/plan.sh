#!/usr/bin/env bash
# Plan d'un repo Nina.fm, tenu dans le Project GitHub dont le numéro est donné par
# NINA_PROJECT (posé dans le `env` du .claude/settings.json du repo).
#
#   plan.sh                        affiche le plan en cours — c'est ce que le
#                                  hook SessionStart du plugin injecte en début de session.
#                                  Une ligne « Signal » dit quand Maintenant est vide
#                                  ou déborde : c'est le moment de lancer /nina:plan
#   plan.sh list                   une ligne par issue de Maintenant, Ensuite et
#                                  Plus tard : ce que /nina:plan passe en revue
#   plan.sh add <url> <Horizon>    range une issue dans le Project : Status Todo,
#                                  avec son Horizon
#   plan.sh start <url>            démarre une issue : In Progress et Maintenant ;
#                                  son epic, s'il y en a une, passe en Maintenant
#   plan.sh move <url> <Horizon>   change l'Horizon d'une issue ; sur une epic, ses
#                                  sous-issues ouvertes suivent
#
# Le Project est la source de vérité. Ce script le rend visible sans rituel, et
# permet d'y ranger une issue en une commande — sans quoi on l'oublie. En
# affichage, il reste muet sans NINA_PROJECT, si gh est absent, hors ligne ou sans
# le scope `project` : une session ne doit pas échouer faute de réseau.
set -euo pipefail

OWNER=nina-fm
PROJECT=${NINA_PROJECT:-}
# Au-delà, Maintenant n'est plus un engagement court mais une file
MAX_NOW=3

# Nom court du repo courant (mixtaper, apps-workspace…), tiré du remote : le nom
# du dossier est faux dans un worktree. Ses issues s'affichent sans préfixe.
current_repo() {
  local url
  url=$(git remote get-url origin 2>/dev/null) || return 0
  url=${url%.git}
  url=${url##*/}
  echo "${url#nina.fm-}"
}

show() {
  local project items epics subs='[]'
  [ -n "$PROJECT" ] || exit 0
  project=$(gh project view "$PROJECT" --owner "$OWNER" --format json 2>/dev/null) || exit 0
  items=$(gh project item-list "$PROJECT" --owner "$OWNER" --format json --limit 200 2>/dev/null) || exit 0
  # Les sous-issues ne sont pas dans item-list : on ne les lit que pour une epic
  # seule en Maintenant, le seul cas où elles changent le signal. Faute de réponse,
  # pas de signal de débordement plutôt qu'un faux. `--slurp` rend un tableau de
  # pages, d'où le `.[][]` ; il refuse `--jq`, d'où le filtre en aval
  epics=$(jq -r '.items[] | select(.status != "Done" and .horizon == "Maintenant"
    and ((.labels // []) | index("epic") != null)) | .content.url' <<<"$items")
  if [ -n "$epics" ] && [ "$(wc -l <<<"$epics")" -eq 1 ]; then
    subs=$(gh api "repos/${epics#https://github.com/}/sub_issues" --paginate --slurp 2>/dev/null \
      | jq -c '[.[][].html_url]' 2>/dev/null) || subs=null
  fi
  jq -r '"Plan \(.title) — \(.url)"' <<<"$project"
  jq -r --arg eau "Au fil de l'eau" --arg repo "$(current_repo)" --argjson subs "$subs" --argjson max "$MAX_NOW" '
    def ref: if .content.repository == null then "[brouillon]"
      else (.content.repository | sub("^nina-fm/nina\\.fm-"; "")) as $r
        | (if $r == $repo then "" else $r end) + "#" + (.content.number | tostring) end;
    def epic: (.labels // []) | index("epic") != null;
    def line: "  - " + ref + (if epic then " [epic]" else "" end) + " " + .content.title
      + (if .status == "In Progress" then " (en cours)" else "" end);
    [.items[] | select(.status != "Done")] as $open
    | [$open[] | select(.horizon == "Maintenant")] as $now
    | ([$now[] | select(epic)] | length) as $n_epics
    | (if $subs == null then 0
       else [$now[] | select((epic | not) and (.content.url as $u | $subs | index($u) | not))] | length
       end) as $isolated
    | (["Maintenant", "Ensuite"][] as $h
        | "\($h) :", ([$open[] | select(.horizon == $h)] | sort_by(epic | not) | .[] | line)),
      (["Plus tard", "Différé", $eau]
        | map(. as $h | "\($h) : \([$open[] | select(.horizon == $h)] | length)")
        | join(" · ")),
      ([$open[] | select(.horizon == null)] | length
        | if . > 0 then "Sans horizon : \(.) — à ranger" else empty end),
      (if ($now | length) == 0 then "Signal : Maintenant est vide — promouvoir depuis Ensuite avec /nina:plan"
       elif $n_epics > 1 then "Signal : Maintenant déborde, \($n_epics) epics — trier avec /nina:plan"
       elif $isolated > $max then "Signal : Maintenant déborde, \($isolated) issues isolées — trier avec /nina:plan"
       else empty end)
  ' <<<"$items"
}

# Une ligne par issue ouverte de Maintenant, Ensuite et Plus tard, de quoi trier sans
# ouvrir les corps : dernière mise à jour, epic et avancement de ses sous-issues,
# parent, en cours. item-list n'expose ni la date ni le parent, d'où GraphQL
list() {
  gh api graphql --paginate --slurp -F n="$PROJECT" -f owner="$OWNER" -f query='
    query($owner: String!, $n: Int!, $endCursor: String) { organization(login: $owner) { projectV2(number: $n) {
      items(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          horizon: fieldValueByName(name: "Horizon") { ... on ProjectV2ItemFieldSingleSelectValue { name } }
          status: fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } }
          content { ... on Issue { url title state updatedAt parent { url }
            subIssuesSummary { total completed } labels(first: 10) { nodes { name } } } }
    } } } } }' | jq -r --arg repo "$(current_repo)" '
    {"Maintenant": 0, "Ensuite": 1, "Plus tard": 2} as $rank
    | def ref: sub("^https://github.com/nina-fm/nina\\.fm-"; "") | sub("/issues/"; "#")
        | if startswith($repo + "#") then ltrimstr($repo) else . end;
    [.[].data.organization.projectV2.items.nodes[]
      | select(.content.state == "OPEN" and $rank[.horizon.name // ""] != null)]
    | sort_by($rank[.horizon.name], .content.updatedAt)[]
    | [.horizon.name, (.content.url | ref), .content.updatedAt[:10],
       (if any(.content.labels.nodes[]; .name == "epic")
        then "epic \(.content.subIssuesSummary.completed)/\(.content.subIssuesSummary.total)" else empty end),
       (if .content.parent then "sous-issue de " + (.content.parent.url | ref) else empty end),
       (if .status.name == "In Progress" then "en cours" else empty end),
       .content.title]
    | join(" · ")'
}

# Champs et identifiant du Project, lus une fois par commande
load_project() {
  local project
  FIELDS=$(gh project field-list "$PROJECT" --owner "$OWNER" --format json)
  project=$(gh project view "$PROJECT" --owner "$OWNER" --format json)
  PID=$(jq -r .id <<<"$project")
  TITLE=$(jq -r .title <<<"$project")
}

# option_id <champ> <option> : id de l'option, ou refus qui liste les options connues
option_id() {
  local id
  id=$(jq -r --arg f "$1" --arg o "$2" '.fields[] | select(.name == $f) | .options[] | select(.name == $o) | .id' <<<"$FIELDS")
  if [ -z "$id" ]; then
    echo "$1 inconnu : $2 — attendu : $(jq -r --arg f "$1" '[.fields[] | select(.name == $f) | .options[].name] | join(", ")' <<<"$FIELDS")" >&2
    exit 1
  fi
  echo "$id"
}

# L'item de l'issue dans le Project : item-add rend l'item existant s'il y est déjà
item_of() {
  gh project item-add "$PROJECT" --owner "$OWNER" --url "$1" --format json --jq .id
}

# set_field <item> <champ> <option>
set_field() {
  local field opt
  field=$(jq -r --arg f "$2" '.fields[] | select(.name == $f) | .id' <<<"$FIELDS")
  opt=$(option_id "$2" "$3")
  gh project item-edit --project-id "$PID" --id "$1" --field-id "$field" --single-select-option-id "$opt" >/dev/null
}

# Le Project visé est nommé : NINA_PROJECT vaut pour toute commande de la session,
# y compris dans un sous-repo du workspace
add() {
  local url=$1 horizon=$2 item
  option_id Horizon "$horizon" >/dev/null
  item=$(item_of "$url")
  set_field "$item" Status Todo
  set_field "$item" Horizon "$horizon"
  echo "$url → $horizon (Project $PROJECT $TITLE)"
}

move() {
  local url=$1 horizon=$2 item subs sub
  option_id Horizon "$horizon" >/dev/null
  item=$(item_of "$url")
  set_field "$item" Horizon "$horizon"
  echo "$url → $horizon (Project $PROJECT $TITLE)"
  # Les sous-issues suivent l'Horizon de leur epic, toutes pages lues. En échec, gh
  # écrit le corps de l'erreur sur la sortie standard, mais sort en 1 : `pipefail`
  # fait tomber le pipe, et le corps ne passe pas pour des sous-issues
  subs=$(gh api "repos/${url#https://github.com/}/sub_issues" --paginate --slurp 2>/dev/null \
    | jq -r '.[][] | select(.state == "open") | .html_url' 2>/dev/null) || subs=""
  for sub in $subs; do
    item=$(item_of "$sub")
    set_field "$item" Horizon "$horizon"
    echo "  $sub → $horizon (sous-issue)"
  done
}

start() {
  local url=$1 item epic
  # Les deux options sont vérifiées avant d'ajouter l'issue : sinon un Project qui
  # nomme son Status autrement la laisserait ajoutée, sans Status ni Horizon
  option_id Status "In Progress" >/dev/null
  option_id Horizon Maintenant >/dev/null
  item=$(item_of "$url")
  set_field "$item" Status "In Progress"
  set_field "$item" Horizon Maintenant
  echo "$url → In Progress, Maintenant (Project $PROJECT $TITLE)"
  # Sans epic, l'API répond 404 et gh écrit le corps de l'erreur sur la sortie standard
  epic=$(gh api "repos/${url#https://github.com/}/parent" --jq .html_url 2>/dev/null) || return 0
  move "$epic" Maintenant
}

# Refus avant tout appel à gh : arguments, URL d'issue, NINA_PROJECT
check() {
  local n=$1 usage=$2 url=$3
  [ "$n" -eq "$(wc -w <<<"$usage")" ] || { echo "usage : plan.sh $usage" >&2; exit 2; }
  [[ $url =~ ^https://github\.com/[^/]+/[^/]+/issues/[0-9]+$ ]] || { echo "URL d'issue attendue : $url" >&2; exit 2; }
  [ -n "$PROJECT" ] || { echo "NINA_PROJECT absent : poser le numéro du Project dans le env du .claude/settings.json du repo" >&2; exit 2; }
}

case "${1:-show}" in
  show) show ;;
  list)
    [ $# -eq 1 ] || { echo "usage : plan.sh list" >&2; exit 2; }
    [ -n "$PROJECT" ] || { echo "NINA_PROJECT absent : poser le numéro du Project dans le env du .claude/settings.json du repo" >&2; exit 2; }
    list
    ;;
  add) check $# "add <url> <Horizon>" "${2:-}"; load_project; add "$2" "$3" ;;
  start) check $# "start <url>" "${2:-}"; load_project; start "$2" ;;
  move) check $# "move <url> <Horizon>" "${2:-}"; load_project; move "$2" "$3" ;;
  *) echo "usage : plan.sh [show | list | add <url> <Horizon> | start <url> | move <url> <Horizon>]" >&2; exit 2 ;;
esac
