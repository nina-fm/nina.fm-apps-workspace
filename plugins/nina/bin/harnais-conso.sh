#!/usr/bin/env bash
# Où partent les tokens des sessions Nina, lus dans leurs transcripts, pour
# /nina:harnais.
#
#   harnais-conso.sh [jours] [racine]   défaut : 14 jours, racine du dépôt courant
#
# Les transcripts sont dans ~/.claude/projects/<chemin encodé>/ : une session par
# `<id>.jsonl`, ses sous-agents dans `<id>/subagents/`. Sont lus ceux de la racine
# et des dossiers qu'elle contient (depuis le workspace : les cinq repos), pas ceux
# d'un autre workspace ni des sessions `claude -p` lancées dans un scratchpad.
#
# Ce que la mesure corrige (relecture de #80) :
# - une requête s'étale sur plusieurs lignes au même `message.id`, dont la
#   dernière seule porte les tokens générés complets : on garde le maximum ;
# - une session reprise recopie l'historique de la précédente : requêtes, sorties
#   d'outils et commandes sont dédoublonnées sur l'ensemble des fichiers ;
# - la période porte sur l'horodatage de chaque requête, pas sur le fichier ;
# - une ligne JSONL tronquée (session en cours d'écriture) est sautée, pas le
#   fichier entier ;
# - une capture d'écran se compte en images, pas en caractères base64.
#
# Le contexte d'une requête est la somme des tokens d'entrée, lus en cache et
# écrits en cache. Sa relecture à chaque requête fait l'essentiel des tokens ;
# la ligne « pondéré » la ramène aux tarifs de l'API pour juger de son poids réel.
set -euo pipefail

command -v jq >/dev/null || { echo "harnais-conso.sh : jq est requis" >&2; exit 2; }
days=${1:-14}
root=$(cd "${2:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" && pwd -P)
projects=${HARNAIS_PROJECTS:-$HOME/.claude/projects}
[ -d "$projects" ] || { echo "harnais-conso.sh : $projects introuvable" >&2; exit 2; }
since=$(date -u -v-"${days}"d +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -d "$days days ago" +%Y-%m-%dT%H:%M:%S)
enc=$(printf '%s' "$root" | sed 's/[^A-Za-z0-9]/-/g')

events=$(mktemp)
trap 'rm -f "$events"' EXIT

# Une ligne TSV par fait, avec l'identifiant qui sert au dédoublonnage :
# R (requête), T (sortie d'outil), C (commande /x), A (agent appelé)
# shellcheck disable=SC2094 # `--arg file` passe un nom, rien n'écrit dans le fichier lu
extract() {
  jq -Rrn --arg kind "$2" --arg file "$1" --arg since "$since" '
    [inputs | fromjson? | select(type == "object")] as $all
    | [$all[] | select(.type == "assistant" and (.timestamp // "") >= $since)] as $as
    | ($as | group_by(.message.id // .requestId)
        | map(max_by(.message.usage.output_tokens // 0) as $m | $m.message.usage as $u | {
            id: ($m.message.id // $m.requestId), model: ($m.message.model // "?"), t: $m.timestamp,
            ctx: (($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0)),
            lu: ($u.cache_read_input_tokens // 0), cree: ($u.cache_creation_input_tokens // 0), gen: ($u.output_tokens // 0) })
        | map(select(.model != "<synthetic>")) | sort_by(.t)) as $req
    | ([$all[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | {key: .id, value: {n: .name, i: .input}}] | from_entries) as $tools
    | ($req[] | ["R", $kind, $file, .id, .model, .ctx, .lu, .cree, .gen] | @tsv),
      ($all[] | select(.type == "user" and (.timestamp // "") >= $since) | (.uuid // "") as $uuid | .message.content
        | if type == "array" then .[] else {type: "text", text: .} end
        | if .type == "tool_result" then
            ($tools[.tool_use_id] // {n: "?", i: {}}) as $t
            | (if (.content | type) == "string" then [{type: "text", text: .content}] else (.content // []) end) as $blocks
            | ["T", .tool_use_id, $t.n,
               ($blocks | map(select(.type != "image") | if .type == "text" then (.text // "" | length) else (tojson | length) end) | add // 0),
               ($blocks | map(select(.type == "image")) | length),
               (if $t.n == "Bash" then ($t.i.command // "" | sub("^\\s*cd\\s+[^&;]+(&&|;)\\s*"; "") | split(" ") | map(select(. != "" and . != "rtk" and . != "proxy")) | .[0] // "?") else "" end)] | @tsv
          elif .type == "text" then
            (.text // "" | [scan("<command-name>/?([^<]+)</command-name>")[0]] | .[] | ["C", $uuid, .] | @tsv)
          else empty end),
      ($as[].message.content[]? | select(.type == "tool_use" and (.name == "Agent" or .name == "Task"))
        | ["A", .id, (.input.subagent_type // "general-purpose")] | @tsv)
  ' <"$1"
}

n=0
failed=0
while IFS= read -r -d '' f; do
  case "$f" in */subagents/*) kind=sub ;; *) kind=main ;; esac
  if extract "$f" "$kind" >>"$events"; then n=$((n + 1)); else failed=$((failed + 1)); echo "harnais-conso.sh : illisible : $f" >&2; fi
done < <(find "$projects" -maxdepth 4 \( -path "$projects/$enc/*" -o -path "$projects/$enc-*/*" \) -name '*.jsonl' -mtime "-$days" -print0 2>/dev/null)
[ "$n" -gt 0 ] || { echo "Aucun transcript sous $root depuis $days jours dans $projects"; exit 0; }

# Les agents définis sous la racine, et ceux qu'une commande ou une skill appelle
# par son champ `agent:` (`context: fork`) : ceux-là ne passent pas par l'outil Agent
frontmatter() { awk -v k="$1" 'NR == 1 && $0 != "---" { exit } NR > 1 && /^---$/ { exit } $0 ~ "^" k ":" { sub("^" k ":[ ]*", ""); print }' "$2"; }
defined=$(find "$root" \( -path '*/plugins/*/agents/*.md' -o -path '*/.claude/agents/*.md' \) -not -path '*/node_modules/*' 2>/dev/null \
  | while IFS= read -r a; do frontmatter name "$a"; done | sort -u | paste -sd ' ' -)
forked=$(find "$root" \( -path '*/commands/*.md' -o -path '*/skills/*/SKILL.md' \) -not -path '*/node_modules/*' 2>/dev/null \
  | while IFS= read -r a; do frontmatter agent "$a"; done | sort -u | paste -sd ' ' -)

awk -F '\t' -v days="$days" -v n="$n" -v failed="$failed" -v defined="$defined" -v forked="$forked" '
  function med(a, k,   i, j, t) { for (i = 2; i <= k; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } return k ? a[int((k + 1) / 2)] : 0 }
  function fmt(x,   s) { s = sprintf("%d", x); while (s ~ /[0-9]{4}/) sub(/[0-9][0-9][0-9]($| )/, " &", s); return s }
  function top(title, arr, cnt, hascnt, lim,   k, i, j, keys, m, t) {
    print "\n" title; m = 0
    for (k in arr) keys[++m] = k
    for (i = 2; i <= m; i++) { t = keys[i]; for (j = i - 1; j >= 1 && arr[keys[j]] < arr[t]; j--) keys[j + 1] = keys[j]; keys[j + 1] = t }
    for (i = 1; i <= m && i <= lim; i++) printf "  %14s  %6s  %s\n", fmt(arr[keys[i]]), (hascnt ? cnt[keys[i]] : ""), keys[i]
  }
  # Le contexte de chaque session se lit sur toutes ses requêtes, recopiées comprises :
  # le dédoublonnage dépendrait sinon de l ordre de lecture des fichiers
  $1 == "R" {
    if (!($3 in first)) { first[$3] = $6; fkind[$3] = $2 }
    if ($6 > mx[$3]) mx[$3] = $6
  }
  $1 == "R" && !seenR[$4]++ { req[$2]++; lu[$2] += $7; cree[$2] += $8; gen[$2] += $9; mod[$5]++ }
  $1 == "T" && !seenT[$2]++ { out[$3] += $4; nout[$3]++; if ($5 > 0) img[$3] += $5; if ($3 == "Bash") bash[$6] += $4 }
  $1 == "C" && !seenC[$2 SUBSEP $3]++ { cmd[$3]++ }
  $1 == "A" && !seenA[$2]++ { ag[$3]++; sub(/^[^:]*:/, "", $3); called[$3] = 1 }
  END {
    for (f in first) if (fkind[f] == "main") { s++; d[s] = first[f]; m2[s] = mx[f] } else subs++
    printf "Sessions des %d derniers jours : %d, et %d sous-agents (%d transcripts", days, s, subs, n
    printf (failed ? ", %d illisibles)\n" : ")\n"), failed
    printf "Contexte à la 1re requête (médiane) : %s tokens ; maximum atteint (médiane) : %s\n", fmt(med(d, s)), fmt(med(m2, s))
    printf "\n%-12s %9s %15s %13s %11s\n", "", "requêtes", "relus (cache)", "écrits", "générés"
    for (k in req) { printf "%-12s %9s %15s %13s %11s\n", (k == "main" ? "principale" : "sous-agents"), fmt(req[k]), fmt(lu[k]), fmt(cree[k]), fmt(gen[k]); L += lu[k]; C += cree[k]; G += gen[k] }
    if (L + C + G > 0) printf "Part de la relecture : %d %% des tokens ; pondéré aux tarifs API (lecture ×0,1, écriture 1 h ×2, génération ×5) : %d %%\n", 100 * L / (L + C + G), 100 * 0.1 * L / (0.1 * L + 2 * C + 5 * G)
    printf "\nRequêtes par modèle :"; for (k in mod) printf "  %s %d", k, mod[k]; print ""
    top("Sorties d\047outils, texte (caractères, nombre)", out, nout, 1, 10)
    top("Images renvoyées par outil (nombre)", img, "", 0, 5)
    top("Bash, par commande (caractères)", bash, "", 0, 10)
    top("Commandes lancées", cmd, "", 0, 15)
    top("Agents appelés par l\047outil Agent", ag, "", 0, 10)
    nf = split(forked, fk, " "); for (i = 1; i <= nf; i++) called[fk[i]] = 1
    nd = split(defined, def, " "); line = ""
    for (i = 1; i <= nd; i++) if (!(def[i] in called)) line = line "  " def[i]
    print "\nAgents définis jamais appelés (ni par l\047outil Agent, ni par le champ agent: d\047une commande) :" (line == "" ? "  aucun" : line)
  }
' "$events"
