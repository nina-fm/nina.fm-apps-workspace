---
paths:
  - "**/.claude/agents/**"
  - "plugins/nina/agents/**"
---

# Agents

- Un agent se justifie par ses appels : une commande qui l'appelle à l'étape où il sert, ou une description assez nette pour qu'on le délègue. Sa description se relit à chaque requête ; `harnais-conso.sh` liste ceux que rien n'appelle, et `/nina:harnais` les trie
