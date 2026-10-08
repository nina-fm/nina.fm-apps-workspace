#!/usr/bin/env bash
# Test de non-régression de harnais-conso.sh : bash plugins/nina/bin/harnais-conso.test.sh
# Des transcripts de fixture au format de ~/.claude/projects : une session, sa
# reprise qui en recopie l'historique, un sous-agent, et ce qui doit être ignoré
# (autre workspace, scratchpad, requête hors période, ligne tronquée).

script="$(cd "$(dirname "$0")" && pwd)/harnais-conso.sh"
work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "ÉCHEC $1"
  failures=$((failures + 1))
}

expect() {
  grep -qE -- "$2" "$work/out" || fail "$1 — attendu /$2/ dans :"$'\n'"$(cat "$work/out")"
}

root="$work/root"
p="$work/projects"
enc=$(printf '%s' "$root" | sed 's/[^A-Za-z0-9]/-/g')
mkdir -p "$p/$enc/s1/subagents" "$p/$enc-repo" "$p/$(printf '%s' "$work/autre" | sed 's/[^A-Za-z0-9]/-/g')" "$p/-private-tmp-scratchpad" \
  "$root/plugins/p/agents" "$root/plugins/p/commands" "$root/repo/.claude/agents"
printf -- '---\nname: api-explorer\n---\n' >"$root/plugins/p/agents/api-explorer.md"
printf -- '---\nname: forke\n---\n' >"$root/plugins/p/agents/forke.md"
printf -- '---\ncontext: fork\nagent: forke\n---\n' >"$root/plugins/p/commands/x.md"
printf -- '---\nname: jamais-appele\n---\n' >"$root/repo/.claude/agents/jamais.md"

t0=$(date -u -v-1H +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S.000Z)
t1=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
u='"input_tokens":1,"cache_read_input_tokens":1000,"cache_creation_input_tokens":200'
# m1 s'étale sur deux lignes : la seconde seule porte ses 30 tokens générés
history=$(cat <<JSON
{"type":"user","uuid":"u1","timestamp":"$t0","message":{"content":"<command-name>/nina:review</command-name>"}}
{"type":"assistant","timestamp":"$t0","requestId":"r1","message":{"id":"m1","model":"opus","usage":{$u,"output_tokens":10},"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"cd /x && gh api foo"}}]}}
{"type":"assistant","timestamp":"$t0","requestId":"r1","message":{"id":"m1","model":"opus","usage":{$u,"output_tokens":30},"content":[{"type":"tool_use","id":"t2","name":"Agent","input":{"subagent_type":"nina:api-explorer"}},{"type":"tool_use","id":"t3","name":"mcp__chrome__computer","input":{}}]}}
{"type":"user","uuid":"u2","timestamp":"$t0","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"0123456789"},{"type":"tool_result","tool_use_id":"t2","content":[{"type":"text","text":"ok"}]},{"type":"tool_result","tool_use_id":"t3","content":[{"type":"image","source":{"data":"QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFB"}},{"type":"text","text":"vu"}]}]}}
{"type":"assistant","timestamp":"$t1","requestId":"r2","message":{"id":"m2","model":"opus","usage":{"input_tokens":0,"cache_read_input_tokens":3000,"cache_creation_input_tokens":0,"output_tokens":5},"content":[]}}
JSON
)
{
  printf '%s\n' "$history"
  printf '%s\n' '{"type":"assistant","timestamp":"2020-01-01T00:00:00.000Z","requestId":"r0","message":{"id":"m0","model":"opus","usage":{"cache_read_input_tokens":99999,"output_tokens":9},"content":[]}}'
  printf '%s' '{"type":"assistant","message":{"id":"tronq'
} >"$p/$enc/s1.jsonl"
# La reprise recopie l'historique, puis ajoute m3
{
  printf '%s\n' "$history"
  printf '%s\n' "{\"type\":\"assistant\",\"timestamp\":\"$t1\",\"requestId\":\"r3\",\"message\":{\"id\":\"m3\",\"model\":\"opus\",\"usage\":{\"input_tokens\":0,\"cache_read_input_tokens\":500,\"cache_creation_input_tokens\":0,\"output_tokens\":7},\"content\":[]}}"
} >"$p/$enc-repo/s2.jsonl"
printf '%s\n' "{\"type\":\"assistant\",\"timestamp\":\"$t1\",\"requestId\":\"r9\",\"message\":{\"id\":\"m9\",\"model\":\"sonnet\",\"usage\":{$u,\"output_tokens\":30},\"content\":[]}}" >"$p/$enc/s1/subagents/a.jsonl"
for d in "$p/$(printf '%s' "$work/autre" | sed 's/[^A-Za-z0-9]/-/g')" "$p/-private-tmp-scratchpad"; do
  printf '%s\n' "{\"type\":\"assistant\",\"timestamp\":\"$t1\",\"requestId\":\"rX\",\"message\":{\"id\":\"mX\",\"model\":\"opus\",\"usage\":{\"cache_read_input_tokens\":7777777,\"output_tokens\":1},\"content\":[]}}" >"$d/s.jsonl"
done

HARNAIS_PROJECTS="$p" bash "$script" 14 "$root" >"$work/out" 2>"$work/err"
code=$?
[ "$code" = 0 ] || fail "code $code, attendu 0 ; stderr : $(cat "$work/err")"
expect "sessions, sous-agents, transcripts lus ; ligne tronquée sautée" '^Sessions des 14 derniers jours : 2, et 1 sous-agents \(3 transcripts\)$'
expect "contexte de départ et maximum" 'médiane\) : 1 201 tokens ; maximum atteint \(médiane\) : 3 000$'
expect "reprise dédoublonnée, maximum des tokens générés, requête hors période exclue" '^principale +3 +4 500 +200 +42$'
expect "sous-agents à part" '^sous-agents +1 +1 000 +200 +30$'
expect "part brute et pondérée" '^Part de la relecture : 92 % des tokens ; .* : 32 %$'
expect "sortie d'outil dédoublonnée" '^ +10 +1 +Bash$'
expect "image comptée à part, pas en base64" '^ +2 +1 +mcp__chrome__computer$'
expect "nombre d'images" '^ +1 +mcp__chrome__computer$'
expect "sortie Bash attribuée à la commande après cd" '^ +10 +gh$'
expect "commande dédoublonnée" '^ +1 +nina:review$'
expect "agent appelé dédoublonné" '^ +1 +nina:api-explorer$'
expect "agent appelé par agent: d'une commande, préfixe de plugin ignoré" ':  jamais-appele$'

HARNAIS_PROJECTS="$work/absent" bash "$script" 14 "$root" >/dev/null 2>&1
[ $? = 2 ] || fail "dossier de transcripts absent : code attendu 2"

if [ "$failures" -gt 0 ]; then
  echo "$failures échec(s)"
  exit 1
fi
echo "harnais-conso.sh : tous les cas passent"
