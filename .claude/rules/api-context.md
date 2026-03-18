---
description: Rappels clés pour nina.fm-api (NestJS). Chargé automatiquement quand on touche des fichiers API depuis le workspace.
paths:
  - "nina.fm-api/src/**"
---

# Contexte nina.fm-api

**Stack :** NestJS 11 + TypeORM + PostgreSQL + SuperTokens + Redis

## Module Map — périmètre critique

- 🎛️ **Libre pour Mixtaper** : `mix-sessions/`, `types/`, `files/`
- 🔒 **Modifier uniquement si nécessaire** : `auth/`, `users/`, `supertokens/`, `common/`, `config/`, `health/`
- 🚫 **Ne jamais toucher pour Mixtaper** : `mixtapes/`, `djs/`, `tags/`, `invitations/`, `stream/`

## Règles non-négociables

- `synchronize: false` TOUJOURS — migrations TypeORM uniquement
- `ConfigService` pour les env vars — jamais `process.env`
- Logique métier dans les **services** uniquement
- Exceptions NestJS dans les **services** — jamais dans les controllers
- `private readonly` sur toutes les dépendances injectées
- Jamais `console.log` — `this.logger.log/warn/error()`
- Après chaque modification d'endpoint → mettre à jour `bruno/Nina.fm API/`
