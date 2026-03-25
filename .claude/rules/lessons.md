---
description: Leçons apprises — workspace Nina.fm (chargé automatiquement dans tous les repos)
---

# Lessons — workspace

## Changesets
- `pnpm changeset` est interactif — ne jamais l'exécuter, ça bloque. Toujours créer le fichier `.changeset/nom-descriptif.md` manuellement avec le frontmatter `---\n"package": patch|minor|major\n---\ndescription`
- Ne jamais mettre `[skip ci]` sur un commit de changeset dans une PR — le squash merge propage le tag et skippa la CI au merge

## Workflow PR (ordre obligatoire)
- plan mode → branche (`git pull origin main && git checkout -b`) → code → changeset (chaque repo `feat:`/`fix:`) → commit → push → PR via `mcp__github__create_pull_request` → review si demandée
- Jamais de modifs sur `main` directement
- Jamais déléguer la création de PR à un agent (il utilisera `gh pr create`)
- Merge : toujours `mcp__github__merge_pull_request` avec `merge_method: "squash"`

## CI — Reusable Workflows
- Pour tout ajout de step CI non-trivial : toujours se demander si ça mérite un reusable workflow (`workflow_call`) partagé dans `.github/workflows/` du repo concerné ou dans un repo `.github` dédié
- Critères pour mutualiser : même logique sur 2+ repos, ou step suffisamment complexe pour justifier une maintenance centralisée
- Critères pour ne pas mutualiser : step trivial (1-2 lignes), très spécifique au repo, ou pas de réutilisation prévisible

## Types auto-générés
- `app/types/` et `src/types/api/` = générés depuis OpenAPI — ne jamais modifier manuellement, corriger la source
