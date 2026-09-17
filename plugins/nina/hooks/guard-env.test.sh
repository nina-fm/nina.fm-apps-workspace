#!/usr/bin/env bash
# Test de non-régression de guard-env.sh : bash plugins/nina/hooks/guard-env.test.sh

script="$(dirname "$0")/guard-env.sh"
failures=0

# expect <allow|deny> <entrée JSON>
expect() {
  local expected=$1 input=$2 output code actual
  output=$(printf '%s' "$input" | bash "$script")
  code=$?
  if [[ "$output" == *'"permissionDecision":"deny"'* ]]; then actual=deny; elif [[ -z "$output" ]]; then actual=allow; else actual="sortie inattendue"; fi
  if [[ $code -ne 0 || "$actual" != "$expected" ]]; then
    echo "ÉCHEC $input : attendu $expected en code 0, obtenu $actual en code $code"
    failures=$((failures + 1))
  fi
}

expect allow '{"tool_name":"Read","tool_input":{"file_path":"/x/foo.ts"}}'
expect allow '{"tool_name":"Read","tool_input":{"file_path":"/x/.env.example"}}'
expect allow '{"tool_name":"Read","tool_input":{"file_path":"/x/.envrc.md/notes.ts"}}'
expect deny '{"tool_name":"Read","tool_input":{"file_path":"/x/.env"}}'
expect deny '{"tool_name":"Read","tool_input":{"file_path":"/x/.env.local"}}'
expect deny '{"tool_name":"Read","tool_input":{"file_path":".env.production"}}'

expect allow '{"tool_name":"Glob","tool_input":{"pattern":"src/**/*.ts"}}'
expect allow '{"tool_name":"Glob","tool_input":{"pattern":"**/.env.example"}}'
expect deny '{"tool_name":"Glob","tool_input":{"pattern":"**/.env*"}}'
expect deny '{"tool_name":"Glob","tool_input":{"pattern":".env"}}'
expect deny '{"tool_name":"Glob","tool_input":{"pattern":"nina.fm-api/.env.local"}}'

expect allow '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
expect allow '{}'

if [[ $failures -gt 0 ]]; then
  echo "$failures cas en échec"
  exit 1
fi
echo "Tous les cas passent"
