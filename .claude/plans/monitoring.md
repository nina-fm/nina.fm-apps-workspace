# Plan Monitoring — Nina.fm

> Objectif : visibilité rapide sur la santé des repos et centralisation des métriques, 100% gratuit.

---

## Phase 1 — Badges dans les READMEs

Chaque repo affiche ses métriques clés directement sur GitHub, sans ouvrir d'outil externe.

### Badges cibles (par repo)

| Badge | Source | Repos concernés |
|---|---|---|
| `version` | shields.io → `package.json` | api, faceb, website, mixtaper |
| `tests` (passed/failed) | Codecov | api, faceb, website, mixtaper |
| `coverage` | Codecov | api, faceb, website, mixtaper |
| `build` | GitHub Actions natif | api, faceb, website, mixtaper |

### Prérequis

- [ ] Créer un compte Codecov et connecter l'organisation GitHub `nina-fm`
- [ ] Free tier Codecov : repos privés illimités, **250 uploads/mois** (= 250 runs CI qui uploadent du coverage)
  - Avec 2 repos testés (api + mixtaper) et une activité normale → ~8 uploads/jour max → suffisant
  - Optimisation : uploader uniquement sur `main` (pas les feature branches) pour limiter la consommation

### Reusable workflow Codecov

Le step coverage est identique sur api et mixtaper → **mutualiser en reusable workflow** dans chaque repo.

Créer `.github/workflows/coverage.yml` :
```yaml
on:
  workflow_call:
    inputs:
      test-command:
        type: string
        default: 'pnpm test:cov'
      lcov-path:
        type: string
        default: './coverage/lcov.info'
      upload-on-branch:   # limiter aux pushes sur main pour économiser les uploads
        type: string
        default: 'main'
    secrets:
      CODECOV_TOKEN:
        required: true

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: ${{ inputs.test-command }}
      - uses: codecov/codecov-action@v4
        if: github.ref == format('refs/heads/{0}', inputs.upload-on-branch)
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ${{ inputs.lcov-path }}
```

Appelé depuis la CI principale :
```yaml
coverage:
  uses: ./.github/workflows/coverage.yml
  with:
    test-command: 'pnpm test --coverage'  # adapter par repo
    lcov-path: './coverage/lcov.info'
  secrets: inherit
```

### Étapes par repo

#### `nina.fm-api` (NestJS + Jest/Vitest)

1. Créer `.github/workflows/coverage.yml` (reusable, voir ci-dessus)
2. Appeler le workflow depuis `ci.yml`
3. S'assurer que les tests génèrent un rapport LCOV (`--coverage --reporter=lcov`)
4. Ajouter les badges dans `README.md` :
   ```md
   [![Version](https://img.shields.io/github/package-json/v/nina-fm/nina.fm-api)](...)
   [![Tests](https://codecov.io/gh/nina-fm/nina.fm-api/branch/main/graphs/badge.svg?type=tests)](...)
   [![Coverage](https://codecov.io/gh/nina-fm/nina.fm-api/branch/main/graph/badge.svg)](...)
   [![Build](https://github.com/nina-fm/nina.fm-api/actions/workflows/ci.yml/badge.svg)](...)
   ```

#### `nina.fm-website` (Nuxt 4 + Vitest)

Même reusable workflow — tests dans `app/lib/`, adapter `test-command` selon la config Vitest.

#### `nina.fm-mixtaper` (SolidJS + Vitest)

Même reusable workflow — adapter `test-command` selon la config Vitest (`pnpm vitest run --coverage`).

#### `nina.fm-faceb` (Nuxt 4 + Vitest)

Même reusable workflow — tests dans `app/lib/`, adapter `test-command` selon la config Vitest.

#### `nina.fm-faceb` et `nina.fm-website` (Nuxt 4)

Badges build + version + license uniquement (pas de tests unitaires à ce stade) :
```md
[![Build](https://github.com/nina-fm/nina.fm-faceb/actions/workflows/ci.yml/badge.svg)](...)
[![Version](https://img.shields.io/github/package-json/v/nina-fm/nina.fm-faceb)](...)
[![License](https://img.shields.io/badge/license-MIT-blue)](...)
```

### Notes

- Le badge `version` via `shields.io/github/package-json/v/{owner}/{repo}` fonctionne pour les **repos publics** sans config. Pour les repos privés, il faut un token shields.io ou passer par le badge Codecov (qui lui a accès via token CI).
- Le badge `build` GitHub Actions est accessible publiquement même sur repo privé (affiche "no status" si non authentifié) — suffisant pour une lecture en étant connecté à GitHub.

---

## Phase 2 — Centralisation sur Grafana Cloud

Un seul dashboard pour logs, métriques, errors, CI failures, coverage.

**Approche** : UptimeRobot, Sentry et Grafana Loki ont déjà été initiés sur `nina.fm-api`. La Phase 2 consiste à finaliser et valider une config complète sur api, puis à la répliquer sur faceb, website et mixtaper.

### Free tier Grafana Cloud

| Ressource | Limite gratuite |
|---|---|
| Logs (Loki) | 10 GB / mois |
| Métriques (Prometheus) | 10 000 series actives |
| Traces (Tempo) | 50 GB / mois |
| Utilisateurs | 3 |

### Architecture cible

```
nina.fm-api ──(winston-loki)──► Loki
nina.fm-api ──(prom-client)───► Prometheus
nina.fm-api ──(Sentry SDK)────► Sentry ──(datasource)──► Grafana
faceb/website/mixtaper ────────(Sentry SDK)──────────────────┤
                                                              │
GitHub Actions ────────────────(plugin datasource)───────────┤
Codecov ───────────────────────(via metrics API CI step)─────┤
                                                              ▼
                                                      Dashboard unifié
```

### Étape 1 — Finaliser sur `nina.fm-api` (pilote)

Déjà en place (à compléter/valider) : UptimeRobot, Sentry, Grafana Loki.

Reste à faire :
- [ ] Valider que les logs winston-loki arrivent correctement dans Loki
- [ ] Valider que Sentry capture bien les erreurs NestJS
- [ ] Métriques Prometheus : vérifier/compléter (`@willsoto/nestjs-prometheus`, latence, erreurs par route)
- [ ] Plugin datasource **GitHub** dans Grafana (CI failures)
- [ ] Coverage trend : step CI qui pousse le % vers Grafana Metrics API
- [ ] Dashboard final avec tous les panels (logs, errors, métriques, CI, coverage)

Panels cibles :
- Logs en temps réel (Loki, filtrable par app)
- Error rate (Sentry)
- Latence API P50/P95 (Prometheus)
- Health checks (Prometheus / UptimeRobot)
- CI status dernières 24h (GitHub datasource)
- Coverage trend (métriques custom)

### Étape 2 — Répliquer sur faceb, website, mixtaper

Une fois la config api validée et satisfaisante :

| App | Logs | Sentry SDK | Spécificités |
|---|---|---|---|
| `nina.fm-faceb` | à définir (Nuxt server logs ?) | `@sentry/nuxt` | SSR + client |
| `nina.fm-website` | à définir (Nuxt server logs ?) | `@sentry/nuxt` | SSR + client |
| `nina.fm-mixtaper` | N/A (SPA pure) | `@sentry/solidjs` | client uniquement |

> Les panels Grafana sont déjà prêts côté dashboard — il suffit d'ajouter les datasources et les labels `app` correspondants.

---

## Ordre d'implémentation recommandé

```
Phase 1 (badges)                        Phase 2 (Grafana)
────────────────────────────────────    ──────────────────────────────────
1. Codecov setup (compte + token)       5. Finaliser monitoring sur api (pilote)
2. Reusable workflow coverage           6. Valider dashboard Grafana complet
3. Step CI Codecov × 4 repos           7. Répliquer Sentry sur faceb/website/mixtaper
4. Badges README × 4 repos             8. Étendre dashboard (labels multi-app)
```

> Phases indépendantes — la Phase 1 peut être déployée sans attendre la Phase 2.
