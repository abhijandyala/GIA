#!/bin/zsh

set -u

project_root="${SRCROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
gateway_directory="$project_root/Gateway"
gateway_port="${GIA_GATEWAY_PORT:-8787}"
gateway_log="${TMPDIR:-/tmp}gia-gateway.log"

if /usr/sbin/lsof -nP -iTCP:"$gateway_port" -sTCP:LISTEN >/dev/null 2>&1; then
    exit 0
fi

if [[ ! -f "$project_root/.env" ]]; then
    echo "warning: G.I.A. gateway was not started because the untracked .env file is missing."
    exit 0
fi

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if ! command -v node >/dev/null 2>&1; then
    echo "warning: G.I.A. gateway was not started because Node.js is unavailable."
    exit 0
fi

cd "$gateway_directory" || exit 0
nohup node --env-file=../.env src/server.mjs \
    </dev/null >"$gateway_log" 2>&1 &!

for _ in {1..20}; do
    if /usr/bin/curl --silent --fail \
        "http://127.0.0.1:$gateway_port/health" >/dev/null 2>&1; then
        exit 0
    fi
    /bin/sleep 0.1
done

echo "warning: G.I.A. gateway did not become ready; see $gateway_log."
exit 0
