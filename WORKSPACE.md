# Nina.fm Workspace

Workspace de configuration Claude Code pour l'écosystème applicatif de Nina.fm.
Ce repo ne contient **pas** de code applicatif — uniquement la config Claude (CLAUDE.md, MCP, hooks, skills, memory).

---

## Écosystème

| Repo               | Stack                            | Rôle                                     | Port local |
| ------------------ | -------------------------------- | ---------------------------------------- | ---------- |
| `nina.fm-api`      | NestJS 11 + TypeORM + PostgreSQL | API partagée (auth, sessions, fichiers…) | 4000       |
| `nina.fm-mixtaper` | SolidJS + SolidStart             | App de création de mixtapes              | 3000       |
| `nina.fm-faceb`    | Nuxt 4                           | Backoffice admin                         | 3001       |
| `nina.fm-website`  | Nuxt 4                           | Site public / radio                      | 3002       |
| `nina.fm-auth`     | SuperTokens (Docker)             | Service d'authentification (infra seule) | 3567       |

Toutes les apps partagent l'authentification SuperTokens via `nina.fm-api`.

> **Note :** `nina.fm-mixtaper` est hébergé sous `fugudesign/nina.fm-mixtaper` (pas sous l'org nina-fm).

---

## Dev Local — Lancer l'environnement

Depuis le workspace (`~/Sites/nina/nina.fm-apps-workspace`) :

```bash
make dev             # Lance l'infra Docker seule (postgres:5432, redis:6379, supertokens:3567)
make dev-mixtaper    # Infra + API (start:dev) + Mixtaper
make dev-faceb       # Infra + API (start:dev) + Face B
make dev-website     # Infra + API (start:dev) + Website
make dev-webradio    # Infra + API (start:dev) + Face B + Website
make dev-stop        # Arrête l'infra Docker
make dev-logs        # Logs en temps réel de l'infra
```

**Architecture :** L'infra (postgres, redis, supertokens) tourne en Docker. L'API NestJS tourne sur l'hôte via `pnpm start:dev` pour garder les logs accessibles et le hot-reload rapide.

**Fichiers Docker :**

- `docker-compose.dev.yml` (workspace) — compose toute l'infra de dev via `include`
- `nina.fm-api/infra/docker-compose.dev.yml` — postgres + redis dev
- `nina.fm-auth/docker-compose.dev.yml` — supertokens-postgres + supertokens-core
- `nina.fm-api/infra/docker-compose.yml` — infra prod (postgres + redis serveur)
- `nina.fm-api/docker-compose.yml` — API prod (déployée via CI)

## Dev Modes Claude

Le "dev mode" = le répertoire depuis lequel tu lances Claude Code.
Claude lit les CLAUDE.md en cascade (répertoire courant → racine).

```bash
# Mode Mixtaper (feature front + API mix-sessions)
cd ~/Sites/nina/nina.fm-apps-workspace/nina.fm-mixtaper && claude

# Mode API seule (infra, auth, autres modules)
cd ~/Sites/nina/nina.fm-apps-workspace/nina.fm-api && claude

# Mode Face B (backoffice)
cd ~/Sites/nina/nina.fm-apps-workspace/nina.fm-faceb && claude

# Mode Website
cd ~/Sites/nina/nina.fm-apps-workspace/nina.fm-website && claude

# Mode global (décisions archi cross-repo, refactors)
cd ~/Sites/nina/nina.fm-apps-workspace && claude
```

En mode Mixtaper, le filesystem MCP donne accès à `nina.fm-api/` pour les features cross-repo.

---

## Scope Mixtaper dans l'API

Pour les features Mixtaper, seuls ces modules NestJS sont concernés :

| Module                                                  | Accès                                                   |
| ------------------------------------------------------- | ------------------------------------------------------- |
| `mix-sessions/`                                         | ✅ Toucher librement                                    |
| `types/`                                                | ✅ Types TS spécifiques Mixtaper                        |
| `files/` (partie audio)                                 | ⚠️ Uniquement `audio-files.*`                           |
| `auth/`, `users/`, `common/`                            | 🔒 Shared — ne modifier que si explicitement nécessaire |
| `mixtapes/`, `djs/`, `tags/`, `stream/`, `invitations/` | 🚫 Autres apps — ne jamais toucher pour Mixtaper        |

---

## Conventions Cross-Repo

- **Package manager** : `pnpm` partout — jamais `npm` ou `yarn`
- **Conventional Commits** dans tous les repos : `type(scope): description`
- **TypeScript strict** : pas de `any` dans le nouveau code — `unknown` + type guards
- **Coverage minimum** : 80% global (avec exceptions explicites pour fichiers non-testables)
- **Bruno files** : toujours mis à jour après une modification d'endpoint API
- **Suppression automatique des branches au merge** : `delete_branch_on_merge` activé sur tous les repos GitHub nina-fm — à activer sur tout nouveau repo (GitHub Settings → General → "Automatically delete head branches")
- **Sync avant de tirer une branche** : toujours `git pull origin main` avant `git checkout -b` — une branche tirée depuis un `main` en retard pollue le diff de la PR avec des fichiers obsolètes
- **Squash merge** sur `main` / `master` — historique détaillé dans les PRs
- **Merger une PR via MCP** : toujours utiliser `mcp__github__merge_pull_request` avec `merge_method: "squash"` — ne jamais merger manuellement avec `git merge` + `git push`, ce qui laisserait la PR ouverte sur GitHub et contournerait le processus de review
- **Stacked PRs** : une PR peut pointer vers la branche de la PR précédente pour avoir un diff cohérent. **Au moment du merge d'une PR dans `main`**, mettre immédiatement à jour les PRs qui la référençaient pour qu'elles pointent vers `main` (GitHub "Edit" ou `git rebase main`).
- **Lint + type-check** : automatiques via hooks Claude Code à chaque édition

### Versioning avec Changesets

Tous les repos utilisent `@changesets/cli` avec `"commit": false`.

**Workflow :**

1. Avant de merger une PR avec un changement user-facing → `pnpm changeset` (crée un fichier `.changeset/*.md`)
2. Au merge sur `main`, le CI détecte les changesets et exécute `pnpm changeset:version` (bump `package.json` + génère `CHANGELOG.md`)
3. Le CI commite manuellement avec `chore: release vX.Y.Z [skip ci]` puis crée le tag Git

**En local** (si besoin d'appliquer manuellement) :

```bash
pnpm changeset:version        # Modifie package.json + CHANGELOG, sans commiter
git add -A
git commit -m "chore: release vX.Y.Z [skip ci]"
```

> `"commit": false` est obligatoire pour que le message reste conventionnel et passe commitlint.
> `[skip ci]` dans le message empêche le CI de se redéclencher sur le commit de release.

---

## MCP Servers

Configurés dans `.mcp.json` :

| MCP          | Rôle                                                                     |
| ------------ | ------------------------------------------------------------------------ |
| `filesystem` | Accès à `~/Sites/nina/nina.fm-apps-workspace` pour navigation cross-repo |
| `github`     | Branches, PRs, reviews (nécessite `GITHUB_PERSONAL_ACCESS_TOKEN`)        |
| `context7`   | Docs à jour : SolidJS, NestJS, TypeORM, Vite, Vitest                     |

---

## Structure de ce Workspace

```
~/Sites/nina/nina.fm-apps-workspace    ← Ce repo (nina.fm-apps-workspace)
├── WORKSPACE.md                       ← Ce fichier
├── Makefile                           ← Commandes dev (make dev, make dev-*)
├── docker-compose.dev.yml             ← Compose global (inclut api + auth)
├── .gitignore                         ← Ignore les repos de code
├── .mcp.json                          ← Config MCP partagée
├── setup.sh                           ← Script d'installation sur nouvelle machine
└── .claude/
    └── memory/                        ← Mémoire persistante (cross-session)

nina.fm-api/                           ← Repo NestJS (son propre git)
├── CLAUDE.md
└── .claude/
    ├── commands/                      ← Skills disponibles dans ce repo
    │   ├── task.md                    ← /task — plan d'implémentation
    │   ├── epic.md                    ← /epic — décomposition feature
    │   ├── pr.md                      ← /pr — qualité + création PR
    │   └── review.md                  ← /review — review IA
    ├── settings.json                  ← Hooks qualité (eslint .ts, type-check avant commit)
    ├── settings.local.json
    └── memory/
        ├── architecture.md
        ├── migrations.md
        └── workflow.md

nina.fm-mixtaper/                      ← Repo SolidJS (son propre git)
├── CLAUDE.md
└── .claude/
    ├── commands/                      ← Skills disponibles dans ce repo
    │   ├── task.md                    ← /task — plan d'implémentation
    │   ├── epic.md                    ← /epic — décomposition feature
    │   ├── pr.md                      ← /pr — qualité + création PR
    │   ├── review.md                  ← /review — review IA
    │   └── sync-types.md              ← /sync-types — regénère types API
    ├── settings.json                  ← Hooks qualité (eslint .ts/.tsx, type-check avant commit)
    ├── settings.local.json
    ├── worktrees/                     ← Git worktrees (Claude Code)
    └── memory/
        ├── architecture.md
        └── workflow.md

nina.fm-faceb/                         ← Repo Nuxt (son propre git)
├── CLAUDE.md
└── .claude/
    ├── commands/                      ← Skills disponibles dans ce repo
    │   ├── task.md                    ← /task — plan d'implémentation
    │   ├── epic.md                    ← /epic — décomposition feature
    │   ├── pr.md                      ← /pr — qualité + création PR
    │   ├── review.md                  ← /review — review IA
    │   └── sync-types.md              ← /sync-types — regénère types API
    ├── settings.json                  ← Hooks qualité (eslint .ts/.vue, type-check avant commit)
    └── settings.local.json

nina.fm-website/                       ← Repo Nuxt (son propre git)
├── CLAUDE.md
└── .claude/
    ├── commands/                      ← Skills disponibles dans ce repo
    │   ├── task.md                    ← /task — plan d'implémentation
    │   ├── epic.md                    ← /epic — décomposition feature
    │   ├── pr.md                      ← /pr — qualité + création PR
    │   └── review.md                  ← /review — review IA
    ├── settings.json                  ← Hooks qualité (eslint .ts/.vue, lint avant commit)
    └── settings.local.json

nina.fm-auth/                          ← Repo infra SuperTokens (son propre git)
├── README.md
├── QUICK_START.md
├── docker-compose.dev.yml             ← SuperTokens core + postgres dédié
├── docker-compose.prod.yml
└── Makefile
```

---

## Prérequis Versions

```bash
# pnpm v10 requis pour tous les repos (packageManager: pnpm@10.12.4)
corepack enable
corepack use pnpm@10.12.4   # ou: npm install -g pnpm@10
```

> ⚠️ La machine de dev doit tourner avec pnpm v10. Les hooks git (husky) et les installs pnpm échoueront silencieusement avec pnpm v9.

## Installation sur une Nouvelle Machine

```bash
# 1. Cloner le workspace (crée ~/Sites/nina/nina.fm-apps-workspace avec la config)
mkdir -p ~/Sites/nina/nina.fm-apps-workspace
git clone git@github.com:YOUR_ORG/nina.fm-apps-workspace.git ~/Sites/nina/nina.fm-apps-workspace

# 2. Cloner les repos de code
cd ~/Sites/nina/nina.fm-apps-workspace
git clone git@github.com:YOUR_ORG/nina.fm-api.git
git clone git@github.com:YOUR_ORG/nina.fm-mixtaper.git
git clone git@github.com:YOUR_ORG/nina.fm-faceb.git
git clone git@github.com:YOUR_ORG/nina.fm-website.git

# 3. Configurer les variables d'environnement
cp nina.fm-api/.env.example nina.fm-api/.env
cp nina.fm-mixtaper/.env.example nina.fm-mixtaper/.env
# → Éditer les fichiers .env avec les vraies valeurs

# 4. Installer les dépendances
cd nina.fm-api && pnpm install
cd ../nina.fm-mixtaper && pnpm install
# etc.

# 5. Configurer le GITHUB_PERSONAL_ACCESS_TOKEN pour le MCP GitHub
export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxxx
# → Ajouter à ~/.zshrc ou ~/.bashrc pour persistance

# 6. Installer les MCPs (la première fois)
npx -y @modelcontextprotocol/server-filesystem --help
npx -y @modelcontextprotocol/server-github --help
npx -y @upstash/context7-mcp --help
```

---

## Commandes Disponibles

Disponibles dans chaque repo via `.claude/commands/` :

| Commande              | Description                                                                                                                                                                                                                                                                |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/task "description"` | Analyse le codebase et crée un plan d'implémentation détaillé. Accepte un prefix Conventional Commit optionnel qui détermine le type de branche créée : `/task "feat: ..."`, `/task "fix: ..."`, `/task "refactor: ..."`, etc. Sans prefix, `feat` est utilisé par défaut. |
| `/epic "description"` | Explore et décompose une grande feature en sous-features actionnables                                                                                                                                                                                                      |
| `/pr`                 | Checks qualité finaux + création de la PR                                                                                                                                                                                                                                  |
| `/review`             | Review IA du diff → commentaire structuré sur la PR                                                                                                                                                                                                                        |
| `/sync-types`         | Regénère les types API depuis l'OpenAPI (mixtaper + faceb uniquement)                                                                                                                                                                                                      |

## Workflow Agentique (rappel)

```
1. /epic "grande feature"          (optionnel, si périmètre large)
   → Décomposition en sous-features → tu valides

2. /task "description de la feature"
   → Plan d'implémentation → tu valides / corriges

3. Agent implémente
   → Hooks qualité : lint + type-check automatiques à chaque édition

4. /pr
   → Qualité finale + création PR(s) sur les repos impactés

5. /review
   → Review IA du diff → commentaire structuré sur la PR

6. Tu valides la PR → merge → déploiement automatique (GitHub Actions)
```
