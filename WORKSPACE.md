# Nina.fm Workspace

Workspace de configuration Claude Code pour l'écosystème applicatif de Nina.fm.
Ce repo ne contient **pas** de code applicatif — uniquement la config Claude (CLAUDE.md, hooks, commandes, agents, rules).

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

En mode Mixtaper, Claude lit `../nina.fm-api/` avec ses outils natifs pour les features cross-repo. Pour éviter la confirmation à chaque lecture, ajouter `Read(//<chemin absolu>/nina.fm-api/**)` dans son `settings.local.json`.

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
- **Merger une PR** : toujours `gh pr merge --squash --delete-branch <numéro>` — ne jamais merger manuellement avec `git merge` + `git push`, ce qui laisserait la PR ouverte sur GitHub et contournerait le processus de review
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

## GitHub

Aucun serveur MCP : branches, PRs, reviews, issues et Projects passent par la CLI `gh`, authentifiée une fois par `gh auth login`.

---

## Plugin nina

L'outillage Claude commun aux repos vit dans un plugin interne, `plugins/nina/`, servi par la marketplace `nina.fm` que déclare ce repo (`.claude-plugin/marketplace.json`).

Contenu actuel :

- **Garde `.env`** : un hook `PreToolUse` sur `Read|Glob` qui refuse les fichiers `.env*` sauf `.env.example`.
- **Plan** : `bin/plan.sh` affiche le Project GitHub du repo, via un hook `SessionStart` (`startup|clear|compact`). Le numéro du Project vient de `NINA_PROJECT`, posé dans le `env` du `.claude/settings.json` du repo (`2` pour le workspace) ; le titre vient du Project. Sans `NINA_PROJECT`, sans `gh` ou hors ligne, le script reste muet. `bin/` du plugin est dans le PATH d'une session : `plan.sh add <url> <Horizon>` range une issue dans le Project (Status Todo et son Horizon), et nomme le Project visé. Une session garde le `NINA_PROJECT` du repo où elle a été lancée, même dans un sous-repo : depuis le workspace, une issue Mixtaper se range avec `NINA_PROJECT=1 plan.sh add …`.

**Activation** dans un repo, via son `.claude/settings.json` :

```json
{
  "extraKnownMarketplaces": {
    "nina.fm": { "source": { "source": "github", "repo": "nina-fm/nina.fm-apps-workspace" } }
  },
  "enabledPlugins": { "nina@nina.fm": true },
  "env": { "NINA_PROJECT": "1" }
}
```

`env.NINA_PROJECT` seulement si le repo a un Project (`gh project list --owner nina-fm`).

**Installation**, une fois par repo et par machine : la déclaration ne suffit pas. L'ouverture d'une session, interactive ou `-p`, enregistre la marketplace sans aucune invite, mais n'installe pas le plugin. `/plugin` le montre alors en erreur (`Plugin "nina" not cached …`), et la garde reste inactive. Depuis le repo, une session ayant déjà été ouverte :

```bash
claude plugin install nina@nina.fm --scope project   # idempotent
claude plugin list                                   # nina@nina.fm : Scope project, ✔ enabled
git checkout .claude/settings.json                   # install réordonne les clés du fichier
```

Ne pas passer par `claude plugin marketplace add` : la commande inscrit la marketplace dans les settings utilisateur, donc pour tous les projets. `claude plugin uninstall … --scope project` vide les deux déclarations du `settings.json` versionné.

**Distribution** : la marketplace est lue sur `main` depuis GitHub. Une modification du plugin n'atteint les repos qu'une fois mergée sur `main`. `plugin.json` ne porte pas de `version` : la version installée est le commit (`claude plugin list` affiche son SHA). Une `version` figerait le plugin tant qu'on oublierait de l'incrémenter.

**Boucle de dev**, depuis le workspace, sur la branche en cours :

```bash
claude --plugin-dir plugins/nina                                  # charge le plugin local
bash plugins/nina/hooks/guard-env.test.sh                         # test de la garde .env
bash plugins/nina/bin/plan.test.sh                                # test de plan.sh (gh simulé)
claude plugin validate . && claude plugin validate plugins/nina   # structure
```

**Désigner un fichier du plugin** dans un hook ou une commande : `${CLAUDE_PLUGIN_ROOT}`, avec accolades. Il est substitué dans le texte d'une commande comme dans ses blocs `` !`…` ``. Sans accolades, `$CLAUDE_PLUGIN_ROOT` fait échouer le contrôle de permission d'un bloc `` !`…` ``.

---

## Structure de ce Workspace

```
~/Sites/nina/nina.fm-apps-workspace    ← Ce repo (nina.fm-apps-workspace)
├── WORKSPACE.md                       ← Ce fichier
├── Makefile                           ← Commandes dev (make dev, make dev-*)
├── docker-compose.dev.yml             ← Compose global (inclut api + auth)
├── .gitignore                         ← Ignore les repos de code
├── setup.sh                           ← Script d'installation sur nouvelle machine
├── .claude-plugin/
│   └── marketplace.json               ← Marketplace nina.fm
├── plugins/
│   └── nina/                          ← Plugin interne (voir « Plugin nina »)
│       ├── .claude-plugin/plugin.json
│       ├── bin/                       ← plan.sh et son test (dans le PATH des sessions)
│       └── hooks/                     ← hooks.json, garde .env et son test
└── .claude/
    ├── commands/                      ← Skills disponibles à la racine du workspace
    ├── agents/                        ← api-explorer
    ├── rules/                         ← lessons.md
    └── settings.json                  ← Activation du plugin nina, NINA_PROJECT=2

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
git clone git@github.com:nina-fm/nina.fm-apps-workspace.git ~/Sites/nina/nina.fm-apps-workspace

# 2. Cloner les repos de code
cd ~/Sites/nina/nina.fm-apps-workspace
git clone git@github.com:nina-fm/nina.fm-api.git
git clone git@github.com:nina-fm/nina.fm-mixtaper.git
git clone git@github.com:nina-fm/nina.fm-faceb.git
git clone git@github.com:nina-fm/nina.fm-website.git

# 3. Configurer les variables d'environnement
cp nina.fm-api/.env.example nina.fm-api/.env
cp nina.fm-mixtaper/.env.example nina.fm-mixtaper/.env
# → Éditer les fichiers .env avec les vraies valeurs

# 4. Installer les dépendances
cd nina.fm-api && pnpm install
cd ../nina.fm-mixtaper && pnpm install
# etc.

# 5. Authentifier la CLI GitHub (PRs, issues, Projects)
gh auth login
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
