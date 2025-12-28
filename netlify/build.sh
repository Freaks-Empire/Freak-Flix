#!/usr/bin/env bash
set -euo pipefail

# Optional audience may be unset in Netlify; default to empty string so set -u does not fail
AUTH0_AUDIENCE=${AUTH0_AUDIENCE:-}
AUTH0_LOGOUT_URL=${AUTH0_LOGOUT_URL:-}
AUTH0_DOMAIN=${AUTH0_DOMAIN:-}
AUTH0_CLIENT_ID=${AUTH0_CLIENT_ID:-}
AUTH0_CALLBACK_URL=${AUTH0_CALLBACK_URL:-}
GRAPH_CLIENT_ID=${GRAPH_CLIENT_ID:-}
GRAPH_TENANT_ID=${GRAPH_TENANT_ID:-}
TMDB_API_KEY=${TMDB_API_KEY:-}

# Configure desired Flutter version
FLUTTER_VERSION="3.24.3"
FLUTTER_TARBALL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

# Download and extract Flutter SDK
mkdir -p /opt/buildhome/flutter
cd /opt/buildhome/flutter
if [ ! -d "flutter" ]; then
  echo "Downloading Flutter ${FLUTTER_VERSION}..."
  curl -L "$FLUTTER_TARBALL" -o flutter.tar.xz
  tar xf flutter.tar.xz
fi

# Add Flutter to PATH
export PATH="/opt/buildhome/flutter/flutter/bin:$PATH"

# Enable web support (no-op if already enabled)
flutter config --enable-web

# Show version for logs
flutter --version

# Move to repo and build
cd /opt/build/repo

# Install Netlify Function dependencies (uses package-lock in netlify/functions)
if [ -f "netlify/functions/package.json" ]; then
  pushd netlify/functions >/dev/null
  npm ci || npm install
  # Ensure pg is available for new functions
  npm install pg
  popd >/dev/null
fi

# Generate .env for flutter_dotenv if env vars are present (keeps secrets in Netlify env, not git)
cat > .env <<EOF
# Generated during Netlify build
GRAPH_CLIENT_ID=${GRAPH_CLIENT_ID}
GRAPH_TENANT_ID=${GRAPH_TENANT_ID}
TMDB_API_KEY=${TMDB_API_KEY}
AUTH0_DOMAIN=${AUTH0_DOMAIN}
AUTH0_CLIENT_ID=${AUTH0_CLIENT_ID}
AUTH0_AUDIENCE=${AUTH0_AUDIENCE}
AUTH0_CALLBACK_URL=${AUTH0_CALLBACK_URL}
EOF

flutter pub get

# === VERSION TAGGING ===
# Extract git info
# In Netlify, HEAD might be detached, so we rely on Netlify's environment variables if available
# BRANCH: the branch name
# COMMIT_REF: the commit hash

SHORT_HASH=$(git rev-parse --short HEAD)
BRANCH_NAME=${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}

# Construct version string
# Example: Published dev@0fd68fa
GIT_VERSION="Published ${BRANCH_NAME}@${SHORT_HASH}"

echo "Building with version: $GIT_VERSION"
# =======================

flutter build web --release \
  --dart-define=AUTH0_DOMAIN=${AUTH0_DOMAIN} \
  --dart-define=AUTH0_CLIENT_ID=${AUTH0_CLIENT_ID} \
  --dart-define=AUTH0_AUDIENCE=${AUTH0_AUDIENCE} \
  --dart-define=AUTH0_CALLBACK_URL=${AUTH0_CALLBACK_URL} \
  --dart-define=AUTH0_LOGOUT_URL=${AUTH0_LOGOUT_URL} \
  --dart-define=GRAPH_CLIENT_ID=${GRAPH_CLIENT_ID} \
  --dart-define=GRAPH_TENANT_ID=${GRAPH_TENANT_ID} \
  --dart-define=TMDB_API_KEY=${TMDB_API_KEY} \
  --dart-define=GIT_VERSION="$GIT_VERSION" \
  --dart-define=BACKEND_URL=""
