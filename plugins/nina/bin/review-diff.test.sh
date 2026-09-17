#!/usr/bin/env bash
# Test de non-régression de review-diff.sh : bash plugins/nina/bin/review-diff.test.sh
# Un vrai dépôt git jetable — ce qu'on vérifie est justement ce que git fait des
# attributs — et un faux `gh` qui sert la base et consigne ses appels.

script="$(cd "$(dirname "$0")" && pwd)/review-diff.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

fail() {
  echo "ÉCHEC $1"
  failures=$((failures + 1))
}

mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_CALLS"
case "$1 $2" in
  "repo view") echo main ;;
  # `pr view --json baseRefOid,baseRefName` : la base d'époque, que le test pose
  # dans PR_BASE, puis le nom de la branche de base
  "pr view") echo "$(cat "$PR_BASE") main" ;;
  *) echo '' ;;
esac
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GH_CALLS="$work/calls" PR_BASE="$work/pr_base"

# fixture <attributs> : un dépôt où `origin/main` est le point de départ et la
# branche courante ajoute une ligne à chaque fichier. `origin` est un vrai remote
# local, pour que le fetch du script ait quelque chose à récupérer.
fixture() {
  local repo="$work/repo" origin="$work/origin"
  rm -rf "$repo" "$origin"
  git init -q --bare "$origin"
  git init -q -b main "$repo"
  git -C "$repo" remote add origin "$origin"
  mkdir -p "$repo/src/api/model"
  printf '%s\n' "$1" >"$repo/.gitattributes"
  [ -s "$repo/.gitattributes" ] || rm "$repo/.gitattributes"
  for f in src/api/ninaFmApi.ts src/api/model/x.ts src/api/fetcher.ts src/real.ts pnpm-lock.yaml; do
    printf 'origine\n' >"$repo/$f"
  done
  git -C "$repo" add -A
  git -C "$repo" -c user.email=t@t -c user.name=t commit -qm "socle"
  git -C "$repo" push -q origin main
  git -C "$repo" rev-parse HEAD >"$PR_BASE"   # la base d'époque, que sert le faux gh
  for f in src/api/ninaFmApi.ts src/api/model/x.ts src/api/fetcher.ts src/real.ts pnpm-lock.yaml; do
    printf 'modifie\n' >>"$repo/$f"
  done
  git -C "$repo" add -A
  git -C "$repo" -c user.email=t@t -c user.name=t commit -qm "feat: la modification relue"
}

# run <args…> : exécute review-diff.sh depuis le dépôt jetable
run() {
  : >"$GH_CALLS"
  out=$(cd "$work/repo" && bash "$script" "$@" 2>"$work/err")
  code=$?
  err=$(cat "$work/err")
}

# contenu_relu <fichier> : le fichier a-t-il son contenu dans « Diff à relire » ?
contenu_relu() {
  printf '%s' "$out" | sed -n '/^--- Diff à relire ---$/,$p' | grep -q "^diff --git a/$1 "
}

# --- should exclure du contenu un fichier marqué linguist-generated=true -------
fixture 'src/api/** linguist-generated=true'
run
contenu_relu src/api/ninaFmApi.ts && fail "marqué =true : le contenu du généré est relu"
contenu_relu src/api/model/x.ts && fail "marqué =true : le contenu d'un généré en sous-dossier est relu"
contenu_relu src/real.ts || fail "marqué =true : le contenu du fichier à relire manque"

# --- should reconnaître aussi un attribut nu (set), pas seulement la valeur true
fixture 'src/api/** linguist-generated'
run
contenu_relu src/api/ninaFmApi.ts && fail "attribut nu : « set » n'est pas reconnu, rien n'est écarté"

# --- should relire un fichier réinclus par -linguist-generated -----------------
fixture 'src/api/** linguist-generated=true
src/api/fetcher.ts -linguist-generated'
run
contenu_relu src/api/fetcher.ts || fail "réinclusion : fetcher.ts, écrit à la main, n'est pas relu"
contenu_relu src/api/ninaFmApi.ts && fail "réinclusion : elle a aussi réintroduit le généré"

# --- should écarter les lockfiles sans déclaration, et obéir à une exclusion ----
fixture ''
run
contenu_relu pnpm-lock.yaml && fail "sans déclaration : le contenu du lockfile est relu"
contenu_relu src/real.ts || fail "sans déclaration : le contenu du fichier à relire manque"
fixture 'pnpm-lock.yaml -linguist-generated'
run
contenu_relu pnpm-lock.yaml || fail "lockfile explicitement relisible : la déclaration du repo ne prime pas"

# --- should garder tous les fichiers dans le récapitulatif ---------------------
fixture 'src/api/** linguist-generated=true'
run
recap=$(printf '%s' "$out" | sed -n '/^--- Récapitulatif, tous fichiers ---$/,/^--- Fichiers générés/p')
for f in src/api/ninaFmApi.ts src/api/model/x.ts src/real.ts pnpm-lock.yaml; do
  grep -q "$f" <<<"$recap" || fail "récapitulatif : $f manque, alors qu'il a changé"
done
# 4 écartés : les trois de src/api/ plus le lockfile, écarté sans déclaration
[[ "$out" == *"Fichiers modifiés : 5 | Écartés du contenu, car générés : 4"* ]] \
  || fail "entête : comptes attendus « 5 » et « 4 », obtenu « $(grep -m1 'Fichiers modifiés' <<<"$out") »"

# --- should nommer les fichiers écartés ---------------------------------------
ecartes=$(printf '%s' "$out" | sed -n '/^--- Fichiers générés/,/^--- Diff à relire/p')
grep -q 'src/api/ninaFmApi.ts' <<<"$ecartes" || fail "liste des écartés : le généré n'y est pas nommé"
grep -q 'régénérés depuis la source' <<<"$ecartes" || fail "liste des écartés : la vérification à faire n'est pas rappelée"

# --- should signaler un repo qui ne déclare rien, et se taire sinon ------------
fixture ''
run
[[ "$out" == *"ne déclare aucun chemin généré"* ]] || fail "sans .gitattributes : le repo n'est pas invité à déclarer ses chemins"
fixture 'src/api/** linguist-generated=true'
run
[[ "$out" != *"ne déclare aucun chemin généré"* ]] || fail "avec déclaration : l'invitation à déclarer est répétée pour rien"

# --- should tirer le diff de refs/pull/N/head, sans laisser de ref -------------
fixture 'src/api/** linguist-generated=true'
git -C "$work/repo" push -q origin HEAD:refs/pull/42/head
git -C "$work/repo" reset -q --hard origin/main
run 42
[[ $code -eq 0 ]] || fail "PR : attendu code 0, obtenu $code, erreur « $err »"
contenu_relu src/real.ts || fail "PR : le diff ne vient pas de refs/pull/42/head — rien à relire"
contenu_relu src/api/ninaFmApi.ts && fail "PR : le contenu du généré est relu"
[[ "$out" == *"Review de PR #42 → main"* ]] || fail "PR : l'entête ne nomme pas la PR relue"
grep -q -- "pr view 42 --json baseRefOid,baseRefName" "$GH_CALLS" || fail "PR : la base d'époque n'est pas demandée à gh"
[[ -z "$(git -C "$work/repo" for-each-ref --format='%(refname)' 'refs/pull' 'refs/nina*')" ]] \
  || fail "PR : une ref locale est restée après la review"

# --- should relire une PR dont la tête est déjà dans la branche de base --------
# Mergée sans squash, la tête de la PR entre telle quelle dans la base : un diff
# contre `origin/main` est alors vide, et la review n'a plus rien à relire.
fixture 'src/api/** linguist-generated=true'
git -C "$work/repo" push -q origin HEAD:refs/pull/42/head
git -C "$work/repo" push -q origin HEAD:main
git -C "$work/repo" fetch -q origin
run 42
contenu_relu src/real.ts || fail "PR mergée sans squash : le diff est vide, la base d'époque n'est pas celle utilisée"
[[ "$out" == *"Fichiers modifiés : 5"* ]] || fail "PR mergée sans squash : comptes attendus « 5 », obtenu « $(grep -m1 'Fichiers modifiés' <<<"$out") »"

# --- should refuser un argument qui n'est pas un numéro ------------------------
run abc
[[ $code -eq 2 && "$err" == *"usage : review-diff.sh"* ]] || fail "argument non numérique : attendu code 2 et l'usage, obtenu code $code, erreur « $err »"

if [[ $failures -gt 0 ]]; then
  echo "$failures cas en échec"
  exit 1
fi
echo "Tous les cas passent"
