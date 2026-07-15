#!/usr/bin/env bash
# Rigenera il JWT Home Assistant dal refresh token "Cursor TrueNAS Session" sul NAS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=nas_common.sh
source "${SCRIPT_DIR}/nas_common.sh"

CLIENT_NAME="${HA_CLIENT_NAME:-Cursor TrueNAS Session}"
CONTAINER="${HA_CONTAINER:-ix-home-assistant-home-assistant-1}"

ssh_nas "docker exec ${CONTAINER} python3 -c \"
import json, time, jwt
with open('/config/.storage/auth') as f:
    store = json.load(f)
rt = next(r for r in store['data']['refresh_tokens'] if r.get('client_name') == '${CLIENT_NAME}')
now = int(time.time())
exp = int(rt['access_token_expiration'])
token = jwt.encode({'iss': rt['id'], 'iat': now, 'exp': now + exp}, rt['jwt_key'], algorithm='HS256')
print(token if isinstance(token, str) else token.decode())
\""
