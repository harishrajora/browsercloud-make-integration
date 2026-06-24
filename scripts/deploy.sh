#!/usr/bin/env bash
#
# deploy.sh — push this repo's app definition to a Make custom app via the Make API.
# Idempotent: creates any missing modules, then overwrites base/connection/module code.
#
# Config via env (with sensible defaults for this project):
#   MAKE_APP          app name slug on Make   (default: test-mu-ai-browser-cloud-zpofey)
#   MAKE_APP_VERSION  app version             (default: 1)
#   MAKE_API_KEY      API token               (default: read from VS Code settings.json active env)
#   MAKE_ZONE         zone e.g. eu1           (default: read from settings.json, else eu1)
#
# Usage:  bash scripts/deploy.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="${MAKE_APP:-test-mu-ai-browser-cloud-zpofey}"
VER="${MAKE_APP_VERSION:-1}"
SETTINGS="${MAKE_SETTINGS:-$HOME/Library/Application Support/Code/User/settings.json}"

# --- resolve API key + zone -------------------------------------------------
if [ -n "${MAKE_API_KEY:-}" ]; then
  KEY="$MAKE_API_KEY"; ZONE="${MAKE_ZONE:-eu1}"
else
  read -r KEY ZONE < <(python3 - "$SETTINGS" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
envs={e["uuid"]:e for e in d["apps-sdk.environments"]}
e=envs[d["apps-sdk.environment"]]
print(e["apikey"], e["url"].split(".")[0])
PY
)
fi
API="https://${ZONE}.make.com/api/v2/sdk"
AUTH=(-H "Authorization: Token $KEY")
JC=(-H "Content-Type: application/jsonc")
JS=(-H "Content-Type: application/json")

say(){ printf "%-22s %s\n" "$1" "$2"; }
put(){ # put <file> <url> <label>
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "${AUTH[@]}" "${JC[@]}" --data-binary @"$1" "$2")
  say "$3" "[$code]"
}

echo "== Deploying $APP v$VER to $ZONE =="

# --- base -------------------------------------------------------------------
put "$REPO_DIR/general/base.imljson" "$API/apps/$APP/$VER/base" "base"

# --- connection (ensure exists, then push api + parameters) -----------------
CONN=$(curl -s "${AUTH[@]}" "$API/apps/$APP/connections" \
  | python3 -c "import json,sys;c=json.load(sys.stdin).get('appConnections',[]);print(c[0]['name'] if c else '')")
if [ -z "$CONN" ]; then
  CONN=$(curl -s -X POST "${AUTH[@]}" "${JS[@]}" \
    -d '{"type":"basic","label":"TestMu AI Browser Cloud"}' "$API/apps/$APP/connections" \
    | python3 -c "import json,sys;print(json.load(sys.stdin)['appConnection']['name'])")
  say "connection created" "$CONN"
fi
put "$REPO_DIR/connections/browsercloud/api.imljson"        "$API/apps/connections/$CONN/api"        "connection/api"
put "$REPO_DIR/connections/browsercloud/parameters.imljson" "$API/apps/connections/$CONN/parameters" "connection/params"

# --- modules (create missing, then push api/expect/interface) ---------------
EXISTING=$(curl -s "${AUTH[@]}" "$API/apps/$APP/$VER/modules" \
  | python3 -c "import json,sys;print(' '.join(m['name'] for m in json.load(sys.stdin).get('appModules',[])))")

# iterate modules declared in makecomapp.json (name, label, description)
python3 - "$REPO_DIR/makecomapp.json" <<'PY' | while IFS=$'\t' read -r name label desc; do
import json,sys
d=json.load(open(sys.argv[1]))
for n,m in d["components"]["module"].items():
    print(f"{n}\t{m['label']}\t{m['description']}")
PY
  if ! grep -qw "$name" <<<"$EXISTING"; then
    python3 -c "import json,sys;print(json.dumps({'name':sys.argv[1],'label':sys.argv[2],'description':sys.argv[3],'typeId':4,'connection':sys.argv[4]}))" \
      "$name" "$label" "$desc" "$CONN" > /tmp/_mod.json
    curl -s -o /dev/null -w "module create $name [%{http_code}]\n" -X POST "${AUTH[@]}" "${JS[@]}" --data-binary @/tmp/_mod.json "$API/apps/$APP/$VER/modules"
  fi
  # keep label + description in sync on every deploy (idempotent)
  python3 -c "import json,sys;print(json.dumps({'label':sys.argv[1],'description':sys.argv[2]}))" "$label" "$desc" > /tmp/_modmeta.json
  curl -s -o /dev/null -w "module/$name meta [%{http_code}]\n" -X PATCH "${AUTH[@]}" "${JS[@]}" --data-binary @/tmp/_modmeta.json "$API/apps/$APP/$VER/modules/$name"
  put "$REPO_DIR/modules/$name/api.imljson"        "$API/apps/$APP/$VER/modules/$name/api"       "module/$name api"
  put "$REPO_DIR/modules/$name/parameters.imljson" "$API/apps/$APP/$VER/modules/$name/expect"    "module/$name expect"
  put "$REPO_DIR/modules/$name/interface.imljson"  "$API/apps/$APP/$VER/modules/$name/interface" "module/$name iface"
  if [ -f "$REPO_DIR/modules/$name/samples.imljson" ]; then
    put "$REPO_DIR/modules/$name/samples.imljson"  "$API/apps/$APP/$VER/modules/$name/samples"  "module/$name samples"
  fi
done

# --- optional: icon + theme (only if present) -------------------------------
if [ -f "$REPO_DIR/assets/icon.png" ]; then
  curl -s -o /dev/null -w "icon [%{http_code}]\n" -X PUT "${AUTH[@]}" -H "Content-Type: image/png" \
    --data-binary @"$REPO_DIR/assets/icon.png" "$API/apps/$APP/$VER/icon"
fi

echo "== Done =="
