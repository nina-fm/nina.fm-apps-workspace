#!/usr/bin/env bash
# Test de non-régression de harnais.sh : bash plugins/nina/bin/harnais.test.sh
# Un faux HOME qui contient l'arbre workspace/repo, comme sur le poste : le
# `~/.claude` de l'utilisateur est alors aussi un dossier parent, compté une fois.

script="$(cd "$(dirname "$0")" && pwd)/harnais.sh"
work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "ÉCHEC $1"
  failures=$((failures + 1))
}

# expect <description> <motif> : la dernière sortie contient la ligne
expect() {
  grep -qE -- "$2" "$work/out" || fail "$1 — attendu /$2/ dans :"$'\n'"$(cat "$work/out")"
}

refute() {
  grep -qE -- "$2" "$work/out" && fail "$1 — /$2/ inattendu dans :"$'\n'"$(cat "$work/out")"
}

export HOME="$work"
ws="$work/ws"
mkdir -p "$HOME/.claude/rules" "$ws/.claude/rules" "$ws/repo/.claude/rules" "$ws/autre"
printf '%s\n' "1234" "@RTK.md" >"$HOME/.claude/CLAUDE.md"   # 13 caractères
printf '12345678\n' >"$HOME/.claude/RTK.md"                 # 9
printf 'é\n' >"$HOME/.claude/rules/perso.md"                 # 2 : des caractères, pas des octets
printf '1234\n' >"$ws/CLAUDE.md"                             # 5
printf -- '---\ndescription: ignorée\n---\n123\n' >"$ws/.claude/rules/lessons.md"   # 4, frontmatter exclu
printf -- '---\npaths:\n  - ".github/**"\n  - "x/**"\n---\n12\n' >"$ws/.claude/rules/gha.md"
printf -- '---\npaths: "y/**"\n---\n1\n' >"$ws/.claude/rules/inline.md"
printf '123\n' >"$ws/repo/CLAUDE.md"                         # 4
printf '12\n' >"$ws/autre/CLAUDE.md"                         # jamais chargé depuis repo
mem="$HOME/.claude/projects/$(printf '%s' "$ws/repo" | sed 's/[^A-Za-z0-9]/-/g')/memory"
mkdir -p "$mem"
seq 1 300 >"$mem/MEMORY.md"   # 200 premières lignes : 9×2 + 90×3 + 101×4 = 692

bash "$script" "$ws/repo" >"$work/out"
code=$?
expect "CLAUDE.md utilisateur" '^ +13  ~/.claude/CLAUDE.md$'
expect "import @ résolu depuis le dossier du fichier" '^ +9  ~/.claude/RTK.md$'
expect "caractères comptés, pas octets" '^ +2  ~/.claude/rules/perso.md$'
expect "frontmatter sans paths retiré" '^ +4  ~/ws/.claude/rules/lessons.md$'
expect "mémoire tronquée à 200 lignes" '^ +692  ~/.claude/projects/.*/MEMORY.md$'
expect "total" '^ +729  total'
expect "règle scopée, motifs en liste" '^ +3  ~/ws/.claude/rules/gha.md  \(.github/\*\* x/\*\*\)$'
expect "règle scopée, motif en ligne" '^ +2  ~/ws/.claude/rules/inline.md  \(y/\*\*\)$'
refute "dossier frère" 'autre/CLAUDE.md'
# shellcheck disable=SC2088 # message affiché, pas un chemin
[ "$(grep -c 'CLAUDE.md$' "$work/out")" = 3 ] || fail "~/.claude/CLAUDE.md compté deux fois"
[ "$code" = 0 ] || fail "code $code dans le budget, attendu 0"

HARNAIS_BUDGET=700 bash "$script" "$ws/repo" >"$work/out"
code=$?
expect "dépassement chiffré" '^Dépassement : 29 caractères'
[ "$code" = 1 ] || fail "code $code hors budget, attendu 1"

# Frontmatter non fermé : Claude Code l'ignore et charge tout le fichier ;
# `paths: []` ne scope rien
printf -- '---\npaths:\n  - "z/**"\n12\n' >"$ws/.claude/rules/ouvert.md"   # 25
printf -- '---\npaths: []\n---\n1\n' >"$ws/.claude/rules/vide.md"             # 2
bash "$script" "$ws/repo" >"$work/out"
expect "frontmatter non fermé compté en entier" '^ +25  ~/ws/.claude/rules/ouvert.md$'
expect "paths vide chargé sans condition" '^ +2  ~/ws/.claude/rules/vide.md$'
rm "$ws/.claude/rules/ouvert.md" "$ws/.claude/rules/vide.md"

# Mémoire de 120 Ko : tronquée à 25 Ko, sans que le SIGPIPE du premier `head`
# n'arrête le script ; cherchée sous la racine git depuis un sous-dossier
git init -q "$ws/repo"
mkdir -p "$ws/repo/src"
awk 'BEGIN { for (i = 0; i < 200; i++) { s = ""; for (j = 0; j < 599; j++) s = s "x"; print s } }' >"$mem/MEMORY.md"
bash "$script" "$ws/repo/src" >"$work/out"
code=$?
expect "mémoire tronquée à 25 Ko, depuis un sous-dossier" '^ +25600  ~/.claude/projects/.*/MEMORY.md$'
expect "total malgré une grosse mémoire" 'total'
[ "$code" = 1 ] || fail "code $code avec une mémoire de 120 Ko, attendu 1 (hors budget)"

bash "$script" "$work/absent" >"$work/out" 2>&1
code=$?
[ "$code" = 2 ] || fail "code $code sur un dossier absent, attendu 2"

# --alerte, pour le hook SessionStart : muet dans le budget, une ligne au-delà,
# toujours 0, et muet sur un dossier absent
HARNAIS_BUDGET=100000 bash "$script" --alerte "$ws/repo" >"$work/out" 2>&1
code=$?
[ -s "$work/out" ] && fail "--alerte dans le budget : sortie inattendue : $(cat "$work/out")"
[ "$code" = 0 ] || fail "--alerte dans le budget : code $code, attendu 0"
HARNAIS_BUDGET=10 bash "$script" --alerte "$ws/repo" >"$work/out" 2>&1
code=$?
expect "--alerte au-delà du budget" '^Harnais : [0-9]+ caractères .* budget 10 — lancer /nina:harnais$'
[ "$(wc -l <"$work/out" | tr -d ' ')" = 1 ] || fail "--alerte : une seule ligne attendue"
[ "$code" = 0 ] || fail "--alerte au-delà du budget : code $code, attendu 0"
bash "$script" --alerte "$work/absent" >"$work/out" 2>&1
code=$?
[ -s "$work/out" ] && fail "--alerte sur un dossier absent : sortie inattendue"
[ "$code" = 0 ] || fail "--alerte sur un dossier absent : code $code, attendu 0"

if [ "$failures" -gt 0 ]; then
  echo "$failures échec(s)"
  exit 1
fi
echo "harnais.sh : tous les cas passent"
