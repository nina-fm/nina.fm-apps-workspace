#!/usr/bin/env bash
# Test de non-régression de harnais-conso.sh : bash plugins/nina/bin/harnais-conso.test.sh
# Des transcripts de fixture au format de ~/.claude/projects, et une racine qui
# définit deux agents, dont un seul est appelé.

script="$(cd "$(dirname "$0")" && pwd)/harnais-conso.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "ÉCHEC $1"
  failures=$((failures + 1))
}

expect() {
  grep -qE -- "$2" "$work/out" || fail "$1 — attendu /$2/ dans :"$'\n'"$(cat "$work/out")"
}

p="$work/projects"
mkdir -p "$p/-x-nina-a/s1/subagents" "$p/-x-autre" "$work/root/plugins/p/agents" "$work/root/repo/.claude/agents"
printf -- '---\nname: api-explorer\n---\n' >"$work/root/plugins/p/agents/api-explorer.md"
printf -- '---\nname: jamais-appele\n---\n' >"$work/root/repo/.claude/agents/jamais.md"

usage='{"input_tokens":1,"cache_read_input_tokens":1000,"cache_creation_input_tokens":200,"output_tokens":30}'
# Une requête en deux messages (même id, même usage) : comptée une fois
cat >"$p/-x-nina-a/s1.jsonl" <<JSON
{"type":"user","message":{"content":"<command-name>/nina:review</command-name>"}}
{"type":"assistant","requestId":"r1","timestamp":"1","message":{"id":"m1","model":"opus","usage":$usage,"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"cd /x && gh api foo"}}]}}
{"type":"assistant","requestId":"r1","timestamp":"1","message":{"id":"m1","model":"opus","usage":$usage,"content":[{"type":"tool_use","id":"t2","name":"Agent","input":{"subagent_type":"nina:api-explorer"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"0123456789"},{"type":"tool_result","tool_use_id":"t2","content":[{"type":"text","text":"ok"}]}]}}
{"type":"assistant","requestId":"r2","timestamp":"2","message":{"id":"m2","model":"opus","usage":{"input_tokens":0,"cache_read_input_tokens":3000,"cache_creation_input_tokens":0,"output_tokens":5},"content":[]}}
JSON
cat >"$p/-x-nina-a/s1/subagents/a.jsonl" <<JSON
{"type":"assistant","requestId":"r9","timestamp":"1","message":{"id":"m9","model":"sonnet","usage":$usage,"content":[]}}
JSON
# Hors Nina, et une session Nina trop ancienne : ignorées
cp "$p/-x-nina-a/s1.jsonl" "$p/-x-autre/s2.jsonl"
cp "$p/-x-nina-a/s1.jsonl" "$p/-x-nina-a/vieux.jsonl"
touch -t 202001010000 "$p/-x-nina-a/vieux.jsonl"

HARNAIS_PROJECTS="$p" bash "$script" 14 "$work/root" >"$work/out"
expect "sessions et sous-agents" '^Sessions Nina des 14 derniers jours : 1, et 1 sous-agents$'
expect "contexte de départ et maximum" 'médiane\) : 1 201 tokens ; maximum atteint \(médiane\) : 3 000$'
expect "requête découpée comptée une fois" '^principale +2 +4 000 +200 +35$'
expect "sous-agents à part" '^sous-agents +1 +1 000 +200 +30$'
expect "sortie Bash attribuée à la commande après cd" '^ +10 +gh$'
expect "sortie d'outil comptée par outil" '^ +10 +1 +Bash$'
expect "commande lancée" '^ +1 +nina:review$'
expect "agent appelé" '^ +1 +nina:api-explorer$'
expect "agent jamais appelé, préfixe de plugin ignoré" '^Agents définis jamais appelés :  jamais-appele$'

HARNAIS_PROJECTS="$work/absent" bash "$script" >/dev/null 2>&1
[ $? = 2 ] || fail "dossier de transcripts absent : code attendu 2"

if [ "$failures" -gt 0 ]; then
  echo "$failures échec(s)"
  exit 1
fi
echo "harnais-conso.sh : tous les cas passent"
