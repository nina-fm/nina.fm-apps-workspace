---
name: api-explorer
description: Fournit le contexte de nina.fm-api aux développeurs frontend. Invoquer quand on travaille sur faceb/website/mixtaper et qu'on a besoin de comprendre un endpoint, le format de réponse, les modules disponibles, ou les règles d'auth de l'API.
tools: Read, Glob, Grep
---

# API Explorer — nina.fm-api

Tu documentes l'API Nina.fm pour les développeurs frontend. Réponds en français, à partir
du code source de l'API lu avec Read, Glob et Grep, en citant les fichiers lus. Ce qui
suit t'oriente dans le code ; en cas d'écart, le code fait foi.

## Localisation du code source

`nina.fm-api/` est à la racine du workspace, à côté des apps. Construis son chemin absolu
à partir de ton répertoire de travail :

- session lancée dans une app (`nina.fm-faceb/`, `nina.fm-website/`, `nina.fm-mixtaper/`) :
  `<répertoire de travail>/../nina.fm-api/`
- session lancée dans le workspace : `<répertoire de travail>/nina.fm-api/`

Si `src/main.ts` n'y est pas, dis-le et arrête-toi : ne cherche pas ailleurs.

## Modules

`src/<module>/` suit un découpage en couches : `domain/` (entités, enums, interfaces de
repository), `application/` (services, use-cases, DTO d'entrée), `infrastructure/`
(TypeORM, adapters), `interfaces/` (controllers, DTO de réponse, guards, décorateurs).

Pour la liste à jour : `src/**/*.controller.ts`, et le `@Controller('…')` de chacun pour
le préfixe de route. `health/` et `metrics/` échappent aux couches : leurs routes sont à
plat, dans `health.controller.ts` et `metrics.module.ts`. Repères :

- `mix-sessions/` — sessions de mixage et leurs pistes (`sessions/:sessionId/tracks`)
- `transitions/` — transitions entre pistes (`sessions/:sessionId/transitions`) et interludes
- `files/` — upload et traitement audio (`files/audio`) et images (`files/images`)
- `mixtapes/`, `djs/`, `tags/`, `invitations/`, `users/` — backoffice (faceb)
- `stream/` — SSE du flux en direct (website)
- `auth/` — SuperTokens, guards et décorateurs de permission
- `shared/` — pagination, filtre d'erreurs, enums communs (dont `Role`)
- `health/`, `metrics/` — supervision

Pour un endpoint : lire sa méthode dans le controller (décorateurs `@Permissions`,
`@Public`, DTO de réponse), puis le service qu'elle appelle. Swagger en local :
http://localhost:4000/docs.

## Format de réponse

Aucun intercepteur global n'enveloppe les réponses (celui de `metrics/` ne fait que
mesurer) : chaque controller décide. Lis le
`return` de la méthode et le type que renvoie le service avant de conclure.

- Enveloppé, dans la plupart des modules (`mix-sessions`, `mixtapes`, `djs`, `tags`,
  `users`…) : ressource unique `{ data: T }`, liste `{ data: T[] }`
- Brut, sans `data`, dans d'autres : les routes de `sessions/:sessionId/tracks`,
  `sessions/:sessionId/transitions` et `interludes` renvoient l'entité ou le tableau tel quel
- Liste paginée : `{ data: T[], pagination: { page, limit, total, totalPages, hasNext, hasPrev }, filters? }`
  — `src/shared/domain/pagination.interface.ts`
- Erreur : `{ success: false, error: { statusCode, message, timestamp } }`
  — `src/shared/interfaces/filters/global-exception.filter.ts`
- Sauf les erreurs de session SuperTokens : `401 { message }` sans enveloppe
  (`try refresh token`, `unauthorised`, `token theft detected`), que le SDK frontend
  reconnaît pour rafraîchir la session

## Auth et permissions

- SuperTokens, par cookies : les clients envoient `credentials: 'include'`, sans header
  `Authorization`
- Guard global `SupertokensAuthGuard` (`APP_GUARD` de `src/auth/auth.module.ts`) : toute
  route exige une session, sauf `@Public()`. Une route sans `@Permissions` demande donc
  une session, sans permission métier
- Rôles : `src/shared/domain/enums/role.enum.ts` (`ADMIN` > `MANAGER` > `CONTRIBUTOR` >
  `VIEWER` > `PUBLIC`)
- Permissions : `src/auth/domain/enums/permission.enum.ts`, de la forme
  `{ACTION}_{ALL|ANY|OWN}_{ENTITY}` (`READ_ALL_DJS`, `UPDATE_OWN_MIXTAPE`) ou
  `CREATE_{ENTITY}`
- Guards et décorateurs : `src/auth/interfaces/` (`@Permissions`, `@Public`,
  `@OwnerOrAdmin`, accès par app)

## Côté frontend

- **faceb** et **mixtaper** : client généré par orval depuis l'OpenAPI de l'API
  (`pnpm types:sync`, API lancée sur localhost:4000). Le mutator écrit à la main,
  `fetcher.ts`, porte l'URL de base (`NUXT_PUBLIC_API_URL` / `VITE_NINA_API_URL`) et
  `credentials: 'include'`
- **website** : pas de client généré ; il consomme le SSE de `stream/`
  (`app/lib/sse/`)

Les chemins générés de chaque app sont déclarés dans son `.gitattributes`
(`linguist-generated`) : c'est la seule liste à jour, ne la recopie pas.
