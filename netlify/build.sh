#!/bin/bash
set -e

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

# Build Flutter Web with dart-define
flutter build web --release --dart-define=GIT_VERSION="$GIT_VERSION" --dart-define=BACKEND_URL=""
