---
description: Rappels clés pour nina.fm-website (Nuxt public SSR). Chargé automatiquement quand on touche des fichiers website depuis le workspace.
paths:
  - "nina.fm-website/**"
  - "!nina.fm-website/node_modules/**"
---

# Contexte nina.fm-website

**Stack :** Nuxt 4 + Vue 3 + Pinia + SSR + Shadcn/Reka UI

## Règles non-négociables

- App avec **SSR activé** — toujours vérifier `import.meta.client` pour les APIs browser
  - `window`, `document`, `navigator`, `EventSource`, `Audio`, `localStorage` : côté client uniquement
- `EventSource` (SSE) : dans `import.meta.client` ou `onMounted` — toujours `eventSource.close()` dans `onUnmounted`
- Stores Pinia : **setup syntax** uniquement — `defineStore('id', () => {...})`
- Thèmes : composants `themes/peak/components/` → préfixe `Peak`, `themes/vinyl/components/` → préfixe `Vinyl`
- `useRuntimeConfig()` pour les env vars — jamais `process.env` côté client
- Jamais `v-if` et `v-for` sur le même élément — utiliser `<template>` wrapper
