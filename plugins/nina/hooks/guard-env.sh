#!/usr/bin/env bash
# Garde .env : refuse Read et Glob sur les fichiers .env*, sauf .env.example
# qui ne porte que la liste des variables attendues.
# Sort toujours en 0 : un refus passe par le JSON permissionDecision, pas par le code.

# Vrai si un nom de fichier (ou un segment de motif) désigne un fichier de secrets
is_secret_name() {
  [[ "$1" == .env* && "$1" != .env.example ]]
}

input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input")
block=false

case "$tool" in
  Read)
    file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
    is_secret_name "${file##*/}" && block=true
    ;;
  Glob)
    pattern=$(jq -r '.tool_input.pattern // empty' <<<"$input")
    IFS=/ read -ra segments <<<"$pattern"
    for segment in "${segments[@]}"; do
      is_secret_name "$segment" && block=true
    done
    ;;
esac

if [[ "$block" == true ]]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Fichiers .env bloqués par la garde du plugin nina"}}'
fi
exit 0
