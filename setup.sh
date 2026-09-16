#!/usr/bin/env bash
# setup.sh — Installation du workspace apps Nina.fm sur une nouvelle machine
# Usage: bash setup.sh

set -e

echo "🎛️  Nina.fm Apps Workspace Setup"
echo "================================"

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Vérifications préalables ─────────────────────────────────────
echo ""
echo "📋 Vérification des prérequis..."

command -v git >/dev/null 2>&1 || { echo "❌ git requis"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ node requis (recommandé: via nvm)"; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo "❌ pnpm requis (npm install -g pnpm)"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "❌ gh requis (brew install gh)"; exit 1; }

echo "✅ git, node, pnpm, gh détectés"

# ── 2. Clonage des repos ────────────────────────────────────────────
echo ""
echo "📦 Clonage des repos..."

REPOS=(
  "nina.fm-api"
  "nina.fm-mixtaper"
  "nina.fm-faceb"
  "nina.fm-website"
)

for repo in "${REPOS[@]}"; do
  if [ -d "$WORKSPACE_DIR/$repo" ]; then
    echo "  ↩️  $repo déjà présent — skip"
  else
    echo "  ⬇️  Clonage de $repo..."
    git clone "git@github.com:YOUR_ORG/$repo.git" "$WORKSPACE_DIR/$repo"
  fi
done

# ── 3. Installation des dépendances ────────────────────────────────
echo ""
echo "📦 Installation des dépendances..."

for repo in "${REPOS[@]}"; do
  if [ -f "$WORKSPACE_DIR/$repo/package.json" ]; then
    echo "  → pnpm install dans $repo..."
    (cd "$WORKSPACE_DIR/$repo" && pnpm install --frozen-lockfile)
  fi
done

# ── 4. Variables d'environnement ────────────────────────────────────
echo ""
echo "⚙️  Variables d'environnement..."

for repo in "${REPOS[@]}"; do
  env_example="$WORKSPACE_DIR/$repo/.env.example"
  env_file="$WORKSPACE_DIR/$repo/.env"
  if [ -f "$env_example" ] && [ ! -f "$env_file" ]; then
    cp "$env_example" "$env_file"
    echo "  📄 $repo/.env créé depuis .env.example — à compléter !"
  fi
done

# ── 5. GitHub CLI ───────────────────────────────────────────────────
echo ""
echo "🔑 GitHub CLI (PRs, issues, Projects)"
if gh auth status >/dev/null 2>&1; then
  echo "  ✅ gh authentifié"
else
  echo "  ⚠️  gh non authentifié"
  echo "  → Lancer : gh auth login"
fi

# ── 6. Git hooks (commitlint + lint-staged) ─────────────────────────
echo ""
echo "🪝 Git hooks..."
for repo in "${REPOS[@]}"; do
  if [ -f "$WORKSPACE_DIR/$repo/package.json" ]; then
    if grep -q '"husky"' "$WORKSPACE_DIR/$repo/package.json" 2>/dev/null; then
      echo "  → Husky dans $repo..."
      (cd "$WORKSPACE_DIR/$repo" && pnpm husky install 2>/dev/null || true)
    fi
  fi
done

echo ""
echo "================================"
echo "✅ Setup terminé !"
echo ""
echo "Prochaines étapes manuelles :"
echo "  1. Compléter les fichiers .env dans chaque repo"
echo "  2. Authentifier la CLI GitHub si besoin : gh auth login"
echo "  3. Lancer les bases de données : voir nina.fm-api/docker-compose.yml"
echo "  4. Lancer l'API : cd nina.fm-api && pnpm start:dev"
echo "  5. Lancer Mixtaper : cd nina.fm-mixtaper && pnpm dev"
