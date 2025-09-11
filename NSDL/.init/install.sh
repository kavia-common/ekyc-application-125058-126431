#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/ekyc-application-125058-126431/NSDL"
cd "$WORKSPACE"
[ -f package.json ] || { echo "package.json missing - run scaffold step" >&2; exit 2; }
# Choose deterministic installer
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund --silent || { echo "npm ci failed" >&2; exit 3; }
elif [ -f yarn.lock ] && command -v yarn >/dev/null; then
  yarn install --silent || { echo "yarn install failed" >&2; exit 3; }
else
  npm i --no-audit --no-fund --silent || { echo "npm install failed" >&2; exit 3; }
fi
# helper to check for dep in package.json
has_dep(){ node -e "try{const p=require('./package.json'); const k=process.argv[1]; if((p.dependencies&&p.dependencies[k])||(p.devDependencies&&p.devDependencies[k])) process.exit(0); else process.exit(1);}catch(e){process.exit(2);}" "$1"; }
# Determine package manager for adding deps
USE_YARN=0
if [ -f yarn.lock ] && command -v yarn >/dev/null; then USE_YARN=1; fi
# Install jest only if not declared locally
if ! has_dep jest >/dev/null 2>&1 && [ $USE_YARN -eq 1 ]; then
  yarn add --dev jest@^29 --silent || { echo "yarn add jest failed" >&2; exit 4; }
elif ! has_dep jest >/dev/null 2>&1; then
  npm i --no-audit --no-fund --silent --save-dev jest@^29 || { echo "npm install jest failed" >&2; exit 4; }
fi
# Install serve only if not declared locally (used for static serve of build)
if ! has_dep serve >/dev/null 2>&1; then
  if [ $USE_YARN -eq 1 ]; then
    yarn add --dev serve@^14 --silent || { echo "yarn add serve failed" >&2; exit 5; }
  else
    npm i --no-audit --no-fund --silent --save-dev serve@^14 || { echo "npm install serve failed" >&2; exit 5; }
  fi
fi
# Verify local binaries (do not modify global PATH)
if [ -x "$WORKSPACE/node_modules/.bin/jest" ]; then
  "$WORKSPACE/node_modules/.bin/jest" --version >/dev/null 2>&1 || true
fi
if [ -x "$WORKSPACE/node_modules/.bin/serve" ]; then
  "$WORKSPACE/node_modules/.bin/serve" --version >/dev/null 2>&1 || true
fi
# success
exit 0
