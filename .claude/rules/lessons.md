---
description: Leçons apprises — workspace Nina.fm (chargé automatiquement dans tous les repos)
---

# Lessons — workspace

_Les règles consolidées ont été déplacées dans `CLAUDE.md` du workspace._

- Le shell est zsh : les tableaux commencent à 1. `${arr[$((i-1))]}` décale tout d'un cran — une boucle `gh issue create` a ainsi collé chaque titre sur le corps suivant. Itérer sur les éléments (`for t in "${arr[@]}"`), pas sur des indices
