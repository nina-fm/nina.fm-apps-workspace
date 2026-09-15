---
description: Leçons apprises — workspace Nina.fm (chargé automatiquement dans tous les repos)
---

# Lessons — workspace

_Les règles consolidées ont été déplacées dans `CLAUDE.md` du workspace._

- Le shell est zsh : les tableaux commencent à 1. `${arr[$((i-1))]}` décale tout d'un cran — une boucle `gh issue create` a ainsi collé chaque titre sur le corps suivant. Itérer sur les éléments (`for t in "${arr[@]}"`), pas sur des indices
- `cat` passe par le hook rtk, qui filtre la sortie : `eslint.config.mjs` affiché sans ses commentaires, son bloc `ignores` ni ses `files` a fait croire à un `max-lines` coupé partout. Lire un fichier de config avec Read ; `rtk proxy <cmd>` pour une sortie brute
- Une fonction shell qui porte le nom d'un alias zsh (`g`, `gp`…) échoue en `parse error` : `function nom { … }` avec un nom improbable
