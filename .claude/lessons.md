# Leçons apprises — workspace Nina.fm

## Git & GitHub

### Merger via `mcp__github__merge_pull_request` uniquement
Un merge local (`git merge` + `git push`) casse la convention squash-merge — l'historique devient sale, les chains de revert se compliquent, l'historique CI devient illisible. Toujours `mcp__github__merge_pull_request` avec `merge_method: "squash"`.

### Changeset obligatoire avant tout merge `feat:` ou `fix:`
Le CI de release utilise les changesets pour calculer les bumps de version et générer les changelogs. Un PR `feat:` ou `fix:` mergé sans changeset = feature perdue dans l'historique de release. Vérifier avec `ls .changeset/*.md` avant de merger.

## Types API auto-générés

### Ne jamais modifier `src/types/api/` ou `app/types/` manuellement
Ces dossiers sont régénérés par `pnpm types:sync` depuis le schéma OpenAPI. Toute modification manuelle est écrasée au prochain sync. Si les types générés sont incorrects, corriger la source (schéma OpenAPI ou décorateurs NestJS), pas les fichiers générés.
