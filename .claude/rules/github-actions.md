---
paths:
  - ".github/**"
---

# GitHub Actions

Un step non trivial qu'on retrouverait dans 2 repos ou plus se mutualise en `workflow_call` du workspace ; un step trivial ou propre à un repo reste chez lui.

- Les `workflow_call` du workspace se vérifient par `validate-workflows.yml`, qui rejoue les appelants committés de `.github/workflow-tests/` (un valide, un fautif) : les mettre à jour quand le contrat change, ne plus en créer à la main. `actionlint` y voit inputs et secrets requis ou inconnus (rien sous `secrets: inherit`) et outputs consommés ; ni les types, ni la casse des inputs, ni les `permissions` de l'appelant
- `actionlint` ne lit pas un appelé `owner/repo/…@ref`, et hors d'un dépôt git ne résout rien : il sort à 0 dans les deux cas (faceb#72). Pour vérifier un appelant d'app : copier les appelés d'`origin/main` dans un dossier `git init`, réécrire les `uses:` en `./.github/workflows/…`, et constater qu'un témoin fautif échoue
- Un code de sortie non nul ne prouve pas qu'un contrôle mord (témoin vidé ou YAML cassé) : vérifier le **compte** d'erreurs et **chaque** message
- Un `actionlint` local vert n'annonce pas un CI vert : shellcheck n'est pas épinglé (SC2002 optionnel en 0.11.0, actif sur le runner)
- Une `description:` d'input est évaluée : y écrire l'expression attendue sans `${{ }}`
- `inputs.<x>` d'un input `boolean` est un booléen (`== 'true'` toujours faux) ; seul `github.event.inputs.<x>` est une chaîne
- Un `workflow_dispatch` lance tous les jobs dont le `if` ne regarde que la ref : un job propre à une valeur d'input, les autres l'excluent (auth#13)
- `runs-on` épinglé (`ubuntu-24.04`), jamais `-latest`
- Toucher un `deploy.yml` déploie pour de bon, `docker compose pull` compris : vérifier avant le merge que les images du compose de prod sont épinglées (auth#9 : 10 min de 502)
- Rulesets et secrets d'org : voir « GitHub hors fichiers » dans `lessons.md`
