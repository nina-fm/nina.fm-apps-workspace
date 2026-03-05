# Nina.fm Workspace

Workspace de configuration Claude Code pour l'écosystème Nina.fm.
Ce repo ne contient **pas** de code applicatif — uniquement la config Claude (CLAUDE.md, MCP, hooks, skills, memory).

---

## Écosystème

| Repo | Stack | Rôle | Port local |
|------|-------|------|-----------|
| `nina.fm-api` | NestJS 11 + TypeORM + PostgreSQL | API partagée (auth, sessions, fichiers…) | 4000 |
| `nina.fm-mixtaper` | SolidJS + SolidStart | App de création de mixtapes | 3000 |
| `nina.fm-faceb` | Nuxt 4 | Backoffice admin | 3001 |
| `nina.fm-website` | Nuxt 4 | Site public / radio | 3002 |

Toutes les apps partagent l'authentification SuperTokens via `nina.fm-api`.

---

## Dev Modes

Le "dev mode" = le répertoire depuis lequel tu lances Claude Code.
Claude lit les CLAUDE.md en cascade (répertoire courant → racine).

```bash
# Mode Mixtaper (feature front + API mix-sessions)
cd ~/Sites/nina/nina.fm-mixtaper && claude

# Mode API seule (infra, auth, autres modules)
cd ~/Sites/nina/nina.fm-api && claude

# Mode Face B (backoffice)
cd ~/Sites/nina/nina.fm-faceb && claude

# Mode Website
cd ~/Sites/nina/nina.fm-website && claude

# Mode global (décisions archi cross-repo, refactors)
cd ~/Sites/nina && claude
```

En mode Mixtaper, le filesystem MCP donne accès à `nina.fm-api/` pour les features cross-repo.

---

## Scope Mixtaper dans l'API

Pour les features Mixtaper, seuls ces modules NestJS sont concernés :

| Module | Accès |
|--------|-------|
| `mix-sessions/` | ✅ Toucher librement |
| `types/` | ✅ Types TS spécifiques Mixtaper |
| `files/` (partie audio) | ⚠️ Uniquement `audio-files.*` |
| `auth/`, `users/`, `common/` | 🔒 Shared — ne modifier que si explicitement nécessaire |
| `mixtapes/`, `djs/`, `tags/`, `stream/`, `invitations/` | 🚫 Autres apps — ne jamais toucher pour Mixtaper |

---

## Conventions Cross-Repo

- **Conventional Commits** dans tous les repos : `type(scope): description`
- **TypeScript strict** : pas de `any` dans le nouveau code — `unknown` + type guards
- **Coverage minimum** : 80% global (avec exceptions explicites pour fichiers non-testables)
- **Bruno files** : toujours mis à jour après une modification d'endpoint API
- **Squash merge** sur `main` / `master` — historique détaillé dans les PRs
- **Lint + type-check** : automatiques via hooks Claude Code à chaque édition

---

## MCP Servers

Configurés dans `.mcp.json` :

| MCP | Rôle |
|-----|------|
| `filesystem` | Accès à `~/Sites/nina/` pour navigation cross-repo |
| `github` | Branches, PRs, reviews (nécessite `GITHUB_PERSONAL_ACCESS_TOKEN`) |
| `context7` | Docs à jour : SolidJS, NestJS, TypeORM, Vite, Vitest |

---

## Structure de ce Workspace

```
~/Sites/nina/                          ← Ce repo (nina.fm-workspace)
├── WORKSPACE.md                       ← Ce fichier
├── .gitignore                         ← Ignore les repos de code
├── .mcp.json                          ← Config MCP partagée
├── setup.sh                           ← Script d'installation sur nouvelle machine
└── .claude/
    ├── commands/                      ← Skills disponibles depuis tous les repos
    │   ├── feature.md                 ← /feature — démarrer une feature (Phase 3)
    │   ├── pr.md                      ← /pr — créer une PR (Phase 3)
    │   └── review.md                  ← /review — review IA (Phase 5)
    └── memory/
        └── ecosystem.md               ← Mémoire persistante de l'écosystème

nina.fm-api/                           ← Repo NestJS (son propre git)
├── CLAUDE.md
└── .claude/
    ├── settings.json                  ← Hooks qualité
    └── memory/
        └── architecture.md

nina.fm-mixtaper/                      ← Repo SolidJS (son propre git)
├── CLAUDE.md
└── .claude/
    ├── settings.json                  ← Hooks qualité
    └── memory/
        └── architecture.md

nina.fm-faceb/                         ← Repo Nuxt (son propre git)
└── CLAUDE.md                          ← À créer quand besoin

nina.fm-website/                       ← Repo Nuxt (son propre git)
└── CLAUDE.md                          ← À créer quand besoin
```

---

## Installation sur une Nouvelle Machine

```bash
# 1. Cloner le workspace (crée ~/Sites/nina/ avec la config)
mkdir -p ~/Sites/nina
git clone git@github.com:YOUR_ORG/nina.fm-workspace.git ~/Sites/nina

# 2. Cloner les repos de code
cd ~/Sites/nina
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

## Workflow Agentique (rappel)

```
1. /feature "description de la feature"
   → Plan mode : agent analyse codebase + propose plan
   → Tu valides / corriges

2. Agent implémente dans un worktree isolé (branche auto)
   → Hooks qualité : lint + type-check automatiques

3. /pr
   → Qualité finale + création PR(s) sur les repos impactés

4. /review
   → Agent review du diff → commentaire structuré sur la PR

5. Tu valides la PR → merge → déploiement automatique (GitHub Actions)
```
