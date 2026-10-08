#!/usr/bin/env bash
# Où partent les tokens des sessions Nina, lus dans leurs transcripts, pour
# /nina:harnais.
#
#   harnais-conso.sh [jours] [racine]   défaut : 14 jours, racine du dépôt courant
#
# Les transcripts sont dans ~/.claude/projects/<chemin encodé>/ : une session par
# `<id>.jsonl`, ses sous-agents dans `<id>/subagents/`. Sont lus ceux des dossiers
# dont le nom contient « nina », modifiés depuis moins de `jours`.
#
# Une requête peut s'étaler sur plusieurs messages assistant au même `requestId`,
# chacun portant le même `usage` : elle n'est comptée qu'une fois. Son contexte est
# la somme des tokens d'entrée, lus en cache et écrits en cache ; c'est la relecture
# de ce contexte à chaque requête qui fait l'essentiel de la consommation (95 % sur
# les 14 jours mesurés pour #79).
#
# Les agents définis sous la racine (`plugins/*/agents/`, `**/.claude/agents/`) et
# jamais appelés dans la période sont listés : leur description est relue à chaque
# requête de chaque session, pour rien.
set -euo pipefail

days=${1:-14}
root=${2:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
projects=${HARNAIS_PROJECTS:-$HOME/.claude/projects}
[ -d "$projects" ] || { echo "harnais-conso.sh : $projects introuvable" >&2; exit 2; }

events=$(mktemp)
trap 'rm -f "$events"' EXIT

# Une ligne TSV par fait : R (requête), T (sortie d'outil), C (commande /x),
# A (agent appelé), S (début de session : contexte de la 1re requête et maximum)
extract() {
  jq -rs --arg kind "$2" '
    [.[] | select(.type == "assistant")] as $as
    | ($as | unique_by(.message.id // .requestId)
        | map(.message.usage as $u | {
            ctx: (($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0)),
            lu: ($u.cache_read_input_tokens // 0), cree: ($u.cache_creation_input_tokens // 0),
            gen: ($u.output_tokens // 0), model: (.message.model // "?"), t: .timestamp })
        | map(select(.model != "<synthetic>")) | sort_by(.t)) as $req
    | ([$as[].message.content[]? | select(.type == "tool_use") | {key: .id, value: {n: .name, i: .input}}] | from_entries) as $tools
    | ($req[] | ["R", $kind, .model, .lu, .cree, .gen] | @tsv),
      (if ($req | length) > 0 then ["S", $kind, $req[0].ctx, ($req | map(.ctx) | max)] | @tsv else empty end),
      (.[] | select(.type == "user") | .message.content
        | if type == "array" then .[] else {type: "text", text: .} end
        | if .type == "tool_result" then
            ($tools[.tool_use_id] // {n: "?", i: {}}) as $t
            | (if (.content | type) == "string" then (.content | length) else (.content | tojson | length) end) as $len
            | ["T", $t.n, $len, (if $t.n == "Bash" then ($t.i.command // "" | sub("^\\s*cd\\s+[^&;]+(&&|;)\\s*"; "") | split(" ") | map(select(. != "" and . != "rtk" and . != "proxy")) | .[0] // "?") else "" end)] | @tsv
          elif .type == "text" then
            (.text // "" | [scan("<command-name>/?([^<]+)</command-name>")[0]] | .[] | ["C", .] | @tsv)
          else empty end),
      ($as[].message.content[]? | select(.type == "tool_use" and (.name == "Agent" or .name == "Task"))
        | ["A", (.input.subagent_type // "general-purpose")] | @tsv)
  ' "$1" 2>/dev/null || true
}

n=0
while IFS= read -r -d '' f; do
  case "$f" in */subagents/*) kind=sub ;; *) kind=main ;; esac
  extract "$f" "$kind" >>"$events"
  n=$((n + 1))
done < <(find "$projects" -maxdepth 4 -path '*nina*' -name '*.jsonl' -mtime "-$days" -print0 2>/dev/null)
[ "$n" -gt 0 ] || { echo "Aucun transcript Nina depuis $days jours dans $projects"; exit 0; }

# Les agents définis sous la racine, par nom
defined=$(find "$root" \( -path '*/plugins/*/agents/*.md' -o -path '*/.claude/agents/*.md' \) -not -path '*/node_modules/*' 2>/dev/null \
  | while IFS= read -r a; do awk 'NR > 1 && /^---$/ { exit } /^name:/ { sub(/^name:[ ]*/, ""); print }' "$a"; done | sort -u | paste -sd " " -)

awk -F '\t' -v days="$days" -v defined="$defined" '
  function med(a, k,   i, j, t) { for (i = 2; i <= k; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } return k ? a[int((k + 1) / 2)] : 0 }
  function fmt(x,   s) { s = sprintf("%d", x); while (s ~ /[0-9]{4}/) sub(/[0-9][0-9][0-9]($| )/, " &", s); return s }
  function top(title, arr, cnt, hascnt, lim,   k, i, j, keys, m, t) {
    print "\n" title; m = 0
    for (k in arr) keys[++m] = k
    for (i = 2; i <= m; i++) { t = keys[i]; for (j = i - 1; j >= 1 && arr[keys[j]] < arr[t]; j--) keys[j + 1] = keys[j]; keys[j + 1] = t }
    for (i = 1; i <= m && i <= lim; i++) printf "  %14s  %6s  %s\n", fmt(arr[keys[i]]), (hascnt ? cnt[keys[i]] : ""), keys[i]
  }
  $1 == "R" { req[$2]++; lu[$2] += $4; cree[$2] += $5; gen[$2] += $6; mod[$3]++ }
  $1 == "S" && $2 == "main" { s++; d[s] = $3; mx[s] = $4 }
  $1 == "S" && $2 == "sub" { subs++ }
  $1 == "T" { out[$2] += $3; nout[$2]++; if ($2 == "Bash") bash[$4] += $3 }
  $1 == "C" { cmd[$2]++ }
  $1 == "A" { ag[$2]++; sub(/^[^:]*:/, "", $2); called[$2] = 1 }
  END {
    printf "Sessions Nina des %d derniers jours : %d, et %d sous-agents\n", days, s, subs
    printf "Contexte à la 1re requête (médiane) : %s tokens ; maximum atteint (médiane) : %s\n", fmt(med(d, s)), fmt(med(mx, s))
    printf "\n%-12s %9s %15s %13s %11s\n", "", "requêtes", "relus (cache)", "écrits", "générés"
    for (k in req) printf "%-12s %9s %15s %13s %11s\n", (k == "main" ? "principale" : "sous-agents"), fmt(req[k]), fmt(lu[k]), fmt(cree[k]), fmt(gen[k])
    printf "\nRequêtes par modèle :"; for (k in mod) printf "  %s %d", k, mod[k]; print ""
    top("Sorties d\047outils (caractères, nombre)", out, nout, 1, 10)
    top("Bash, par commande (caractères)", bash, none, 0, 10)
    top("Commandes lancées", cmd, none, 0, 15)
    top("Agents appelés", ag, none, 0, 10)
    nd = split(defined, def, " "); line = ""
    for (i = 1; i <= nd; i++) if (def[i] != "" && !(def[i] in called)) line = line "  " def[i]
    print "\nAgents définis jamais appelés :" (line == "" ? "  aucun" : line)
  }
' "$events"
