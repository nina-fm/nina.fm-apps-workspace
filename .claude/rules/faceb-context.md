---
description: Rappels clés pour nina.fm-faceb (Nuxt backoffice CSR). Chargé automatiquement quand on touche des fichiers faceb depuis le workspace.
paths:
  - "nina.fm-faceb/app/**"
---

# Contexte nina.fm-faceb

**Stack :** Nuxt 4 + Vue 3 + TanStack Query + VeeValidate + Zod + Shadcn/Reka UI

## Règles non-négociables

- App **100% CSR** — SSR désactivé (`routeRules: { '/**': { ssr: false } }`)
  - Jamais `import.meta.server` (jamais exécuté), jamais `<ClientOnly>` (inutile)
  - **Exception** : `<Teleport>` doit toujours être dans `<ClientOnly>` même en CSR
- `credentials: 'include'` sur tous les `$fetch` — SuperTokens gère le refresh
- `baseURL: useRuntimeConfig().public.apiUrl` — jamais d'URL hardcodée
- Unwrapper `.data` — réponses API wrappées dans `{ data: T }`
- Query keys TOUJOURS dans `composables/query-keys.ts` — jamais de string inline
- `app/types/` = auto-généré — ne jamais modifier manuellement (`pnpm types:sync`)
