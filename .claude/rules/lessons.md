# Lessons — workspace

Chargé dans toute session des cinq repos : une leçon n'est ici que si elle peut servir
n'importe quand. Le reste se scope (`paths:`, voir `github-actions.md`), va dans une
commande, un script ou `plugins/nina/LESSONS.md`. L'histoire d'une leçon reste dans
l'issue citée. `/nina:harnais` mesure et fait le tri.

## Shell (zsh)

- Tableaux indexés à **1** : itérer sur les éléments (`for t in "${arr[@]}"`), pas sur des indices
- Un mot qui commence par `=` est une expansion (`echo =====` → `==== not found`) : séparateurs entre guillemets
- `$var:x` applique le modificateur `:x` (`"$B:src/…"` substitue) : accolades, `"${B}:src/…"`
- Une variable non quotée n'est **pas** découpée en mots : `"${spec%%:*}"` / `"${spec##*:}"`, ou `${=spec}`
- Une fonction qui porte le nom d'un alias (`g`, `gp`…) échoue en `parse error` : `function nom { … }` avec un nom improbable
- Un remplacement qui lit une variable absente (`perl … $ENV{SEC}`) remplace par du vide en silence : `open … or die` en tête, puis relire le fichier avant publication
- `grep -v NOM` exclut tout nom qui **contient** le motif : filtrer sur le nom exact (`find … ! -name 'README.md'`)
- `echo "$var"` interprète les `\` : un JSON passé par `echo` à `jq` casse (`Invalid escape`) ; `printf '%s' "$var"`
- Une apostrophe dans un programme `awk` ou `jq` entre guillemets simples le ferme, **commentaires compris** (`# l'ordre`) : le script casse en `commande introuvable` loin de la cause
- Sous `set -e`, `VAR=$(cmd)` arrête le script si `cmd` échoue : `|| true` quand ne rien trouver est permis

## gh

- `-f champ=123` envoie une chaîne : `-F` pour un entier (`sub_issue_id`)
- Corps de commentaire, d'issue ou de PR : `--body-file`, écrit par heredoc `<<'EOF'` — en argument, zsh exécute les backticks et casse sur les apostrophes
- Aucun `Closes` / `Fixes` / `Resolves #N` dans un **message de commit** : il ferme l'issue au squash, quoi que dise le corps de la PR (workspace#55) ; `Refs #N`
- Une collection se lit avec `--paginate` (sinon 30 éléments) ; `--slurp` refuse `--jq` : `… --paginate --slurp | jq '.[][]'`

## GitHub hors fichiers

Ce qui se fait par `gh api`, sans lire de fichier, ne charge aucune règle à `paths:` :

- Un push fait avec `GITHUB_TOKEN` ne franchit pas un check requis (l'app Actions ne peut pas être en bypass d'un ruleset) : un check obligatoire sur `main` casse les `release.yml` qui y poussent (website#65)
- Les secrets vivent dans chaque repo : en plan Free, un repo privé ne reçoit pas les secrets d'org, même si `gh api …/organization-secrets` les liste (mixtaper#73)

## Chercher dans les repos

Le code de faceb est dans `app/`, celui de mixtaper dans `src/` : chercher depuis la racine (`git ls-files | xargs grep`), jamais dans un dossier supposé.

## Mutualiser

Un modèle à recopier ne porte que le **commun** : ce qui est propre à chaque repo (`env.NINA_PROJECT`) se décrit à part, avec ses valeurs (api#58).
