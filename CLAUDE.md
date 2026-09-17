# CLAUDE.md — nina.fm-apps-workspace

Guidelines transversales pour tous les repos du workspace Nina.fm.

> Chaque repo a son propre CLAUDE.md pour les conventions stack-spécifiques.
> Voir `WORKSPACE.md` pour l'infrastructure, l'écosystème et le workflow git.

## TypeScript

- `strict: true` dans tous les repos — zéro `any` dans le nouveau code
- `catch (error: unknown)` — `error instanceof Error ? error.message : 'Erreur inconnue'`
- Types de retour explicites sur toutes les fonctions/méthodes **publiques**
- `??` (nullish coalescing) pas `||` pour les valeurs par défaut
- `unknown` + type guards pour les données externes (API, events, localStorage)
- `readonly` sur les dépendances injectées et les refs non-mutables

## Tests

Tester intelligemment, pas exhaustivement. Objectif : maintenabilité et non-régression.

**Tester :** logique métier isolée, cas d'erreur, contrats publics, régressions connues.
**Ne pas tester :** composants purement UI, getters triviaux, wrappers d'une ligne.

- Nommage : `it('should [comportement] when [condition]')` — jamais `it('works')`
- Pas de snapshot tests
- Coverage 80% minimum global (exceptions : config, migrations, DTOs simples)
- Co-localisation : `my-service.test.ts` ou `my-service.spec.ts`
- Factory helpers pour les objets complexes : `createMockTrack()`, `createMockSession()`
- Mocks uniquement sur les dépendances externes (DB, HTTP) — pas sur la logique métier
- Priorité : unitaires → fonctionnels → e2e (parcours critiques uniquement)

## Workflow d'implémentation

Pour toute implémentation multi-étapes : utiliser le skill `/task` pour analyser et planifier, puis créer des tasks (TaskCreate) pour suivre la progression étape par étape.

### Recette : avant de prendre un ticket, et avant de merger

Deux recettes encadrent tout ticket, dans l'app réelle — pas seulement dans les tests :

- **Recette de constat, avant de le prendre** : reproduire le défaut, ou constater
  l'absence de la fonctionnalité, sur `main`. On vérifie que le ticket est pertinent
  et toujours d'actualité ; un ticket qui ne se reproduit plus se commente et se
  ferme, il ne s'implémente pas.
- **Recette finale, avant de merger** : après l'implémentation, et de nouveau après
  chaque passe de retours de review. Rejouer le scénario du constat, plus le chemin
  nominal pour la non-régression. Les tests prouvent le code ; la recette prouve ce
  que l'utilisateur voit et entend — un test peut passer avec et sans le correctif.

Mesurer plutôt qu'observer (valeurs avant / après), et reporter les mesures dans la
PR. Toute donnée créée pour la recette est retirée à la fin, état d'origine vérifié.
Le protocole propre à chaque app vit dans son repo (ex. `/recette` dans mixtaper).

## Self-Improvement

Après toute correction ou erreur détectée : mettre à jour `.claude/rules/lessons.md` du repo concerné (ou du workspace si transversal) avec la leçon en une ligne concise. Ne pas attendre que l'utilisateur le signale.

## Workflow Git & GitHub

Ordre : recette de constat → plan mode → `git pull origin main && git checkout -b` → code → recette finale → changeset → commit → `git push --set-upstream origin <branch>` → `gh pr create` → review si demandée → recette finale après retours → merge

- **Merger une PR** : `gh pr merge --squash --delete-branch <numéro>` — jamais `git merge` + `git push`
- **Squash merge** sur `main` — un commit par PR, historique propre
- **Changeset obligatoire** avant tout merge `feat:` ou `fix:` — créer `.changeset/nom.md` manuellement (jamais `pnpm changeset`, interactif) ; jamais `[skip ci]` sur ce commit (le squash propage le tag)
- **Toujours `git push --set-upstream origin <branch>`** (pas juste `push`) — sans upstream, `gh pr create` échoue. Pas `-u` : rtk le retire et aucun upstream n'est posé, la forme longue passe
- **Sync avant de tirer une branche** : `git pull origin main` puis `git checkout -b`
- **Suppression automatique des branches** au merge (`delete_branch_on_merge` activé)
- Conventions → `CLAUDE.md` du repo — jamais dans `~/.claude/` sauf préférences personnelles
- **Après le merge d'une PR**, fusionner `main` dans les branches qui en descendent
  et vérifier `.changeset/` : un changeset déjà publié **survit au merge** quand son
  ajout et sa suppression ont eu lieu sur des branches distinctes (git voit « ajouté
  chez moi, absent chez eux » et le garde). Le laisser rejouerait la même entrée de
  changelog et un bump en trop. `npx changeset status` confirme ce qui sera publié
- **Vérifier un run CI** : épingler l'identifiant (`gh run view <id>`). `gh run list --limit 1`
  peut renvoyer un run **antérieur** tant que le nouveau n'est pas créé — on croit alors lire
  le résultat de son propre push et on rapporte un succès qui n'a rien à voir

## Consigner ce qu'on trouve — issues GitHub

Un défaut trouvé en chemin qu'on ne corrige pas tout de suite va dans une
**issue**, pas dans une description de PR : une PR mergée n'est plus lue, et
le constat disparaît avec elle.

Ouvrir une issue quand le sujet est **hors du périmètre** de ce qu'on fait,
demande un **arbitrage produit**, ou appartient à un **autre repo**. Sinon on
corrige sur-le-champ — une issue n'est pas un moyen d'éviter le travail.

Une issue utile porte : le symptôme **mesuré** (chiffres, pas impressions), la
cause si elle est connue, et les options avec leur coût quand il y a un choix
à faire. Préciser où le défaut a été trouvé et s'il est antérieur au code
courant — ça évite de rouvrir l'enquête.

Le repo d'accueil est celui du **code fautif**, pas celui où le symptôme est
apparu : un contrat d'API faux se consigne sur l'API.

## CI — Reusable Workflows

Pour tout ajout de step CI non-trivial, se demander si ça mérite un `workflow_call` partagé :
- **Mutualiser** : même logique sur 2+ repos, ou step complexe à maintenir centralement
- **Ne pas mutualiser** : step trivial (1-2 lignes), très spécifique au repo, pas de réutilisation prévisible

## Types auto-générés

`app/types/` et `src/types/api/` sont générés depuis OpenAPI — ne jamais modifier manuellement, corriger la source.
