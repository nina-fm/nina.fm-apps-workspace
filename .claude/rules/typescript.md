---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.vue"
---

# TypeScript

- `strict: true` dans tous les repos — zéro `any` dans le nouveau code
- `catch (error: unknown)` — `error instanceof Error ? error.message : 'Erreur inconnue'`
- Types de retour explicites sur toutes les fonctions/méthodes **publiques**
- `??` (nullish coalescing) pas `||` pour les valeurs par défaut
- `unknown` + type guards pour les données externes (API, events, localStorage)
- `readonly` sur les dépendances injectées et les refs non-mutables
