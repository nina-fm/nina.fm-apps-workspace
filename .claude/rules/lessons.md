---
description: Leçons apprises — workspace Nina.fm (chargé automatiquement dans tous les repos)
---

# Lessons — workspace

## Changesets
- `pnpm changeset` est interactif — ne jamais l'exécuter, ça bloque. Toujours créer le fichier `.changeset/nom-descriptif.md` manuellement avec le frontmatter `---\n"package": patch|minor|major\n---\ndescription`

## Workflow PR (ordre obligatoire)
- plan mode → branche (`git pull origin main && git checkout -b`) → code → changeset (chaque repo `feat:`/`fix:`) → commit → push → PR via `mcp__github__create_pull_request` → review si demandée
- Jamais de modifs sur `main` directement
- Jamais déléguer la création de PR à un agent (il utilisera `gh pr create`)
- Merge : toujours `mcp__github__merge_pull_request` avec `merge_method: "squash"`

## Types auto-générés
- `app/types/` et `src/types/api/` = générés depuis OpenAPI — ne jamais modifier manuellement, corriger la source
