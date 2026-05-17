#!/usr/bin/env bash

set -euo pipefail

# Usage:
#   TAG=v1.0.0 ./scripts/tag-release.sh
#   ./scripts/tag-release.sh v1.0.0

TAG="${TAG:-${1:-}}"
REMOTE="${REMOTE:-origin}"

if [[ -z "${TAG}" ]]; then
  echo "Usage: TAG=v1.0.0 $0"
  echo "   or: $0 v1.0.0"
  exit 1
fi

echo "Preparing tag: ${TAG} (remote: ${REMOTE})"

# Delete remote tag only if it exists
if git ls-remote --tags "${REMOTE}" "refs/tags/${TAG}" | grep -q "refs/tags/${TAG}$"; then
  echo "Remote tag exists. Deleting ${REMOTE}/${TAG}..."
  git push "${REMOTE}" --delete "${TAG}"
else
  echo "Remote tag ${TAG} does not exist. Skipping remote delete."
fi

# Delete local tag only if it exists
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "Local tag exists. Deleting ${TAG}..."
  git tag -d "${TAG}"
else
  echo "Local tag ${TAG} does not exist. Skipping local delete."
fi

echo "Creating tag ${TAG}..."
git tag "${TAG}"

echo "Pushing tag ${TAG} to ${REMOTE}..."
git push "${REMOTE}" "${TAG}"

echo "Done."
