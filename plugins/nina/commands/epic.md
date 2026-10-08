---
description: Explorer une grande fonctionnalité et la découper en sous-issues rangées dans le plan
argument-hint: "#N | URL d'issue epic | description de la fonctionnalité"
---

Explorer une grande fonctionnalité et la découper en sous-fonctionnalités réalisables : $ARGUMENTS

## Consignes

Tu es en **mode exploration** : comprendre le périmètre d'une grande fonctionnalité, discuter des compromis, et produire un découpage structuré en fonctionnalités plus petites. Ne créer aucune branche et n'écrire aucun code.

Tout ce que tu écris est en français : analyse, issues créées, commentaires.

---

### Étape 1 — Comprendre la demande

Si `$ARGUMENTS` est une issue (`#N` ou son URL), la lire avec ses commentaires et ses sous-issues existantes : c'est l'epic, et ses décisions font partie de la spec. Pour l'URL d'un autre repo, remplacer `{owner}/{repo}` par le `nina-fm/<repo>` de l'URL et ajouter `-R nina-fm/<repo>` à `gh issue view`.

```bash
# --comments hors terminal n'écrit que les commentaires, sans titre ni corps : d'où --json
gh issue view N --json title,labels,body,comments --jq '"# \(.title)\nlabels : \([.labels[].name] | join(", "))\n\n\(.body)\n\n--- commentaires ---\n\(if (.comments | length) == 0 then "(aucun)" else [.comments[] | "\(.author.login) : \(.body)"] | join("\n\n") end)"'
gh api repos/{owner}/{repo}/issues/N/sub_issues --jq '.[] | "#\(.number) \(.state) \(.title)"'
```

Se demander :
- Le périmètre est-il assez clair pour être découpé, ou faut-il d'abord lever des ambiguïtés ?
- Touche-t-il plusieurs couches ou plusieurs repos (API, fronts, auth, infra) ?
- Plusieurs approches techniques valables méritent-elles d'être comparées ?

En cas d'ambiguïté bloquante, poser la question à l'utilisateur avant de continuer.

---

### Étape 2 — Explorer le code

Déléguer la lecture à un agent `Explore` (outil Agent, `subagent_type: Explore`, `model: sonnet`) : il lit dans son propre contexte, et seule sa carte revient dans la session. Un agent par repo touché ; pour un endpoint ou un format de réponse de l'API depuis une app, `nina:api-explorer`. Il ne voit ni la conversation ni les `CLAUDE.md` (Explore ne les charge pas) : son brief porte le chemin du repo, où y vit le code (`app/` dans faceb, `src/` dans mixtaper…), ses chemins générés (`linguist-generated` du `.gitattributes`, jamais des modèles à suivre), la fonctionnalité telle que l'étape 1 l'a cadrée, et lui demande de chercher ce qui existe déjà en lien avec elle, ce qu'il faudrait créer et modifier, les dépendances externes et changements d'API impliqués, et les contraintes (performance, auth), puis de rendre une carte — `fichier:ligne`, rôle, pourquoi c'est pertinent —, les modèles voisins à suivre et les risques, sans recopier le code.

Lire ensuite soi-même, avec Read, les fichiers au cœur du découpage, et le modèle voisin retenu : les frontières des sous-issues reposent sur le code lu, pas sur un résumé. Les `CLAUDE.md` sont déjà chargés, inutile de les relire.

---

### Étape 3 — Présenter l'analyse

Structurer la réponse **exactement** ainsi :

---

**Epic :** $ARGUMENTS

#### Contexte
[2–4 phrases : ce qu'est la fonctionnalité, pourquoi elle compte, quelles parties du système elle touche]

#### Approches techniques
[Si plusieurs approches sont valables, les comparer brièvement — 2 ou 3 au plus]

| Approche | Pour | Contre |
|----------|------|--------|
| Option A | ... | ... |
| Option B | ... | ... |

**Recommandée :** [Option X — pourquoi]

#### Découpage en sous-fonctionnalités

| # | Fonctionnalité | Repo | Taille | Dépend de |
|---|----------------|------|--------|-----------|
| 1 | `[nom court]` — [une phrase] | [repo] | Petite/Moyenne/Grande | — |
| 2 | `[nom court]` — [une phrase] | [repo] | Petite/Moyenne/Grande | 1 |
| 3 | `[nom court]` — [une phrase] | [repo] | Petite/Moyenne/Grande | 1, 2 |

#### Impact sur l'API
[Endpoints à créer ou modifier — ou **Aucun**]

#### Questions ouvertes
[Décisions à prendre par l'utilisateur avant de commencer — ou **Aucune**]

#### Ordre suggéré
[Séquence recommandée, et pourquoi]

---

### Étape 4 — Attendre la décision

Après l'analyse, demander :

> J'enregistre ce découpage dans le plan ? (ou : on l'ajuste d'abord ?)

Ne créer aucune branche, n'écrire aucun code et ne pas lancer `/nina:task` de soi-même.

---

### Étape 5 — Enregistrer le découpage (une fois approuvé)

Écrire chaque corps d'issue dans un fichier par heredoc à guillemets simples (`<<'EOF'`) et le passer avec `--body-file` : un corps passé en argument se casse sur les apostrophes et les backticks.

1. **Issue epic** — la réutiliser si elle existe déjà ; sinon la créer avec le label `epic`, dans le workspace pour un chantier qui traverse les repos, dans l'app pour un chantier qu'elle pilote, même s'il touche l'API (mixtaper#46 porte des sous-issues `api`). Son corps porte l'objectif, le constat, l'approche retenue et l'ordre suggéré (section « Découpage » datée si l'epic existait). Tous les repos n'ont pas le label : le créer s'il manque, avant `gh issue create`.

   ```bash
   gh label list -R nina-fm/<repo> --search epic --json name --jq '.[].name' | grep -qx epic \
     || gh label create epic -R nina-fm/<repo> --description "Grande fonctionnalité découpée en sous-issues"
   ```

2. **Une issue par sous-fonctionnalité**, dans le repo du code qu'elle modifie (`nina.fm-api` pour le travail d'API). Corps : `Sous-issue de nina-fm/<repo>#<epic>`, puis Objectif, Constat (mesuré, daté, sur `main`), Périmètre, Recette.
3. **Les rattacher comme sous-issues de l'epic, dans l'ordre suggéré** — avec l'`id` REST, pas le numéro :
   ```bash
   ID=$(gh api repos/nina-fm/<repo>/issues/<N> --jq .id)
   gh api -X POST repos/nina-fm/<repo-de-l-epic>/issues/<epic>/sub_issues -F sub_issue_id="$ID"
   ```
4. **Dépendances**, d'après la colonne « Dépend de » :
   ```bash
   gh api -X POST repos/nina-fm/<repo>/issues/<N>/dependencies/blocked_by -F issue_id=<id REST de l'issue bloquante>
   ```
5. **Horizon** — seulement si l'epic est rangée dans un Project, ou que la session en a un pour l'y ranger (`NINA_PROJECT`, voir « Plugin nina » dans `WORKSPACE.md`). Les sous-issues suivent l'Horizon de leur epic : l'utilisateur le choisit pour l'epic seule, puis chaque issue créée se range avec celui-là.
   ```bash
   plan.sh add <url> <Horizon>   # Maintenant, Ensuite, Plus tard, Différé, Au fil de l'eau
   ```
   L'epic se range d'abord, dans le Project de son repo : une session garde le `NINA_PROJECT` du repo où elle a été lancée ; pour un autre Project, `NINA_PROJECT=<n> plan.sh add …` (`gh project list --owner nina-fm` donne les numéros). Ses sous-issues, une fois rattachées, vont d'elles-mêmes dans ce Project-là, sans préfixe. Pour une epic déjà rangée, reprendre son Horizon ; `plan.sh move <url de l'epic> <Horizon>` le change dans son Project, quelle que soit la session, en entraînant ses sous-issues ouvertes. Epic rangée nulle part et session sans `NINA_PROJECT` : sauter cette étape et le dire.

Donner ensuite l'URL de l'epic et demander par quelle sous-issue commencer. Chacune se démarre dans une nouvelle session avec `/nina:task #N` — l'utilisateur décide de la suite.
