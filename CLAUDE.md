# CLAUDE.md — nina.fm-apps-workspace

Guidelines transversales pour tous les repos du workspace Nina.fm.

> Chaque repo a son propre CLAUDE.md pour les conventions stack-spécifiques.
> Voir `WORKSPACE.md` pour l'infrastructure, l'écosystème et le workflow git.

## TypeScript

- `strict: true` dans tous les repos — zéro `any` dans le nouveau code
- `catch (error: unknown)` — `error instanceof Error ? error.message : 'Erreur inconnue'`
- Types de retour explicites sur toutes les fonctions/méthodes **publiques**
- `??` (nullish coalescing) pas `||` pour les valeurs par défaut
- `unknown` + type guards pour les données externes (API, events, localStorage)
- `readonly` sur les dépendances injectées et les refs non-mutables

## Tests

Tester intelligemment, pas exhaustivement. Objectif : maintenabilité et non-régression.

**Tester :** logique métier isolée, cas d'erreur, contrats publics, régressions connues.
**Ne pas tester :** composants purement UI, getters triviaux, wrappers d'une ligne.

- Nommage : `it('should [comportement] when [condition]')` — jamais `it('works')`
- Pas de snapshot tests
- Coverage 80% minimum global (exceptions : config, migrations, DTOs simples)
- Co-localisation : `my-service.test.ts` ou `my-service.spec.ts`
- Factory helpers pour les objets complexes : `createMockTrack()`, `createMockSession()`
- Mocks uniquement sur les dépendances externes (DB, HTTP) — pas sur la logique métier
- Priorité : unitaires → fonctionnels → e2e (parcours critiques uniquement)

## Workflow d'implémentation

Pour toute implémentation multi-étapes : utiliser le skill `/task` pour analyser et planifier, puis créer des tasks (TaskCreate) pour suivre la progression étape par étape.

## Self-Improvement

Après toute correction ou erreur détectée : mettre à jour `.claude/rules/lessons.md` du repo concerné (ou du workspace si transversal) avec la leçon en une ligne concise. Ne pas attendre que l'utilisateur le signale.

## Workflow Git & GitHub

Ordre : plan mode → `git pull origin main && git checkout -b` → code → changeset → commit → `git push -u origin <branch>` → `gh pr create` → review si demandée

- **Merger une PR** : `gh pr merge --squash --delete-branch <numéro>` — jamais `git merge` + `git push`
- **Squash merge** sur `main` — un commit par PR, historique propre
- **Changeset obligatoire** avant tout merge `feat:` ou `fix:` — créer `.changeset/nom.md` manuellement (jamais `pnpm changeset`, interactif) ; jamais `[skip ci]` sur ce commit (le squash propage le tag)
- **Toujours `push -u`** (pas juste `push`) — sans upstream, `gh pr create` échoue
- **Sync avant de tirer une branche** : `git pull origin main` puis `git checkout -b`
- **Suppression automatique des branches** au merge (`delete_branch_on_merge` activé)
- Conventions → `CLAUDE.md` du repo — jamais dans `~/.claude/` sauf préférences personnelles

## CI — Reusable Workflows

Pour tout ajout de step CI non-trivial, se demander si ça mérite un `workflow_call` partagé :
- **Mutualiser** : même logique sur 2+ repos, ou step complexe à maintenir centralement
- **Ne pas mutualiser** : step trivial (1-2 lignes), très spécifique au repo, pas de réutilisation prévisible

## Types auto-générés

`app/types/` et `src/types/api/` sont générés depuis OpenAPI — ne jamais modifier manuellement, corriger la source.
