# CLAUDE.md — nina.fm-apps-workspace

Conventions communes aux cinq repos ; celles d'une stack sont dans le `CLAUDE.md` du repo.
Infrastructure, écosystème et plugin `nina` : `WORKSPACE.md`.

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

- **Un Project, un périmètre.** Celui d'un repo porte son métier et ce qui lui est
  intrinsèque ; celui du workspace porte les chantiers qui traversent les cinq repos. `api` et
  `auth` n'ont pas de Project : leurs issues se rangent dans celui du repo pour le compte
  duquel elles sont ouvertes.
- **Une issue, une session.** Les epics (label `epic`) se découpent avec `/nina:epic` au
  moment d'y venir ; leurs sous-issues, dans l'ordre, prennent l'Horizon de l'epic.
- **Un chantier transverse est une epic du workspace** ; un chantier à deux repos que pilote
  une app reste son epic à elle (mixtaper#46 porte des sous-issues `api`). Les sous-issues
  vivent dans le repo du code qu'elles modifient et se rangent dans le **seul** Project de leur
  epic : un second rangement, ce sont deux Horizons qui divergent en silence.
- **Toute issue ouverte se range dans un Project**, `plan.sh add <url> <Horizon>` : celui de
  l'epic dont elle est une sous-issue, sinon celui de son repo. `plan.sh` trouve seul celui
  d'une sous-issue ou d'une issue déjà rangée, quelle que soit la session ; le premier rangement
  d'une issue sans epic depuis un autre repo se préfixe `NINA_PROJECT=<n>`.
- **Horizon** (`Maintenant`, `Ensuite`, `Plus tard`, `Différé`, `Au fil de l'eau`) dit la
  priorité ; « Maintenant » est un engagement court : l'epic en cours, ou 2 ou 3 issues.
  Il bouge par `/nina:plan`, au signal du plan affiché ou à la fermeture d'une epic.
- **Status** dit l'exécution : `/nina:task` passe l'issue en `In Progress`, la PR porte
  `Closes #N` et l'issue passe à Done toute seule — pas son epic, que `/nina:pr` signale.

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
  peut renvoyer un run antérieur au push
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

## Fichiers générés

Un fichier généré ne se modifie jamais à la main : on corrige la source et on régénère
(orval depuis OpenAPI, lockfiles). Chaque repo **déclare ses chemins générés** dans son
`.gitattributes`, marqueur `linguist-generated` — seule liste à jour, dont GitHub et
`/nina:review` se servent ; `review-diff.sh` en rappelle la syntaxe quand un repo ne
déclare rien. Un fichier écrit à la main au milieu du généré (le mutator `fetcher.ts`)
se réinclut nommément **après** la ligne qui l'exclut : la dernière qui matche gagne.

## Self-Improvement

Après toute correction ou erreur détectée, consigner la leçon sans attendre qu'on le
signale, en une ligne : la règle, et l'issue où elle s'est apprise — pas son histoire.
Avant de l'écrire :

1. **Un outil peut-il l'appliquer** (lint, script, hook, CI) ? Alors l'outil, en commentaire
   au-dessus du code qui l'applique. Une ligne que la machine fait respecter ne s'écrit pas.
2. **Le moment où elle sert est-il prévisible ?** En touchant certains fichiers →
   `.claude/rules/<sujet>.md` avec `paths:` ; pendant une commande → son corps, dans
   `plugins/nina/commands/` ; en retouchant le plugin → `plugins/nina/LESSONS.md`.
3. Sinon seulement, `.claude/rules/lessons.md` du repo, ou du workspace si elle vaut pour
   les cinq. Une convention va dans `CLAUDE.md` ; `~/.claude/` ne reçoit que du personnel.

Ce qui se charge sans condition se paye à chaque requête des cinq repos. `/nina:harnais`
le mesure contre son budget et fait le tri : à lancer quand il le dépasse.
