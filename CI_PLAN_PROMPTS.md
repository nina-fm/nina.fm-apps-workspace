# CI/CD — Prompts d'implémentation

Plan complet : `~/.claude/plans/linear-rolling-narwhal.md`

---

## 1. nina.fm-auth

```
Le plan CI/CD est dans ~/.claude/plans/linear-rolling-narwhal.md. Applique tous les fixes prévus pour nina.fm-auth : bug #3 (rollback condition inatteignable) et bug #4 (docker system prune --volumes).
```

## 2. nina.fm-website

```
Le plan CI/CD est dans ~/.claude/plans/linear-rolling-narwhal.md. Applique tous les fixes prévus pour nina.fm-website : bug #1 (heredoc EOF), et items Sprint 2 : #5 (versions actions Docker), #6 (pnpm/action-setup), #8 (docker-compose via api.github.com), #11 (VERSIONING_TOKEN → GITHUB_TOKEN), #13 (health check polling), #15 (no-cache conditionnel).
```

## 3. nina.fm-mixtaper

```
Le plan CI/CD est dans ~/.claude/plans/linear-rolling-narwhal.md. Applique tous les fixes prévus pour nina.fm-mixtaper : bug #2 (skip ci sur release commit), et items Sprint 2 : #5 (versions actions Docker), #15 (no-cache conditionnel). Vérifie aussi #21 (pnpm build redondant avant Docker) en lisant le Dockerfile.
```

## 4. nina.fm-faceb

```
Le plan CI/CD est dans ~/.claude/plans/linear-rolling-narwhal.md. Applique tous les fixes prévus pour nina.fm-faceb : Sprint 2 items #5 (versions actions Docker), #7 (:latest), #8 (docker-compose via api.github.com), #13 (health check polling), #15 (no-cache conditionnel), #16 (ls debug à supprimer), #17 (build-args via vars.*).
```

## 5. nina.fm-api

```
Le plan CI/CD est dans ~/.claude/plans/linear-rolling-narwhal.md. Applique tous les fixes prévus pour nina.fm-api : Sprint 2 items #9 (ajouter pnpm type-check), #12 (remplacer docker-cleanup.sh --safe par inline keep last 3 images), #15 (no-cache conditionnel).
```

## 6. nina.fm-apps-workspace

```
Le plan CI/CD est dans ~/.claude/plans/linear-rolling-narwhal.md. Implémente le Sprint 3 complet : créer .github/workflows/node-test.yml (reusable job test), .github/workflows/release.yml (reusable logique changeset/release), .github/workflows/cleanup.yml (scheduled Docker cleanup via SSH). Puis migrer les deploy.yml de api, faceb, website, mixtaper vers ces reusable workflows.
```
