# Plan d'optimisation Claude Code — Workspace Nina.fm

> Objectif : réduire le contexte système chargé à chaque conversation tout en
> maintenant (et améliorant) la capacité cross-repo.
>
> **État actuel** : ~40 000 tokens de CLAUDE.md chargés pour chaque conversation.
> **Cible** : ~11 000 tokens toujours chargés + agents spécialisés à la demande.

---

## 1. Diagnostic

| Repo             | CLAUDE.md actuel | ~Tokens     | % "connu par Claude" |
| ---------------- | ---------------- | ----------- | -------------------- |
| Workspace root   | 262 lignes       | 6 500       | ~60%                 |
| nina.fm-api      | 400 lignes       | 10 000      | ~40%                 |
| nina.fm-website  | 210 lignes       | 5 250       | ~55%                 |
| nina.fm-faceb    | 296 lignes       | 7 400       | ~45%                 |
| nina.fm-mixtaper | 447 lignes       | 11 175      | ~45%                 |
| nina.fm-auth     | —                | 0           | —                    |
| **Total**        | **1 615 lignes** | **~40 325** |                      |

**Économie visée après refactoring :** ~29 000 tokens (~72%)

---

## 2. Architecture cible (3 tiers)

```
┌─────────────────────────────────────────────────────────────┐
│  TIER 1 — Toujours chargé (CLAUDE.md)                       │
│  Contraintes projet, module map, commandes, règles rares     │
│  Cible : 70–110 lignes par repo                              │
└─────────────────────────────────────────────────────────────┘
              ↓ délégation automatique
┌─────────────────────────────────────────────────────────────┐
│  TIER 2 — On demand (.claude/agents/)                        │
│  Agents spécialisés : patterns complets + exemples           │
│  Chargés uniquement quand la tâche les requiert              │
│  System prompt riche, tools restreints, context isolé        │
└─────────────────────────────────────────────────────────────┘
              ↓ invocation explicite utilisateur
┌─────────────────────────────────────────────────────────────┐
│  TIER 3 — Explicite (.claude/commands/)                      │
│  Workflows interactifs : scaffolding, sync, release          │
│  L'utilisateur invoque volontairement                        │
└─────────────────────────────────────────────────────────────┘
```

### Règle de tri

| Type de contenu                                | Tier        | Raison                                                |
| ---------------------------------------------- | ----------- | ----------------------------------------------------- |
| Règles non-évidentes du projet                 | 1           | Toujours pertinent                                    |
| Module map + périmètre des touches             | 1           | Oriente chaque décision                               |
| Commandes bash courantes                       | 1           | Référence rapide                                      |
| Patterns avec exemples de code                 | 2 (agent)   | Claude connaît la syntaxe, pas les conventions projet |
| Flux de travail complets (scaffold, migration) | 3 (command) | Déclenché volontairement                              |

---

## 3. Workspace root — Ce qui change

### 3.1 CLAUDE.md (262L → ~90L)

**Garder :**

- Principes d'architecture (texte, sans blocs de code)
- Git workflow (squash merge, changeset, sync avant branch)
- TypeScript rules (liste de bullets, sans exemples)
- Test philosophy (sans exemples de code)
- Section "Par Framework" — renvois vers les repos

**Supprimer / déplacer :**

- Blocs ❌/✅ avec code (→ agents)
- Section Front-end (Vue 3 / SolidJS patterns) → repo CLAUDE.md respectifs
- Section Back-end (NestJS patterns) → nina.fm-api/CLAUDE.md

### 3.2 `.claude/rules/` (path-scoped — NOUVEAU)

Fichiers de règles chargés uniquement si Claude ouvre des fichiers matching le path.
Permet la capacité cross-repo sans polluer le contexte.

```
.claude/rules/
├── api-context.md         paths: ["nina.fm-api/**"]
├── website-context.md     paths: ["nina.fm-website/**"]
├── faceb-context.md       paths: ["nina.fm-faceb/**"]
└── mixtaper-context.md    paths: ["nina.fm-mixtaper/**"]
```

Chaque fichier = résumé condensé du repo pour quand on y touche depuis le workspace.

### 3.3 Agents workspace (NOUVEAU)

```
.claude/agents/
└── api-explorer.md
```

**`api-explorer`** — Pour les développeurs frontend qui ont besoin de contexte API.

- Invocation auto : "comment fonctionne l'endpoint X", "quel est le format de réponse", "quels modules API puis-je utiliser"
- Contenu : module map complète, format réponse, auth/permissions, types générés

---

## 4. nina.fm-api — Ce qui change

### 4.1 CLAUDE.md (400L → ~100L)

**Garder :**

- Commandes (déjà concis)
- Module Map (🎛️ libre / 🔒 partagé / 🚫 autres apps) — critique, orienter chaque décision
- Variables d'environnement clés
- Auth et Permissions (court, non-évident)
- Règles courtes : `synchronize: false`, `ConfigService` obligatoire, `{ data: T }` wrap

**Supprimer → agents :**

- Pattern DTO complet avec exemples → `api-pattern-dto`
- Pattern Entity → `api-pattern-entity`
- Pattern Service → `api-pattern-service`
- Pattern Controller → `api-pattern-controller`
- Tests complets → `api-test-writer`
- Bruno files → `api-bruno-writer`
- Migrations → command `/new-migration`

### 4.2 Agents (NOUVEAU)

```
nina.fm-api/.claude/agents/
├── api-module-builder.md      ← orchestrateur : crée un module complet
├── api-pattern-dto.md         ← patterns DTO avec class-validator + Swagger
├── api-pattern-entity.md      ← patterns Entity TypeORM + types enrichis
├── api-pattern-service.md     ← patterns Service NestJS
├── api-pattern-controller.md  ← patterns Controller + Swagger docs
├── api-test-writer.md         ← patterns Jest + mocks + factory helpers
└── api-bruno-writer.md        ← génération fichiers .bru
```

**Descriptions pour auto-invocation :**

| Agent                    | Description (champ `description:`)                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `api-module-builder`     | Crée un module NestJS complet (entity, DTO, service, controller, migration, tests, Bruno). Invoquer pour tout nouveau domaine/feature API. |
| `api-pattern-dto`        | Référence patterns DTO avec class-validator et @ApiProperty. Invoquer avant de créer ou modifier un DTO.                                   |
| `api-pattern-entity`     | Référence patterns Entity TypeORM avec relations, types enrichis, onDelete. Invoquer avant de créer ou modifier une entity.                |
| `api-pattern-service`    | Référence patterns Service NestJS : logger, ConfigService, repository, exceptions. Invoquer avant de créer ou modifier un service.         |
| `api-pattern-controller` | Référence patterns Controller : Swagger, réponses wrappées, ParseUUIDPipe. Invoquer avant de créer ou modifier un controller.              |
| `api-test-writer`        | Patterns tests unitaires NestJS : TestingModule, mocks Repository, factory helpers. Invoquer pour écrire des tests.                        |
| `api-bruno-writer`       | Génère ou met à jour les fichiers .bru après modification d'endpoint. Invoquer après tout changement d'API.                                |

### 4.3 Commands (NOUVEAU ou modifié)

```
nina.fm-api/.claude/commands/
├── pr.md           ← existant
├── epic.md         ← existant
├── task.md         ← existant
├── review.md       ← existant
└── new-migration.md  ← NOUVEAU : wizard migration TypeORM
```

**`/new-migration`** : workflow complet : nommage, generate, vérification, run, revert si erreur.

---

## 5. nina.fm-website — Ce qui change

### 5.1 CLAUDE.md (210L → ~75L)

**Garder :**

- Commandes
- Structure dossiers (thèmes Peak/Vinyl, composants auto-importés)
- Variables d'environnement
- Règles SSR safety (import.meta.client, useRuntimeConfig)
- Note "site public uniquement = player radio"

**Supprimer → agents :**

- Pattern Composant Vue 3 avec exemples → `website-component-builder`
- SSE Streaming avec code détaillé → `sse-handler`
- Patterns Pinia avec code → `website-component-builder`

### 5.2 Agents (NOUVEAU)

```
nina.fm-website/.claude/agents/
├── website-component-builder.md  ← Vue 3 + Pinia + Shadcn/Reka patterns
└── sse-handler.md                ← SSE streaming, reconnexion, cleanup
```

| Agent                       | Description                                                                                                      |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `website-component-builder` | Crée composants Vue 3 avec Pinia, Shadcn/Reka, thèmes Peak/Vinyl.                                                |
| `sse-handler`               | Patterns SSE streaming radio : EventSource, reconnexion auto, cleanup. Invoquer pour tout code lié au streaming. |

---

## 6. nina.fm-faceb — Ce qui change

### 6.1 CLAUDE.md (296L → ~95L)

**Garder :**

- Commandes (dont `types:sync` — workflow critique)
- Structure dossiers
- Variables d'environnement
- Règle : 100% CSR (pas de SSR), raison explicite
- Règle : `credentials: include` obligatoire
- Auth SuperTokens (non-évident)

**Supprimer → agents :**

- TanStack Query patterns avec code → `faceb-feature-builder`
- VeeValidate + Zod patterns → `faceb-feature-builder`
- Pattern Composant Vue 3 → `faceb-feature-builder`
- types:sync détaillé → command `/sync-types` (déjà existant)

### 6.2 Agents (NOUVEAU)

```
nina.fm-faceb/.claude/agents/
└── faceb-feature-builder.md  ← TanStack Query + VeeValidate + Zod + Shadcn
```

| Agent                   | Description                                                                                                                                                     |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `faceb-feature-builder` | Crée features backoffice : TanStack Query (useQuery/useMutation), formulaires VeeValidate + Zod, composants Shadcn. Invoquer pour tout nouveau page ou feature. |

---

## 7. nina.fm-mixtaper — Ce qui change

### 7.1 CLAUDE.md (447L → ~110L)

**Garder :**

- Commandes
- Architecture centrale (texte) : Context → Store → Hooks → Components
- Hooks taxonomy (liste des 8 hooks avec rôle = oriente toutes les décisions)
- Services Layer (noms des classes = non-évident)
- Lucide icons import individuel (vite plugin — erreur fréquente)
- Variables d'environnement
- Types auto-générés : types:sync critique

**Supprimer → agents :**

- SessionStore interface complète → `mixtaper-feature-builder`
- Patterns SolidJS détaillés (Show, For, createMemo) → `mixtaper-component-builder`
- Pipeline audio (Web Worker, orchestrateur) → `audio-pipeline-handler`
- Tests Vitest patterns → `mixtaper-test-writer`

### 7.2 Agents (NOUVEAU)

```
nina.fm-mixtaper/.claude/agents/
├── mixtaper-feature-builder.md   ← SessionStore + Context + Hooks patterns
├── mixtaper-component-builder.md ← SolidJS UI patterns + Kobalte + Lucide
├── audio-pipeline-handler.md     ← Web Worker + AudioLoader + Essentia.js
└── mixtaper-test-writer.md       ← Vitest + @solidjs/testing-library
```

| Agent                        | Description                                                                                                                                     |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `mixtaper-feature-builder`   | Crée features Mixtaper : SessionStore signal, Context, Hooks (useSession, useTrackOperations…). Invoquer pour tout nouveau domaine fonctionnel. |
| `mixtaper-component-builder` | Crée composants SolidJS : Show/For, createMemo, Kobalte, Lucide imports individuels, cn(). Invoquer pour tout nouveau composant.                |
| `audio-pipeline-handler`     | Pipeline audio : AudioLoader → AudioAnalysis → Web Worker, Essentia.js BPM/Key. Invoquer pour tout code audio.                                  |
| `mixtaper-test-writer`       | Tests Vitest + @solidjs/testing-library, factory helpers, mocks. Invoquer pour écrire des tests.                                                |

---

## 8. nina.fm-auth — Ce qui est créé

Repo rarement touché. Un CLAUDE.md minimal suffit.

```
nina.fm-auth/CLAUDE.md (~30L)
```

**Contenu :** rôle du repo (wrapper SuperTokens), commandes docker, variables d'env, règle "ne pas modifier la logique SuperTokens directement".

---

## 9. Récapitulatif : catalogue complet des agents

| Agent                        | Repo      | Auto-invoqué quand                        |
| ---------------------------- | --------- | ----------------------------------------- |
| `api-explorer`               | workspace | Frontend dev pose des questions sur l'API |
| `api-module-builder`         | api       | Création d'un nouveau module/feature      |
| `api-pattern-dto`            | api       | Création/modification d'un DTO            |
| `api-pattern-entity`         | api       | Création/modification d'une Entity        |
| `api-pattern-service`        | api       | Création/modification d'un Service        |
| `api-pattern-controller`     | api       | Création/modification d'un Controller     |
| `api-test-writer`            | api       | Écriture de tests NestJS                  |
| `api-bruno-writer`           | api       | Modification d'endpoint → fichiers Bruno  |
| `website-component-builder`  | website   | Création de composant Vue 3 / feature     |
| `sse-handler`                | website   | Code lié au streaming SSE                 |
| `faceb-feature-builder`      | faceb     | Création de page / feature backoffice     |
| `mixtaper-feature-builder`   | mixtaper  | Nouveau domaine fonctionnel               |
| `mixtaper-component-builder` | mixtaper  | Nouveau composant SolidJS                 |
| `audio-pipeline-handler`     | mixtaper  | Code audio / Web Worker                   |
| `mixtaper-test-writer`       | mixtaper  | Écriture de tests Vitest                  |

---

## 10. Ce qui NE change PAS

- Les **hooks** (settings.json) — ESLint auto-fix PostToolUse, type-check PreToolUse
- Les **4 commands universels** (pr, epic, task, review) — restent identiques
- Les **`sync-types.md`** commands (faceb, mixtaper) — restent tels quels
- Les **settings.local.json** — permissions inchangées
- La **structure des repos** — aucune migration de code

---

## 11. Plan d'implémentation (ordre suggéré)

### Phase 1 — nina.fm-api (plus d'impact, patterns les plus clairs)

1. Créer les 7 agents dans `nina.fm-api/.claude/agents/`
2. Slim `nina.fm-api/CLAUDE.md` → ~100L
3. Créer command `/new-migration`
4. Valider en conditions réelles

### Phase 2 — nina.fm-mixtaper (le plus long, étroitement lié à l'API)

1. Créer les 4 agents dans `nina.fm-mixtaper/.claude/agents/`
2. Slim `nina.fm-mixtaper/CLAUDE.md` → ~110L

### Phase 3 — nina.fm-faceb + nina.fm-website (stack Nuxt similaire, faire ensemble)

1. Créer agents pour faceb + website
2. Slim leurs CLAUDE.md respectifs

### Phase 4 — Workspace root

1. Slim `CLAUDE.md` workspace → ~90L (supprimer sections Vue/SolidJS/NestJS)
2. Créer `.claude/rules/` avec fichiers path-scoped
3. Créer `api-explorer` agent au niveau workspace

### Phase 5 — nina.fm-auth

1. Créer `nina.fm-auth/CLAUDE.md` minimal (~30L)

---

## 12. Résultat attendu

| Métrique                    | Avant                     | Après                                       | Économie |
| --------------------------- | ------------------------- | ------------------------------------------- | -------- |
| Tokens always-loaded (API)  | ~40 325                   | ~11 250                                     | **~72%** |
| Context budget pour le code | limité                    | +29 000 tokens libérés                      |          |
| Patterns disponibles        | toujours (coûteux)        | à la demande (gratuit si non-utilisé)       |          |
| Capacité cross-repo         | oui (workspace CLAUDE.md) | oui + améliorée (path rules + api-explorer) |          |

---

_Plan élaboré le 2026-03-17. Implémentation terminée le 2026-03-18._

## 13. Résultat réel

| Repo             | Avant      | Après    | Réduction | Agents                               |
| ---------------- | ---------- | -------- | --------- | ------------------------------------ |
| workspace        | 262L       | 88L      | -66%      | `api-explorer` + 4 rules path-scoped |
| nina.fm-api      | 400L       | 98L      | -75%      | 7 agents                             |
| nina.fm-mixtaper | 447L       | 108L     | -76%      | 4 agents                             |
| nina.fm-faceb    | 296L       | 88L      | -70%      | 1 agent                              |
| nina.fm-website  | 210L       | 74L      | -65%      | 2 agents                             |
| nina.fm-auth     | 0L         | 30L      | —         | —                                    |
| **Total**        | **1 615L** | **486L** | **-70%**  | **15 agents**                        |

**Tokens always-loaded** : ~40 000 → ~12 000 (~70% d'économie par conversation)
