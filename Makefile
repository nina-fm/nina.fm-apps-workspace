# Nina.fm — Environnement de développement local
#
# Prérequis : Docker, pnpm, Node.js
#
# Socle commun (auth + infra) : lancé automatiquement par toutes les cibles dev-*
#
# Usage :
#   make dev             Lance l'infra Docker seule (postgres, redis, supertokens)
#   make dev-stop        Arrête l'infra Docker
#   make dev-logs        Logs en temps réel de l'infra
#   make dev-mixtaper    Infra + API + Mixtaper
#   make dev-faceb       Infra + API + Face B (backoffice)
#   make dev-website     Infra + API + Website
#   make dev-webradio    Infra + API + Face B + Website

.PHONY: dev dev-stop dev-logs dev-mixtaper dev-faceb dev-website dev-webradio

## Lance l'infra Docker (postgres, redis, supertokens)
dev:
	docker compose -f docker-compose.dev.yml up -d

## Arrête l'infra Docker
dev-stop:
	docker compose -f docker-compose.dev.yml down

## Affiche les logs en temps réel de l'infra
dev-logs:
	docker compose -f docker-compose.dev.yml logs -f

## Infra + API (start:dev) + Mixtaper
dev-mixtaper: dev
	cd nina.fm-mixtaper && pnpm dev:stack

## Infra + API (start:dev) + Face B (backoffice)
dev-faceb: dev
	cd nina.fm-faceb && pnpm dev:stack

## Infra + API (start:dev) + Website
dev-website: dev
	cd nina.fm-website && pnpm dev:stack

## Infra + API (start:dev) + Face B + Website
dev-webradio: dev
	npx --yes concurrently -k \
		-n "API,FaceB,Website" \
		-c "bgWhite.black,bgBlue.white,bgGreen.black" \
		"cd nina.fm-api && pnpm start:dev" \
		"cd nina.fm-faceb && pnpm dev" \
		"cd nina.fm-website && pnpm dev"
