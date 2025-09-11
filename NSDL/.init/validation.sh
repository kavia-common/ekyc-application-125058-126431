#!/usr/bin/env bash
set -euo pipefail
# Validation: build app, start preview server, verify HTTP, and stop
WORKSPACE="/home/kavia/workspace/code-generation/ekyc-application-125058-126431/NSDL"
cd "$WORKSPACE"
[ -f package.json ] || { echo "package.json missing - run scaffold step" >&2; exit 2; }
# Ensure CI and production build env
export CI=true
export NODE_ENV=production
# Prefer local node bins
export PATH="$WORKSPACE/node_modules/.bin:$PATH"
# Build
npm run build --silent || { echo "Build failed" >&2; exit 3; }
# Determine artifact directory
ARTIFACT_DIR=""
if [ -d "$WORKSPACE/build" ]; then ARTIFACT_DIR="$WORKSPACE/build"; elif [ -d "$WORKSPACE/dist" ]; then ARTIFACT_DIR="$WORKSPACE/dist"; elif [ -d "$WORKSPACE/out" ]; then ARTIFACT_DIR="$WORKSPACE/out"; fi
if [ -z "$ARTIFACT_DIR" ]; then
  TOOLCHAIN=$(node -e "try{const p=require('./package.json'); if((p.dependencies&&p.dependencies['react-scripts'])||(p.devDependencies&&p.devDependencies['react-scripts'])){console.log('cra');}else if((p.dependencies&&p.dependencies.vite)||(p.devDependencies&&p.devDependencies.vite)||(p.scripts&&p.scripts.dev&&p.scripts.dev.includes('vite'))){console.log('vite');}else{console.log('unknown')} }catch(e){console.log('unknown')}" )
  if [ "$TOOLCHAIN" = "vite" ] && [ -d "$WORKSPACE/dist" ]; then ARTIFACT_DIR="$WORKSPACE/dist"; fi
fi
if [ -z "$ARTIFACT_DIR" ]; then echo "No build artifact directory found (looked for build/ dist/ out/)." >&2; exit 4; fi
# Pick ephemeral port
PORT=$(python3 - <<'PY'
import socket,sys
s=socket.socket()
s.bind(('127.0.0.1',0))
port=s.getsockname()[1]
s.close()
print(port)
PY
) || PORT=5000
# Start preview server: prefer local vite preview, else local serve, else npx serve
SERVER_PID=""
LOG_DIR="/tmp"
PREVIEW_LOG="$LOG_DIR/nsdl_preview.log"
SERVE_LOG="$LOG_DIR/nsdl_serve.log"
# Try vite preview (local bin), else try npx vite preview, else use serve
if [ -x "$WORKSPACE/node_modules/.bin/vite" ] && grep -q 'vite' package.json 2>/dev/null; then
  "$WORKSPACE/node_modules/.bin/vite" preview --port "$PORT" --strictPort >"$PREVIEW_LOG" 2>&1 &
  SERVER_PID=$!
else
  if command -v npx >/dev/null && (grep -q 'vite' package.json 2>/dev/null || grep -q 'preview' package.json 2>/dev/null); then
    npx --yes vite preview --port "$PORT" --strictPort >"$PREVIEW_LOG" 2>&1 &
    SERVER_PID=$!
  else
    if [ -x "$WORKSPACE/node_modules/.bin/serve" ]; then
      "$WORKSPACE/node_modules/.bin/serve" -s "$ARTIFACT_DIR" -l "$PORT" >"$SERVE_LOG" 2>&1 &
      SERVER_PID=$!
    elif command -v npx >/dev/null; then
      npx --yes serve -s "$ARTIFACT_DIR" -l "$PORT" >"$SERVE_LOG" 2>&1 &
      SERVER_PID=$!
    else
      echo "No way to serve built files (no local serve, no npx)" >&2; exit 5
    fi
  fi
fi
# Ensure SERVER_PID set
if [ -z "${SERVER_PID:-}" ]; then echo "Server failed to start" >&2; exit 6; fi
# Wait for readiness up to 40s
STATUS=000
for i in {1..40}; do
  sleep 1
  STATUS=$(curl -o /dev/null -s -w "%{http_code}" http://127.0.0.1:$PORT/ || echo "000")
  case "$STATUS" in
    200|301|302) break;;
    *) true;;
  esac
done
if [ "$STATUS" = "000" ]; then
  echo "Server did not start; logs:" >&2
  [ -f "$SERVE_LOG" ] && sed -n '1,200p' "$SERVE_LOG" || true
  [ -f "$PREVIEW_LOG" ] && sed -n '1,200p' "$PREVIEW_LOG" || true
  kill "$SERVER_PID" >/dev/null 2>&1 || true
  wait "$SERVER_PID" 2>/dev/null || true
  exit 7
fi
# Print result for pipeline
echo "validation_status_code=$STATUS"
# clean shutdown
kill "$SERVER_PID" >/dev/null 2>&1 || true
wait "$SERVER_PID" 2>/dev/null || true
