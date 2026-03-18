---
description: Rappels clés pour nina.fm-mixtaper (SolidJS DAW). Chargé automatiquement quand on touche des fichiers Mixtaper depuis le workspace.
paths:
  - "nina.fm-mixtaper/src/**"
---

# Contexte nina.fm-mixtaper

**Stack :** SolidJS + SolidStart + Vitest + Web Audio API + Essentia.js

## Architecture : Context → Store → Hooks → Components

Hooks existants à vérifier avant d'en créer un : `useSession`, `useFileUpload`, `useTrackOperations`, `useSessionPlayback`, `useTrackPlayback`, `useTrackAnalysis`, `useTrackListState`, `useTrackOrdering`, `useMixExport`, `useEditTrackDialog`, `useAudioShortcuts`

## Règles non-négociables

- **Lucide icons** : `import Trash2 from 'lucide-solid/icons/trash-2'` — jamais `import { Trash2 } from 'lucide-solid'`
- **Signaux** : toujours appelés comme fonctions — `session()`, jamais `session`
- **Analyse audio** (BPM/Key) : Web Worker obligatoire — jamais sur le thread principal
- **Upload multiple** : séquentiel (`for...of`) — jamais parallèle (`Promise.all`)
- `credentials: 'include'` sur tous les fetch
- `src/types/api/` = auto-généré — ne jamais modifier manuellement
- Framework de test : **Vitest** (`vi.*`) — jamais Jest
