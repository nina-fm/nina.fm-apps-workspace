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

## Architecture hexagonale (en cours de migration)

- **Domain entity** (`domain/[entity].entity.ts`) — pure TS, zéro TypeORM
- **Port repository** (`domain/[entity].repository.interface.ts`) — abstract class étendant `AbstractRepository<T>`
- **ORM entity** (`infrastructure/persistence/`) — entité TypeORM, séparée de la domain entity
- **Mapper** (`infrastructure/persistence/`) — `AbstractMapper<Domain, OrmEntity>`, `@Injectable()`
- **Wiring** : `{ provide: XxxRepository, useClass: XxxTypeormRepository }` dans le module
- Injection dans le service : `@Inject(XxxRepository)` — jamais `@InjectRepository()` sur le port

## Règles non-négociables

- `synchronize: false` TOUJOURS — migrations TypeORM uniquement
- `ConfigService` pour les env vars — jamais `process.env`
- Logique métier dans les **services** (et futurs use cases Phase 2+) — jamais dans les controllers
- Exceptions NestJS dans les **services** — jamais dans les controllers
- `private readonly` sur toutes les dépendances injectées
- Jamais `console.log` — `this.logger.log/warn/error()`
- Après chaque modification d'endpoint → mettre à jour `bruno/Nina.fm API/`
