# Nina.fm — Mémoire Écosystème

## Repos et leurs rôles

| Repo | Stack | Port | Rôle |
|------|-------|------|------|
| `nina.fm-api` | NestJS 11, TypeORM, PostgreSQL, Redis | 4000 | API partagée |
| `nina.fm-mixtaper` | SolidJS, SolidStart, Vite | 3000 | App mixtapes |
| `nina.fm-faceb` | Nuxt 4 | 3001 | Backoffice |
| `nina.fm-website` | Nuxt 4 | 3002 | Site public |

## Auth partagée
SuperTokens gère l'auth pour tous les frontends. L'API expose les endpoints SuperTokens.
- API : modules `auth/` + `supertokens/`
- Mixtaper : `supertokens-web-js` (intercepte automatiquement tous les fetch)
- Face B : idem

## Scope Mixtaper dans l'API NestJS
- `mix-sessions/` → cœur Mixtaper (sessions, tracks, ordering)
- `types/` → types TS Mixtaper (audio.types.ts, session.types.ts, error.types.ts)
- `files/audio-files.*` → upload et processing audio
- Tout le reste → infrastructure partagée ou autres apps

## Conventions partagées
- Conventional Commits : `feat(mix-sessions): add BPM sync`, `fix(audio-analysis): handle empty buffer`
- Squash merge sur main
- 80% coverage minimum (global, avec exceptions pour fichiers non-testables)
- Bruno files mis à jour à chaque modification d'endpoint API
- Pas de `any` dans le nouveau code TypeScript

## Déploiement
- Chaque repo a sa propre GitHub Actions pipeline
- Push sur `main` → build Docker → déploiement DigitalOcean
- Infrastructure : serveur Debian sur DigitalOcean

## Relations inter-repos
- Mixtaper consomme nina.fm-api (mix-sessions, files, auth, users)
- Face B consomme nina.fm-api (mixtapes, djs, tags, invitations, users, auth)
- Website consomme nina.fm-api (stream SSE pour metadata radio live)
- Types Mixtaper auto-générés dans nina.fm-mixtaper depuis l'OpenAPI de nina.fm-api (`pnpm types:sync`)
