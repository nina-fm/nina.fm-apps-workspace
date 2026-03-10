# CLAUDE.md — nina.fm-apps-workspace

Guidelines globales pour tous les repos du workspace Nina.fm.
Ces règles s'appliquent à toutes les stacks (NestJS, Nuxt, SolidJS…) sauf mention contraire.

> Ce fichier est lu en **cascade** par Claude depuis n'importe quel repo du workspace.
> Voir `WORKSPACE.md` pour l'infrastructure, l'écosystème et le workflow git.

---

## Principes d'Architecture

### Séparation Métier / UI

**La logique métier ne vit jamais dans les composants UI.**

```
Logique métier        ← fonctions pures, classes, services — testables sans framework
      ↓
Couche d'état         ← store Pinia / signaux SolidJS / service NestJS injectable
      ↓
Hooks / Composables   ← orchestration état ↔ composant, side effects
      ↓
Composant UI          ← props in, events out — affichage uniquement
```

- Les composants **dumb** (UI) reçoivent des props, émettent des events — ils ne connaissent pas les stores ni l'API
- Les composants **smart** (composites/containers) orchestrent les hooks/composables — ils ne font pas de rendu complexe
- Tout ce qui peut être extrait **doit** l'être : hooks, composables, middleware, services, utils

### Fonctions Pures et Classes Isolées

Toute logique extractable dans une fonction pure ou une classe DOIT l'être.

```typescript
// ✅ Logique isolée — testable sans framework, sans DOM
function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}:${s.toString().padStart(2, '0')}`
}

// ✅ Classe à responsabilité unique
class BpmDetectorService {
  detect(buffer: AudioBuffer): BpmResult { ... }
}

// ❌ Logique métier dans un composant
const TrackItem = ({ seconds }) => {
  const formatted = `${Math.floor(seconds / 60)}:${...}` // ← extraire
}
```

Une fonction pure = sans side effects, sans dépendances framework, testable directement avec `expect(fn(input)).toBe(output)`.

### Architecture Feature-Based

**Organiser par domaine fonctionnel, pas par type technique.**

```
# ❌ Organisation par type (à éviter)
components/
  DjCard.vue
  MixtapeList.vue
hooks/
  useDj.ts
  useMixtape.ts

# ✅ Organisation par feature
components/
  djs/          ← composants du domaine DJs
    DjCard.vue
    DjAvatar.vue
  mixtapes/     ← composants du domaine Mixtapes
    MixtapeList.vue
    MixtapeCard.vue
hooks/          ← (ou composables/)
  djs/
    useDjForm.ts
    useDjList.ts
  mixtapes/
    useMixtape.ts
lib/            ← logique métier pure, par domaine
  djs/
    formatDj.ts
    formatDj.test.ts
  mixtapes/
    sortMixtapes.ts
```

**Règles :**
- Chaque feature est un dossier nommé par domaine : `audio/`, `djs/`, `auth/`, `session/`…
- Les fichiers d'un domaine (composants, hooks, types, utils, tests) sont **co-localisés** dans ce dossier
- `components/ui/` — primitives UI partagées uniquement (Shadcn, Kobalte…)
- `components/common/` — composants **vraiment** cross-feature (layout, navigation globale…)
- Si une feature grossit, lui donner son propre sous-dossier structuré — ne pas aplatir

Pour NestJS, c'est le pattern module natif : chaque module = une feature.

### Composants Minimalistes

- Un composant UI = props + template + events. Pas de logique métier, pas d'appels API directs.
- Si un composant dépasse ~100 lignes de template ou contient de la logique non-triviale, extraire.
- Préférer la **composition** (primitives + composites) à l'accumulation dans un seul composant.

---

## TypeScript

`strict: true` dans tous les repos. Zéro `any` dans le nouveau code.

```typescript
// ✅ Error handling universel
} catch (error: unknown) {
  const message = error instanceof Error ? error.message : 'Erreur inconnue'
  // log + handle
}

// ✅ Type guard pour les données externes (API, events, localStorage)
function isApiError(e: unknown): e is { statusCode: number; message: string } {
  return typeof e === 'object' && e !== null && 'statusCode' in e
}

// ❌ Jamais dans le nouveau code
} catch (error: any) { ... }
const data: any = response
```

- Types de retour explicites sur toutes les fonctions/méthodes **publiques**
- `??` (nullish coalescing) plutôt que `||` pour les valeurs par défaut
- `unknown` + type guards pour tout ce qui vient de l'extérieur
- `readonly` sur les dépendances injectées (NestJS) et les refs non-mutables

---

## Tests

### Philosophie

**Tester intelligemment, pas exhaustivement.** L'objectif est la maintenabilité et la non-régression — pas le coverage pour le coverage.

Ce qui **vaut** la peine d'être testé :
- La logique métier isolée (fonctions pures, transformations, cas limites)
- Les cas d'erreur et les branches critiques
- Les contrats publics des services/stores consommés par d'autres modules
- Les comportements qui ont déjà régressé

Ce qui **ne vaut pas** la peine d'être testé :
- Les composants purement UI sans logique
- Les getters/setters triviaux sans transformation
- Les wrappers de une ligne

**Ajouter des tests quand on constate qu'ils manquent** — pas besoin d'attendre une feature dédiée.

### Règles Universelles

```typescript
// ✅ Nommage obligatoire
it('should throw NotFoundException when session does not exist', ...)
it('should return false when track has no BPM', ...)

// ❌ Nommage interdit
it('works', ...)
it('test 1', ...)
```

- **Pas de snapshot tests** — fragiles, peu informatifs, difficiles à maintenir
- **Coverage 80% minimum** global (avec exceptions explicites pour fichiers non-testables : config, migrations, DTOs simples)
- Tests **co-localisés** avec la source : `my-service.test.ts` ou `my-service.spec.ts`
- **Factory helpers** pour les objets complexes : `createMockTrack()`, `createMockSession()`
- Mocks uniquement sur les **dépendances externes** (DB, HTTP, filesystem) — pas sur la logique métier elle-même
- Tests unitaires en priorité, fonctionnels si nécessaire, e2e pour les parcours critiques

---

## Front-end (Vue 3 / SolidJS)

### Architecture Composants

```
Page / Route
  └── Composant composite (smart)
        ├── useXxx() / composable / hook  ← orchestration état + side effects
        │     └── Store / Context         ← état global
        └── Composant UI (dumb)           ← affichage, props, events
```

### Gestion d'État

- État dérivé = `computed()` / `createMemo()` — jamais une variable locale recalculée à chaque render
- Side effects dans `watch()` / `createEffect()` — jamais pour calculer une valeur
- Mutations d'état via **actions/setters explicites** — jamais directement depuis les composants

### Règles Communes Vue 3 + SolidJS

- `cn()` (clsx + tailwind-merge) pour les classes Tailwind conditionnelles
- Icônes Lucide : imports **tree-shakeable** obligatoires — jamais d'import global
- Composants UI primitifs (Shadcn / Kobalte) avant d'en créer de nouveaux
- Props typées explicitement, callbacks préfixés `on`, handlers locaux préfixés `handle`
- `defineProps<T>()` / `defineEmits<T>()` avec types génériques (Vue) — jamais options API
- `interface XxxProps` explicite pour chaque composant (Solid)

---

## Back-end (NestJS)

### Couches

```
Controller   ← Routes, Swagger, validation entrée, format réponse { data: T }
  └── Service    ← Logique métier, exceptions NestJS
        └── Repository / Entity  ← Accès données TypeORM
```

- **Toute la logique métier dans les Services** — controllers = déléguer + formater + documenter
- `private readonly logger = new Logger(ClassName.name)` dans chaque service/controller
- Jamais `console.log` — toujours `this.logger.log/warn/error()`
- Exceptions NestJS levées dans les **services** (pas dans les controllers) : `NotFoundException`, `BadRequestException`, `ForbiddenException`, `ConflictException`

### Conventions

- Réponses wrappées : `{ data: T }` pour une ressource, `{ data: T[], pagination: ... }` pour une liste paginée
- `synchronize: false` toujours sur TypeORM — migrations uniquement, jamais d'auto-sync
- `ConfigService` pour les variables d'environnement — jamais `process.env` direct
- `readonly` obligatoire sur toutes les dépendances injectées

---

## Par Framework

### Nuxt 4 — `nina.fm-faceb` · `nina.fm-website`

- `srcDir: 'app'` — structure obligatoire
- Variables d'env runtime : `useRuntimeConfig()` — jamais `process.env` côté client
- Path aliases : `~` et `@` → racine du projet
- Stores Pinia : setup syntax (`defineStore('id', () => {...})`) — jamais options API
- **Voir le CLAUDE.md du repo** pour les patterns spécifiques (SSR vs CSR, TanStack Query, Pinia, SSE…)

### SolidJS — `nina.fm-mixtaper`

- Signaux appelés comme des fonctions : `value()` — jamais accédés comme propriétés
- `Show` pour le conditionnel, `For` pour les listes — pas de ternaires/`.map()` en JSX
- `createMemo()` pour les dérivations — jamais de calcul inline dans le return JSX
- **Voir le CLAUDE.md du repo** pour les patterns Context/Store/Hooks/Services

### NestJS — `nina.fm-api`

- Pattern Module → Controller → Service → Entity + DTO
- DTOs : décorateurs `class-validator` + `@ApiProperty()` sur chaque champ exposé
- `PartialType(CreateDto)` pour les Update DTOs
- **Voir le CLAUDE.md du repo** pour les patterns complets (auth, migrations, Bruno files…)
