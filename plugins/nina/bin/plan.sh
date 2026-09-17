#!/usr/bin/env bash
# Plan d'un repo Nina.fm, tenu dans le Project GitHub dont le numéro est donné par
# NINA_PROJECT (posé dans le `env` du .claude/settings.json du repo).
#
#   plan.sh                        affiche le plan en cours — c'est ce que le
#                                  hook SessionStart du plugin injecte en début de session
#   plan.sh add <url> <Horizon>    range une issue dans le Project : Status Todo,
#                                  avec son Horizon
#
# Le Project est la source de vérité. Ce script le rend visible sans rituel, et
# permet d'y ranger une issue en une commande — sans quoi on l'oublie. En
# affichage, il reste muet sans NINA_PROJECT, si gh est absent, hors ligne ou sans
# le scope `project` : une session ne doit pas échouer faute de réseau.
set -euo pipefail

OWNER=nina-fm
PROJECT=${NINA_PROJECT:-}

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
  local project items
  [ -n "$PROJECT" ] || exit 0
  project=$(gh project view "$PROJECT" --owner "$OWNER" --format json 2>/dev/null) || exit 0
  items=$(gh project item-list "$PROJECT" --owner "$OWNER" --format json --limit 200 2>/dev/null) || exit 0
  jq -r '"Plan \(.title) — \(.url)"' <<<"$project"
  jq -r --arg eau "Au fil de l'eau" --arg repo "$(current_repo)" '
    def ref: (.content.repository | sub("^nina-fm/nina\\.fm-"; "")) as $r
      | (if $r == $repo then "" else $r end) + "#" + (.content.number | tostring);
    def epic: (.labels // []) | index("epic") != null;
    def line: "  - " + ref + (if epic then " [epic]" else "" end) + " " + .content.title
      + (if .status == "In Progress" then " (en cours)" else "" end);
    [.items[] | select(.status != "Done")] as $open
    | (["Maintenant", "Ensuite"][] as $h
        | "\($h) :", ([$open[] | select(.horizon == $h)] | sort_by(epic | not) | .[] | line)),
      (["Plus tard", "Différé", $eau]
        | map(. as $h | "\($h) : \([$open[] | select(.horizon == $h)] | length)")
        | join(" · ")),
      ([$open[] | select(.horizon == null)] | length
        | if . > 0 then "Sans horizon : \(.) — à ranger" else empty end)
  ' <<<"$items"
}

add() {
  local url=$1 horizon=$2 fields pid item status_f todo horizon_f opt
  fields=$(gh project field-list "$PROJECT" --owner "$OWNER" --format json)
  opt=$(jq -r --arg h "$horizon" '.fields[] | select(.name == "Horizon") | .options[] | select(.name == $h) | .id' <<<"$fields")
  if [ -z "$opt" ]; then
    echo "Horizon inconnu : $horizon — attendu : $(jq -r '[.fields[] | select(.name == "Horizon") | .options[].name] | join(", ")' <<<"$fields")" >&2
    exit 1
  fi
  horizon_f=$(jq -r '.fields[] | select(.name == "Horizon") | .id' <<<"$fields")
  status_f=$(jq -r '.fields[] | select(.name == "Status") | .id' <<<"$fields")
  todo=$(jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "Todo") | .id' <<<"$fields")
  pid=$(gh project view "$PROJECT" --owner "$OWNER" --format json --jq .id)

  item=$(gh project item-add "$PROJECT" --owner "$OWNER" --url "$url" --format json --jq .id)
  gh project item-edit --project-id "$pid" --id "$item" --field-id "$status_f" --single-select-option-id "$todo" >/dev/null
  gh project item-edit --project-id "$pid" --id "$item" --field-id "$horizon_f" --single-select-option-id "$opt" >/dev/null
  echo "$url → $horizon"
}

case "${1:-show}" in
  show) show ;;
  add)
    [ $# -eq 3 ] || { echo "usage : plan.sh add <url de l'issue> <Horizon>" >&2; exit 2; }
    [ -n "$PROJECT" ] || { echo "NINA_PROJECT absent : poser le numéro du Project dans le env du .claude/settings.json du repo" >&2; exit 2; }
    add "$2" "$3"
    ;;
  *) echo "usage : plan.sh [show | add <url de l'issue> <Horizon>]" >&2; exit 2 ;;
esac
