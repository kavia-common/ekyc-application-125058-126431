#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/ekyc-application-125058-126431/NSDL"
cd "$WORKSPACE"
[ -f package.json ] || { echo "package.json missing - run scaffold step" >&2; exit 2; }
if [ -f tsconfig.json ]; then EXT=ts; else EXT=js; fi
mkdir -p __tests__
cat > "__tests__/sanity.test.${EXT}" <<'JS'
test('sanity', ()=>{ expect(1+1).toBe(2); });
JS
export CI=true
TOOLCHAIN=$(node -e "try{const p=require('./package.json'); if((p.dependencies&&p.dependencies['react-scripts'])||(p.devDependencies&&p.devDependencies['react-scripts'])){console.log('cra');}else if((p.dependencies&&p.dependencies.vite)||(p.devDependencies&&p.devDependencies.vite)||(p.scripts&&p.scripts.dev&&p.scripts.dev.includes('vite'))){console.log('vite');}else{console.log('unknown')} }catch(e){console.log('unknown')}")
if [ -x ./node_modules/.bin/jest ]; then
  ./node_modules/.bin/jest --runInBand --silent || { echo "jest tests failed" >&2; exit 3; }
elif [ "$TOOLCHAIN" = "cra" ]; then
  npm run test --silent -- --watchAll=false || { echo "CRA tests failed" >&2; exit 4; }
else
  npm run test --silent || { echo "tests failed" >&2; exit 5; }
fi
