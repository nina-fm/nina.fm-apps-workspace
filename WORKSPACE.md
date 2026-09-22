# Nina.fm Workspace

Workspace de configuration Claude Code pour l'écosystème applicatif de Nina.fm.
Ce repo ne contient **pas** de code applicatif — uniquement la config Claude (CLAUDE.md, hooks, commandes, agents, rules) et les workflows CI réutilisables.

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

En mode Mixtaper, Face B ou Website, Claude lit `../nina.fm-api/` avec ses outils natifs pour les features cross-repo. Aucune confirmation n'est demandée à chaque lecture : le `settings.json` versionné de l'app déclare `../nina.fm-api` en `additionalDirectories` (voir « Accès à l'API », dans « Plugin nina »).

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
- **Lint, type-check, tests** :
  - **Hooks git husky**, dans les quatre apps : `commitlint` sur le message, `lint-staged` au commit, lint et type-check au push ; les tests au commit dans mixtaper et website, au push dans api et faceb. `/nina:pr` les relance avant de pousser
  - **CI** : sur chaque PR dans mixtaper, seulement au push sur `main` ailleurs (api#62, faceb#49, website#60)
  - **Hook Claude Code** : seul mixtaper en a un, qui passe ESLint sur chaque fichier écrit (`.claude/scripts/lint-on-write.sh`) ; aucun ne lance de type-check

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

Avant de toucher aux hooks, aux commandes ou à `bin/` : `plugins/nina/LESSONS.md` réunit les pièges du chantier (sessions `claude -p`, recette d'un hook, refus du classifieur du mode auto). Ils sont là plutôt que dans `.claude/rules/`, qui est relu à chaque requête de chaque session.

Contenu actuel :

- **Garde `.env`** : un hook `PreToolUse` sur `Read|Glob` qui refuse les fichiers `.env*` sauf `.env.example`.
- **Plan** : `bin/plan.sh` affiche le Project GitHub du repo, via un hook `SessionStart` (`startup|clear|compact`). Le numéro du Project vient de `NINA_PROJECT`, posé dans le `env` du `.claude/settings.json` du repo (`2` pour le workspace) ; le titre vient du Project. Sans `NINA_PROJECT`, sans `gh` ou hors ligne, le script reste muet. Une ligne « Signal » s'y ajoute quand « Maintenant » est vide, ou qu'il déborde : plus d'une epic, ou plus de 3 issues hors des sous-issues de l'epic ; c'est un signal, pas une règle bloquante. `bin/` du plugin est dans le PATH d'une session, et chaque écriture nomme le Project visé :
  - `plan.sh add <url> <Horizon>` range une issue (Status Todo et son Horizon) ;
  - `plan.sh start <url>` la démarre (In Progress et Maintenant), avec son epic en Maintenant — lancé par `/nina:task` à la création de la branche ;
  - `plan.sh move <url> <Horizon>` change son Horizon ; sur une epic, ses sous-issues ouvertes suivent ;
  - `plan.sh list` liste Maintenant, Ensuite et Plus tard en une ligne par issue, pour `/nina:plan`.

  Le parent d'une issue n'est pas dans `gh project item-list` : il se lit par `gh api …/parent` et `…/sub_issues`, ou par GraphQL. Une session garde le `NINA_PROJECT` du repo où elle a été lancée, même dans un sous-repo : depuis le workspace, une issue Mixtaper se range avec `NINA_PROJECT=1 plan.sh add …`.
- **Agent `nina:api-explorer`** (`agents/`) : contexte de `nina.fm-api` pour les apps — endpoints, format de réponse, auth. Il lit le code de l'API dans le repo frère `../nina.fm-api/` ; depuis une app, ce dossier est hors du projet, et ses lectures sont refusées tant que l'app ne l'ouvre pas (voir « Accès à l'API » ci-dessous).
- **Commandes communes** : `/nina:epic`, `/nina:task`, `/nina:pr`, `/nina:review`, `/nina:plan` (`commands/`, voir « Commandes Disponibles »). Tronc commun à tous les repos : elles passent par `gh`, et déduisent ce qui se déduit — le repo (`gh repo view`, `{owner}/{repo}` dans `gh api`), la branche par défaut, le nom du package et les scripts de vérification (`package.json`), l'usage de Changesets (`.changeset/config.json`). Ce qui est propre à une stack vient de la checklist du repo.

**Checklists du repo** : `.claude/checklists/review.md` et `.claude/checklists/task.md`, à la racine du repo (`git rev-parse --show-toplevel`). Chacune est facultative : la commande la lit si elle existe et s'en passe sinon. Elles sont hors de `.claude/rules/`, qui se charge à chaque session, car elles ne servent qu'à la commande.

- **Contenu** : seulement ce que le tronc commun ne couvre pas — architecture cible, conventions du framework, dettes suivies. Ne pas y recopier la checklist commune (TypeScript, tests, sécurité, langue, changeset, recette), qui vit dans la commande.
- **`review.md`** : des sections `#### <Domaine> (<fichiers visés>)` faites de cases `- [ ]`, en français. `/nina:review` les applique après les sections communes, aux fichiers qu'elles visent. Écrire d'abord ce que la case vise, le glob ensuite : une case rangée sous un glob plus étroit que sa portée est sautée en silence (mixtaper#65). Ce qui vise tout le repo va dans une section sans glob.
- **`task.md`** : des étapes de planification propres au repo (`### <Étape>`), déroulées par `/nina:task` après l'exploration du code. Une étape qui produit une section du plan donne son titre et son tableau (`#### Où va le code` et ses colonnes) : la section s'insère avant « Fichiers à créer ».

```markdown
<!-- .claude/checklists/review.md -->
#### Réactivité SolidJS (`.tsx`, `src/**/*.ts`)
- [ ] Signaux lus comme des fonctions (`session()`, pas `session`)

<!-- .claude/checklists/task.md -->
### Où va le code
Lire `docs/ARCHITECTURE.md` et placer chaque morceau de code avec sa table « Où va ce code ? ».
Section du plan : `#### Où va le code`, tableau `| Code | Destination |`.
```

**Activation** dans un repo, via son `.claude/settings.json` :

```json
{
  "extraKnownMarketplaces": {
    "nina.fm": { "source": { "source": "github", "repo": "nina-fm/nina.fm-apps-workspace" } }
  },
  "enabledPlugins": { "nina@nina.fm": true }
}
```

Ce bloc est le même partout. Ne pas y recopier le `env` du `settings.json` du workspace : `NINA_PROJECT` est propre à chaque repo.

**Accès à l'API**, dans le `.claude/settings.json` des apps qui appellent l'API (faceb, website, mixtaper) : `"permissions": { "additionalDirectories": ["../nina.fm-api"] }`, pour que `nina:api-explorer` y lise sans refus. Versionné et non dans `settings.local.json` : le chemin ne dépend que de la disposition des repos, imposée par `setup.sh`.

**Project du repo**, à part de l'activation : `"env": { "NINA_PROJECT": "<numéro>" }` seulement si le repo a **son propre** Project, dont il est le sujet. Valeurs : workspace `2` (Apps Workspace) ; mixtaper `1` (Mixtaper), posée par la PR mixtaper de #13 ; faceb `3` (Face B), par #9 ; website `4` (Website), par #10. api et auth n'en ont pas. Qu'un de leurs tickets figure dans un autre Project ne leur en donne pas un : sans `NINA_PROJECT`, rien ne s'affiche en début de session, et c'est voulu.

**Installation**, une fois par repo et par machine : la déclaration ne suffit pas. L'ouverture d'une session, interactive ou `-p`, enregistre la marketplace sans aucune invite, mais n'installe pas le plugin. `/plugin` le montre alors en erreur (`Plugin "nina" not cached …`), et la garde reste inactive. Depuis le repo, une session ayant déjà été ouverte :

```bash
claude plugin install nina@nina.fm --scope project   # idempotent
claude plugin list                                   # nina@nina.fm : Scope project, ✔ enabled
git checkout .claude/settings.json                   # install réordonne les clés du fichier
```

Ne pas passer par `claude plugin marketplace add` : la commande inscrit la marketplace dans les settings utilisateur, donc pour tous les projets. `claude plugin uninstall … --scope project` vide les deux déclarations du `settings.json` versionné.

**Distribution** : la marketplace est lue sur `main` depuis GitHub. Une modification du plugin n'atteint les repos qu'une fois mergée sur `main`. `plugin.json` ne porte pas de `version` : la version installée est le commit (`claude plugin list` affiche son SHA). Une `version` figerait le plugin tant qu'on oublierait de l'incrémenter.

Le merge ne se propage pas seul (mesuré au merge de #21) : après une nouvelle session, le workspace était toujours en `e31ee2927ba8` et la copie locale de la marketplace sur l'ancien commit. Dans chaque repo, après un merge du plugin :

```bash
claude plugin update nina@nina.fm --scope project   # rafraîchit la marketplace, ne touche pas settings.json
```

La mise à jour ne vaut que pour le repo où on la lance, et prend effet à la session suivante.

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

Les cinq repos de code sont clonés **dans** le workspace par `setup.sh`, et ignorés par son git (`nina.fm-*/`) ; ils sont décrits à part ci-dessous. Pour les quatre apps, seuls `CLAUDE.md`, `docs/` et `.claude/` sont listés. Seuls les fichiers versionnés figurent ; `settings.local.json`, propre à chaque machine, existe à côté de chaque `settings.json`.

```
~/Sites/nina/nina.fm-apps-workspace    ← Ce repo (nina.fm-apps-workspace)
├── CLAUDE.md                          ← Guidelines transversales, lues par toutes les sessions
├── WORKSPACE.md                       ← Ce fichier
├── Makefile                           ← Commandes dev (make dev, make dev-*)
├── docker-compose.dev.yml             ← Compose global (inclut api + auth)
├── .gitignore                         ← Ignore les repos de code
├── setup.sh                           ← Script d'installation sur nouvelle machine
├── .github/workflows/                 ← Workflows réutilisables (node-validate, release, cleanup)
├── .claude-plugin/
│   └── marketplace.json               ← Marketplace nina.fm
├── plugins/
│   └── nina/                          ← Plugin interne (voir « Plugin nina »)
│       ├── .claude-plugin/plugin.json
│       ├── LESSONS.md                 ← Pièges du chantier du plugin
│       ├── agents/                    ← api-explorer (nina:api-explorer)
│       ├── bin/                       ← plan.sh, review-diff.sh et leurs tests (dans le PATH des sessions)
│       ├── commands/                  ← /nina:epic, /nina:task, /nina:pr, /nina:review, /nina:plan
│       └── hooks/                     ← hooks.json, garde .env et son test
└── .claude/
    ├── rules/                         ← lessons.md
    └── settings.json                  ← Activation du plugin nina, NINA_PROJECT=2

nina.fm-api/                           ← Repo NestJS (son propre git)
├── CLAUDE.md
├── docs/                              ← Architecture, Docker, migrations, versioning…
└── .claude/
    ├── agents/                        ← Agents du repo (modules, fichiers Bruno)
    ├── checklists/                    ← task.md, review.md (lues par /nina:task, /nina:review)
    ├── commands/                      ← /arch-context, /new-migration
    ├── rules/                         ← lessons.md
    └── settings.json                  ← Activation du plugin nina, permissions (lint, type-check, test)

nina.fm-mixtaper/                      ← Repo SolidJS (son propre git)
├── CLAUDE.md
├── docs/                              ← Architecture, auth, déploiement, transitions…
└── .claude/
    ├── agents/                        ← Agents du repo (features, composants, audio, tests)
    ├── checklists/                    ← task.md, review.md
    ├── commands/                      ← /recette, /sync-types
    ├── rules/                         ← Règles par dossier (components, features, routes, domain) + lessons.md
    ├── scripts/                       ← lint-on-write.sh (hook ESLint)
    └── settings.json                  ← Activation du plugin nina, NINA_PROJECT=1, hook PostToolUse ESLint

nina.fm-faceb/                         ← Repo Nuxt (son propre git)
├── CLAUDE.md
├── docs/                              ← Déploiement, permissions, SuperTokens ; archive/ : anciens plans
└── .claude/
    ├── agents/                        ← Agents du repo (features)
    ├── checklists/                    ← task.md, review.md
    ├── commands/                      ← /sync-types
    ├── rules/                         ← forms.md (formulaires), lessons.md
    └── settings.json                  ← Activation du plugin nina, NINA_PROJECT=3

nina.fm-website/                       ← Repo Nuxt (son propre git)
├── CLAUDE.md
├── docs/archive/                      ← Guides de migration PM2 → Docker
└── .claude/
    ├── checklists/                    ← task.md, review.md
    ├── rules/                         ← lessons.md
    └── settings.json                  ← Activation du plugin nina, NINA_PROJECT=4

nina.fm-auth/                          ← Repo infra SuperTokens (son propre git)
├── CLAUDE.md
├── README.md
├── QUICK_START.md
├── docs/                              ← Architecture, déploiement, RBAC, workflows…
├── docker-compose.dev.yml             ← SuperTokens core + postgres dédié
├── docker-compose.prod.yml
├── Makefile
└── .claude/
    └── settings.json                  ← Activation du plugin nina
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

Servies par le plugin nina dans tout repo qui l'active :

| Commande                           | Description                                                                                                                                                                                                  |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/nina:task #N` ou `"description"` | Recette de constat, exploration et plan d'implémentation ; la branche, proposée dans le plan, est créée après approbation. Avec une issue, lit ses commentaires, son epic et ses bloqueurs, et nomme la branche d'après son titre. Applique `.claude/checklists/task.md`. Démarre l'issue dans le Project (`plan.sh start`). |
| `/nina:epic #N` ou `"description"` | Explore et découpe une grande fonctionnalité ; une fois le découpage approuvé, crée les sous-issues, leurs dépendances, et les range dans le Project (`NINA_PROJECT`) à l'Horizon de l'epic.                                       |
| `/nina:pr`                         | Vérifications déduites de `package.json`, changeset si le repo utilise Changesets, push avec upstream, `gh pr create`. Signale l'epic dont la PR ferme la dernière sous-issue ouverte.                          |
| `/nina:plan`                       | Revue du plan, au signal de `plan.sh` ou à la fermeture d'une epic : propose de monter, garder, descendre ou fermer chaque issue de Maintenant, Ensuite et Plus tard, puis applique ce qui est tranché.       |
| `/nina:review [N]`                 | Review du diff (PR `N` ou branche courante) avec la checklist commune et `.claude/checklists/review.md` ; avec `N`, publiée par `gh pr comment`.                                                              |

Commandes locales, dans le `.claude/commands/` de leur repo :

| Commande         | Repo            | Description                                                         |
| ---------------- | --------------- | ------------------------------------------------------------------- |
| `/arch-context`  | api             | Charge le contexte d'architecture (`docs/ARCHITECTURE.md`)          |
| `/new-migration` | api             | Crée une migration TypeORM                                          |
| `/recette`       | mixtaper        | Protocole de recette dans le navigateur (instrumentation Web Audio) |
| `/sync-types`    | mixtaper, faceb | Regénère le client API depuis le schéma OpenAPI de nina.fm-api      |

## Workflow Agentique (rappel)

```
1. /nina:epic "grande feature"     (optionnel, si périmètre large)
   → Décomposition en sous-issues → tu valides → issues rangées dans le plan

2. /nina:task #N
   → Recette de constat + plan d'implémentation → tu valides / corriges

3. Agent implémente
   → ESLint à chaque écriture dans mixtaper (hook Claude Code) ; partout, husky : commitlint, lint-staged au commit, lint + type-check au push, tests au commit ou au push selon le repo

4. /nina:pr
   → Vérifications + création PR(s) sur les repos impactés

5. /nina:review N
   → Review IA du diff → commentaire structuré sur la PR

6. Tu valides la PR → merge → déploiement automatique (GitHub Actions)

7. /nina:plan                      (au signal du plan, ou à la fermeture d'une epic)
   → Revue des Horizons → tu tranches → plan.sh move applique
```
