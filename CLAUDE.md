# CLAUDE.md — nina.fm-apps-workspace

Guidelines globales pour tous les repos du workspace Nina.fm.
Ces règles s'appliquent à toutes les stacks (NestJS, Nuxt, SolidJS…) sauf mention contraire.

> Ce fichier est lu en cascade par Claude depuis n'importe quel repo du workspace.
> Voir `WORKSPACE.md` pour l'infrastructure, l'écosystème et le workflow git.

---

## Principes d'Architecture

**Logique métier → État → Hooks/Composables → Composant UI**

- Composants **dumb** : props in, events out — pas de stores, pas d'API directe
- Composants **smart** : orchestrent les hooks/composables — pas de rendu complexe
- Toute logique extractable dans une fonction pure ou une classe DOIT l'être
- Organisation par **domaine fonctionnel**, pas par type technique : `djs/`, `audio/`, `session/` — pas `components/hooks/utils/` plats
- `components/ui/` = primitives partagées uniquement (Shadcn, Kobalte)
- Composant > ~100 lignes de template ou logique non-triviale → extraire
- NestJS : chaque module = une feature (pattern natif)

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

## Front-end (Vue 3 / SolidJS)

- État dérivé : `computed()` / `createMemo()` — jamais recalculé inline dans le template/JSX
- Side effects : `watch()` / `createEffect()` — jamais pour calculer une valeur
- Mutations d'état via actions/setters explicites — jamais directement depuis les composants
- `cn()` (clsx + tailwind-merge) pour les classes Tailwind conditionnelles
- Icônes Lucide : imports **tree-shakeable** obligatoires — jamais d'import global
- Primitives Shadcn/Kobalte avant d'en créer de nouvelles
- Props typées explicitement, callbacks préfixés `on`, handlers locaux préfixés `handle`
- Vue : `defineProps<T>()` / `defineEmits<T>()` avec types génériques — jamais options API
- SolidJS : signaux appelés comme fonctions `value()`, `Show` / `For` en JSX — pas de ternaires / `.map()`

## Back-end (NestJS)

- Controller → Service → Repository : **logique métier dans les services uniquement**
- `private readonly logger = new Logger(ClassName.name)` dans chaque service/controller — jamais `console.log`
- Exceptions dans les **services** : `NotFoundException`, `BadRequestException`, `ForbiddenException`, `ConflictException`
- Réponses : `{ data: T }` pour une ressource, `{ data: T[], pagination: ... }` pour une liste paginée
- `synchronize: false` TypeORM — migrations uniquement, jamais d'auto-sync
- `ConfigService` pour les env vars — jamais `process.env` direct

## Par Framework

**Nuxt 4** (`nina.fm-faceb`, `nina.fm-website`) : `srcDir: 'app'`, `useRuntimeConfig()` pour les env vars côté client, Pinia setup syntax. → Voir CLAUDE.md du repo.

**SolidJS** (`nina.fm-mixtaper`) : signaux `value()`, `Show`/`For` en JSX, `createMemo()` pour les dérivations. → Voir CLAUDE.md du repo.

**NestJS** (`nina.fm-api`) : Module → Controller → Service → Entity + DTO, `PartialType(CreateDto)` pour les updates. → Voir CLAUDE.md du repo.

## Workflow d'implémentation

- Pour toute implémentation multi-étapes dans ce workspace : utiliser le skill `/task` pour analyser et planifier, puis créer des tasks (TaskCreate) pour suivre la progression étape par étape

## Self-Improvement

Après toute correction ou erreur détectée (correction de l'utilisateur, commande qui échoue, mauvaise approche constatée en cours de route) : mettre à jour `.claude/rules/lessons.md` du repo concerné (ou du workspace si la leçon est transversale) avec la leçon, en une ligne concise. Ne pas attendre que l'utilisateur le signale — si je réalise que j'ai pris la mauvaise voie, j'ajoute la leçon moi-même. Ce fichier est chargé automatiquement par Claude Code à chaque session.

## Workflow Git & GitHub

- **Merger une PR** : `mcp__github__merge_pull_request` avec `merge_method: "squash"` — jamais `git merge` + `git push`
- **Squash merge** sur `main` — un commit par PR, historique propre
- **Changeset obligatoire** avant tout merge `feat:` ou `fix:` — `pnpm changeset`
- **Sync avant de tirer une branche** : `git pull origin main` puis `git checkout -b`
- **Suppression automatique des branches** au merge (`delete_branch_on_merge` activé sur tous les repos)
- Conventions → `CLAUDE.md` (workspace ou repo) — jamais dans `~/.claude/` sauf préférences vraiment personnelles
