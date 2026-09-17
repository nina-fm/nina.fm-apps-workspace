# CLAUDE.md — nina.fm-apps-workspace

Guidelines transversales pour tous les repos du workspace Nina.fm.

> Chaque repo a son propre CLAUDE.md pour les conventions stack-spécifiques.
> Voir `WORKSPACE.md` pour l'infrastructure, l'écosystème, le plugin `nina` et les
> conventions cross-repo.

## Langue

Tout ce qui se lit s'écrit en français : issues, PR, messages de commit (après le préfixe
conventionnel, `fix(transitions): aligner…`), changesets, docs, commentaires de code. Les
identifiants restent en anglais. L'historique ancien ne se réécrit pas ; ce qu'on touche
passe en français.

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
- Pas de snapshot tests ; coverage 80 % global (exceptions : config, migrations, DTOs simples)
- Co-localisation : `my-service.test.ts` ou `my-service.spec.ts`
- Factories pour les objets complexes : `createMockTrack()`, `createMockSession()`
- Mocks uniquement sur les dépendances externes (DB, HTTP) — pas sur la logique métier
- Priorité : unitaires → fonctionnels → e2e (parcours critiques uniquement)

## Plan

Le plan d'un repo vit dans son Project GitHub, pas dans ses fichiers. Le plugin `nina`
l'affiche en début de session quand le repo a le sien (`NINA_PROJECT` dans son
`.claude/settings.json`).

- **Une issue, une session.** Les epics portent le label `epic` ; leurs sous-issues en
  sont le découpage, dans l'ordre. Une epic se découpe avec `/nina:epic` au moment d'y
  venir, pas avant ; une issue se démarre avec `/nina:task #N`.
- **Toute issue ouverte se range dans le Project** avec son Horizon,
  `plan.sh add <url> <Horizon>` — y compris celle ouverte sur un autre repo pour le compte
  de celui-ci. On tranche à l'ouverture si elle passe avant la suite du plan. Les
  sous-issues entrent sans Horizon ; « Sans horizon » dans le plan affiché signale un oubli.
- **Horizons** : `Maintenant`, `Ensuite`, `Plus tard`, `Différé`, `Au fil de l'eau`.
- **Fermer** : la PR porte `Closes #N`, l'issue passe à Done toute seule.

## Recette

Deux recettes encadrent tout ticket, dans l'app réelle — pas seulement dans les tests.
Un test peut passer avec et sans le correctif : la recette prouve ce que l'utilisateur
voit et entend.

- **De constat, avant de prendre le ticket** : reproduire le défaut, ou constater
  l'absence de la fonctionnalité, sur `main`. Un ticket qui ne se reproduit plus se
  commente et se ferme, il ne s'implémente pas.
- **Finale, avant de merger**, et de nouveau après chaque passe de review : rejouer le
  scénario du constat, plus le chemin nominal pour la non-régression.

Mesurer plutôt qu'observer (valeurs avant / après), reporter les mesures dans la PR,
retirer à la fin toute donnée créée pour la recette. Le protocole propre à chaque app
vit dans son repo (ex. `/recette` dans mixtaper).

## Workflow Git & GitHub

Ordre : recette de constat → `/nina:task` → `git pull origin main && git checkout -b` →
code → recette finale → `/nina:pr` → `/nina:review` si demandée → recette finale après
retours → merge

- **Merger** : `gh pr merge --squash --delete-branch <numéro>` — jamais `git merge` + `git push`
- **Sync avant de tirer une branche** : `git pull origin main` puis `git checkout -b`
- **Après un merge**, fusionner `main` dans les branches qui en descendent, puis vérifier
  `npx changeset status` : un changeset déjà publié survit à ce merge et rejouerait son
  entrée de changelog
- **Vérifier un run CI** : épingler l'identifiant (`gh run view <id>`) — `gh run list --limit 1`
  peut renvoyer un run antérieur tant que le nouveau n'est pas créé, et on rapporte alors
  un succès qui n'a rien à voir avec son push
- Le reste de la mécanique d'une PR — vérifications, changeset, upstream, corps — est dans
  `/nina:pr`, qui la porte au moment où elle sert

## Consigner ce qu'on trouve — issues GitHub

Un défaut trouvé en chemin qu'on ne corrige pas tout de suite va dans une **issue**, pas
dans une description de PR : une PR mergée n'est plus lue.

Ouvrir une issue quand le sujet est **hors périmètre**, demande un **arbitrage produit**,
ou appartient à un **autre repo** — celui du code fautif, pas celui où le symptôme est
apparu. Sinon on corrige sur-le-champ : une issue n'est pas un moyen d'éviter le travail.

Une issue utile porte le symptôme **mesuré** (chiffres, pas impressions), la cause si elle
est connue, les options avec leur coût, et où le défaut a été trouvé.

## CI — Reusable Workflows

Un step CI non-trivial qu'on retrouverait sur 2+ repos se mutualise en `workflow_call`
partagé ; un step trivial ou très spécifique à un repo reste chez lui.

## Fichiers générés

Un fichier généré ne se modifie jamais à la main : on corrige la source et on régénère
(orval depuis OpenAPI, lockfiles). Chaque repo **déclare ses chemins générés** dans son
`.gitattributes`, marqueur `linguist-generated` — seule liste à jour, dont GitHub et
`/nina:review` se servent ; `review-diff.sh` en rappelle la syntaxe quand un repo ne
déclare rien. Un fichier écrit à la main au milieu du généré (le mutator `fetcher.ts`)
se réinclut nommément **après** la ligne qui l'exclut : la dernière qui matche gagne.

## Self-Improvement

Après toute correction ou erreur détectée, consigner la leçon en une ligne concise, sans
attendre qu'on le signale — et là où elle sert :

- vaut pour **toute session** → `.claude/rules/lessons.md` du repo, ou du workspace si transversal
- ne joue qu'au moment où une **commande** tourne → son corps, dans `plugins/nina/commands/`
- un **outil** peut l'appliquer → le script, en commentaire au-dessus du code qui l'applique
- c'est une **convention** → `CLAUDE.md` du repo ; jamais `~/.claude/`, sauf préférence personnelle

`.claude/rules/` est relu à chaque requête de chaque session des cinq repos : une ligne
qui n'y sert plus s'y paye tous les jours.
