#!/usr/bin/env bash
set -euo pipefail

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

# Generate .env for flutter_dotenv if env vars are present (keeps secrets in Netlify env, not git)
cat > .env <<'EOF'
# Generated during Netlify build
GRAPH_CLIENT_ID=${GRAPH_CLIENT_ID}
GRAPH_TENANT_ID=${GRAPH_TENANT_ID}
TMDB_API_KEY=${TMDB_API_KEY}
EOF

flutter pub get
flutter build web --release
