# CLAUDE.md — nina.fm-apps-workspace

Conventions communes aux cinq repos ; celles d'une stack sont dans le `CLAUDE.md` du repo.
Infrastructure, écosystème et plugin `nina` : `WORKSPACE.md`.

## Langue

Tout ce qui se lit s'écrit en français : issues, PR, messages de commit (après le préfixe
conventionnel, `fix(transitions): aligner…`), changesets, docs, commentaires de code. Les
identifiants restent en anglais. L'historique ancien ne se réécrit pas ; ce qu'on touche
passe en français.

## Tests

Tester la logique métier isolée, les cas d'erreur, les contrats publics et les régressions
connues ; pas les composants purement UI, les getters triviaux ni les wrappers d'une ligne.
`it('should [comportement] when [condition]')`, test co-localisé, pas de snapshot,
factories pour les objets complexes (`createMockTrack()`), mocks sur les seules dépendances
externes (DB, HTTP), e2e pour les parcours critiques seulement. Le seuil de coverage est
propre à chaque repo, dans sa config.

## Plan

Le plan d'un repo vit dans son Project GitHub ; le plugin `nina` l'affiche en début de
session (`NINA_PROJECT` du `.claude/settings.json`). Celui d'un repo porte son métier, celui
du workspace les chantiers qui traversent les cinq repos ; `api` et `auth` n'en ont pas :
leurs issues vont dans le Project du repo pour le compte duquel elles s'ouvrent. Une issue,
une session ; une epic se découpe avec `/nina:epic`, Horizon et Status se manient par
`/nina:plan`, `/nina:task` et `/nina:pr`.

**Toute issue ouverte se range**, `plan.sh add <url> <Horizon>` : dans le **seul** Project de
son epic si c'en est une sous-issue (un second rangement, ce sont deux Horizons qui divergent
en silence), sinon dans celui de son repo ; le premier rangement d'une issue sans epic depuis
un autre repo se préfixe `NINA_PROJECT=<n>`.

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
`/nina:review` se servent.

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
