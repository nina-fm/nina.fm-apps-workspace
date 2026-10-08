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
- Une fonction qui porte le nom d'un alias (`g`, `gp`…) échoue en `parse error` : nom improbable
- Un remplacement qui lit une variable absente (`perl … $ENV{SEC}`) remplace par du vide en silence : `or die`, puis relire le fichier avant publication
- `grep -v NOM` exclut tout nom qui **contient** le motif : filtrer sur le nom exact (`find … ! -name 'README.md'`)
- Sous `set -e`, `VAR=$(cmd)` arrête le script si `cmd` échoue : `|| true` quand ne rien trouver est permis

## gh

- `-f champ=123` envoie une chaîne : `-F` pour un entier (`sub_issue_id`)
- Corps de commentaire, d'issue ou de PR : `--body-file`, écrit par heredoc `<<'EOF'` — en argument, zsh exécute les backticks et casse sur les apostrophes
- Une collection se lit avec `--paginate` (sinon 30 éléments) ; `--slurp` refuse `--jq` : `… --paginate --slurp | jq '.[][]'`

## Chercher dans les repos

Le code de faceb est dans `app/`, celui de mixtaper dans `src/` : chercher depuis la racine (`git ls-files | xargs grep`), jamais dans un dossier supposé.

## Mutualiser

Un modèle à recopier ne porte que le **commun** : ce qui est propre à chaque repo (`env.NINA_PROJECT`) se décrit à part, avec ses valeurs (api#58).
