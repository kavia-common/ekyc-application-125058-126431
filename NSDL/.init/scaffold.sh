#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/ekyc-application-125058-126431/NSDL"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# ensure CI persisted
if [ ! -f /etc/profile.d/nsdl_ci.sh ]; then sudo sh -c 'echo "export CI=true" > /etc/profile.d/nsdl_ci.sh' || true; fi
# validate node/npm
if ! command -v node >/dev/null; then echo "node not found" >&2; exit 2; fi
NODE_MAJOR=$(node -v | sed -E 's/^v([0-9]+).*/\1/')
if [ "${NODE_MAJOR:-0}" -lt 16 ]; then echo "Requires Node >=16" >&2; exit 3; fi
if command -v npm >/dev/null; then NPM_MAJOR=$(npm -v | cut -d. -f1); if [ "${NPM_MAJOR:-0}" -lt 8 ]; then echo "Warning: npm <8" >&2; fi; fi
# run scaffold logic (try CRA, npx CRA, npx vite, else deterministic minimal)
if [ -f package.json ]; then
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'))||{};const deps=p.dependencies||{};const dev=p.devDependencies||{};const scripts=p.scripts||{};let modified=false; if(!deps.react){deps.react='^18.0.0';modified=true} if(!deps['react-dom']){deps['react-dom']='^18.0.0';modified=true}
  const isVite = Boolean(deps.vite||dev.vite||(scripts.dev&&scripts.dev.includes('vite')));
  const isCRA = Boolean(deps['react-scripts']||dev['react-scripts']||(scripts.start&&scripts.start.includes('react-scripts')));
  if(isVite){ if(!scripts.dev){scripts.dev='vite';modified=true} if(!scripts.build){scripts.build='vite build';modified=true} if(!scripts.start){scripts.start='vite preview --port "$PORT"';modified=true} }
  else if(isCRA){ if(!scripts.start){scripts.start='react-scripts start';modified=true} if(!scripts.build){scripts.build='react-scripts build';modified=true} }
  else { if(!scripts.dev){scripts.dev='vite';modified=true} if(!scripts.build){scripts.build='vite build';modified=true} if(!scripts.start){scripts.start='vite preview --port "$PORT"';modified=true} }
  if(modified){ p.dependencies=deps; p.devDependencies=dev; p.scripts=scripts; fs.writeFileSync('package.json',JSON.stringify(p,null,2)); console.log('package.json updated'); }
" || { echo "package.json patch failed" >&2; exit 4; }
  exit 0
fi
if command -v create-react-app >/dev/null; then
  CRA_VER=$(create-react-app --version 2>/dev/null || true)
  if echo "$CRA_VER" | sed -E 's/^([0-9]+).*/\1/' | grep -E '^[0-9]+$' >/dev/null; then
    CRA_MAJOR=$(echo "$CRA_VER" | sed -E 's/^([0-9]+).*/\1/')
  else
    CRA_MAJOR=0
  fi
  if [ "$CRA_MAJOR" -ge 5 ]; then
    create-react-app . --use-npm >/dev/null 2>&1 || true
    if [ -f package.json ]; then exit 0; fi
  fi
fi
if command -v npx >/dev/null; then
  timeout 120s npx create-react-app@latest . --use-npm >/dev/null 2>&1 || true
  if [ -f package.json ]; then exit 0; fi
fi
if command -v npx >/dev/null; then
  timeout 60s npx create-vite@latest . -- --template react >/dev/null 2>&1 || true
  if [ -f package.json ]; then exit 0; fi
fi
# deterministic minimal fallback
cat > package.json <<'JSON'
{ "name":"nsdl-frontend","version":"0.1.0","private":true,"scripts":{"dev":"vite","build":"vite build","start":"vite preview --port $PORT","test":"jest --runInBand"},"dependencies":{"react":"^18.0.0","react-dom":"^18.0.0"} }
JSON
mkdir -p src && cat > src/main.jsx <<'JS'
import React from 'react'
import { createRoot } from 'react-dom/client'
function App(){return React.createElement('div',null,'NSDL Dev Environment')}
const root=document.createElement('div');root.id='root';document.body.appendChild(root);createRoot(root).render(React.createElement(App));
JS
cat > index.html <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>
HTML
