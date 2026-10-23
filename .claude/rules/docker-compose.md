---
paths:
  - "**/docker-compose*.yml"
  - "**/Dockerfile"
---

# Docker Compose (prod)

- Sur `nina-network`, partagé par toutes les stacks, chaque nom de service devient un alias DNS : `postgres`, `redis` et `api` y désignent déjà deux conteneurs, et la résolution rend les deux au hasard. Joindre un conteneur par son `container_name`, et laisser une base hors de `nina-network`, sur un réseau privé de la stack (`internal: true`) (auth#17 : 3 min 30 de démarrage du core)
- Passé le `start_period`, Docker ne vérifie plus qu'à chaque `interval` (2 min) : le `start_period` couvre toute l'attente du déploiement, sinon un démarrage un peu lent reste `starting` et le déploiement échoue alors que le service est prêt (auth#16, api#81)
- Au redémarrage du démon Docker, `restart:` relance tous les conteneurs en même temps, sans `depends_on` : un service doit savoir réessayer sa dépendance
- Changer un healthcheck, un réseau ou une variable recrée le conteneur au déploiement : quelques secondes de coupure du service, à annoncer dans la PR
