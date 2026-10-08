---
paths:
  - "**/.gitattributes"
---

# Chemins générés

- `review-diff.sh` rappelle la syntaxe du marqueur `linguist-generated` quand un repo ne déclare rien
- Un fichier écrit à la main au milieu du généré (le mutator `fetcher.ts`) se réinclut nommément **après** la ligne qui l'exclut : la dernière qui matche gagne
