#!/usr/bin/env bash
# Ce que Claude Code charge dans une session lancée depuis un dossier, mesuré pour
# /nina:harnais.
#
#   harnais.sh            depuis le dossier courant
#   harnais.sh <dossier>  depuis ce dossier (la racine d'un des cinq repos)
#
# Chargé sans condition : `~/.claude/CLAUDE.md` et ses imports `@…`, les règles de
# `~/.claude/rules/`, puis de la racine du disque jusqu'au dossier, les `CLAUDE.md`,
# `.claude/CLAUDE.md`, `CLAUDE.local.md` et règles `.claude/rules/**` de chaque
# niveau — les règles d'un dossier parent comprises : celles du workspace se
# chargent dans les cinq repos (vérifié par `claude -p` depuis website, #79). Enfin
# le `MEMORY.md` de la mémoire automatique, tronqué comme Claude Code le tronque.
#
# Une règle qui porte `paths:` ne se charge qu'à la lecture d'un fichier qui
# correspond : elle est listée à part, hors budget. Son frontmatter, retiré avant
# le chargement, n'est pas compté.
#
# Les tokens sont estimés à 3,5 caractères par token, ce que donne un texte
# français mêlé de code : l'ordre de grandeur sert à comparer, pas à facturer.
#
# Code de sortie : 0 dans le budget, 1 au-delà (HARNAIS_BUDGET, en caractères).
set -euo pipefail
export LC_ALL=en_US.UTF-8

BUDGET=${HARNAIS_BUDGET:-18000}
target=$(cd "${1:-.}" && pwd -P)
home=$(cd ~ && pwd -P)
seen=" "
always=0
scoped=""

# chars <fichier> : caractères chargés, frontmatter exclu
chars() {
  if [ "$(head -n 1 "$1")" = "---" ]; then
    awk 'NR == 1 { next } !done && /^---$/ { done = 1; next } done' "$1" | wc -m | tr -d ' '
  else
    wc -m <"$1" | tr -d ' '
  fi
}

# Le motif `paths:` d'une règle, sur une ligne ; vide si elle n'en a pas
paths_of() {
  [ "$(head -n 1 "$1")" = "---" ] || return 0
  awk 'NR == 1 { next } /^---$/ { exit } /^paths:/ { on = 1; sub(/^paths:[ ]*/, ""); if ($0 != "") print; next }
       on && /^[ ]*- / { sub(/^[ ]*- /, ""); print; next } on { on = 0 }' "$1" | tr -d '"' | paste -sd ' ' -
}

show() {
  local path=$1
  case "$path" in "$home"/*) path="~${path#"$home"}" ;; esac
  printf '%8s  %s\n' "$2" "$path"
}

# add <fichier> : compte un fichier chargé, une seule fois même s'il est atteint
# par deux chemins (le `~/.claude` de l'utilisateur est aussi un dossier parent)
add() {
  local file real n p
  file=$1
  [ -f "$file" ] || return 0
  real=$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")
  case "$seen" in *" $real "*) return 0 ;; esac
  seen="$seen$real "
  n=$(chars "$real")
  p=$(paths_of "$real")
  if [ -n "$p" ]; then
    scoped="$scoped$(show "$real" "$n")  ($p)"$'\n'
    return 0
  fi
  show "$real" "$n"
  always=$((always + n))
  imports "$real"
}

# Les imports `@chemin` d'un fichier d'instructions, seuls sur leur ligne
imports() {
  local dir line ref
  dir=$(dirname "$1")
  while IFS= read -r line; do
    ref=${line#@}
    # shellcheck disable=SC2088 # le `~` littéral de l'import, développé à la main
    case "$ref" in "~/"*) ref="$home/${ref#"~/"}" ;; /*) ;; *) ref="$dir/$ref" ;; esac
    add "$ref"
  done < <(grep -E '^@[^ ]+$' "$1" || true)
}

rules() {
  [ -d "$1" ] || return 0
  local f
  while IFS= read -r f; do add "$f"; done < <(find "$1" -name '*.md' | sort)
}

echo "Chargé à chaque session lancée depuis $(show "$target" "" | sed 's/^ *//')"
add "$home/.claude/CLAUDE.md"
rules "$home/.claude/rules"

dir=""
IFS=/ read -ra parts <<<"${target#/}"
for part in "${parts[@]}"; do
  dir="$dir/$part"
  add "$dir/CLAUDE.md"
  add "$dir/.claude/CLAUDE.md"
  add "$dir/CLAUDE.local.md"
  rules "$dir/.claude/rules"
done

# La mémoire automatique : 200 premières lignes, au plus 25 Ko
memory="$home/.claude/projects/$(printf '%s' "$target" | sed 's/[^A-Za-z0-9]/-/g')/memory/MEMORY.md"
if [ -f "$memory" ]; then
  n=$(head -n 200 "$memory" | head -c 25600 | wc -m | tr -d ' ')
  show "$memory" "$n"
  always=$((always + n))
fi

printf '%8s  total, ≈ %s tokens — budget %s\n' "$always" "$((always * 2 / 7))" "$BUDGET"
if [ -n "$scoped" ]; then
  echo
  echo "Chargé à la lecture d'un fichier qui correspond (paths:)"
  printf '%s' "$scoped"
fi

if [ "$always" -gt "$BUDGET" ]; then
  echo
  echo "Dépassement : $((always - BUDGET)) caractères au-delà du budget"
  exit 1
fi
