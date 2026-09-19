#!/usr/bin/with-contenv bash
# Railway boot wrapper for linuxserver/heimdall.
#
# Runs BEFORE the image's s6 init (/init): on a fresh volume it seeds a
# hardened nginx site conf (basic auth on, unauthenticated /healthz route),
# generates the htpasswd from DASHBOARD_USER/DASHBOARD_PASSWORD, then hands
# off to the untouched upstream boot.
#
# Idempotency contract:
#   - the site conf is only written when missing (never clobbers user edits);
#     if it exists but lacks auth, the auth lines are (re-)enabled in place
#   - the htpasswd is only regenerated when the credential variables changed
#     (tracked via a hash marker) - a restart with unchanged variables never
#     rewrites or locks you out; rotating DASHBOARD_USER/PASSWORD and
#     redeploying updates the file on the next boot

set -e

CONF_DIR="/config/nginx/site-confs"
SITE_CONF="$CONF_DIR/default.conf"
HTPASSWD="/config/nginx/.htpasswd"
CREDHASH_FILE="/config/nginx/.railway-credhash"
SEED_CONF="/defaults/railway-default.conf"

echo "[railway-auth] Railway wrapper: preparing /config"

# --- 1. Seed the hardened site conf on a fresh volume -----------------------
# The stock init only writes default.conf when none exists, so a file seeded
# here (before /init runs) deterministically wins.
if [ ! -e "$SITE_CONF" ] && [ -f "$SEED_CONF" ]; then
    mkdir -p "$CONF_DIR"
    cp "$SEED_CONF" "$SITE_CONF"
    echo "[railway-auth] Fresh volume: seeded hardened nginx site conf"
fi

if [ ! -e "$SITE_CONF" ]; then
    echo "[railway-auth] ERROR: no nginx site conf at $SITE_CONF - cannot wire auth"
    exit 1
fi

# --- 2. Respect the explicit opt-out ----------------------------------------
if [ "$DASHBOARD_AUTH_ENABLED" = "false" ]; then
    echo "[railway-auth] DASHBOARD_AUTH_ENABLED=false - basic auth not enforced"
    exec /init "$@"
fi

# --- 3. Credentials are mandatory (fail closed, never boot unprotected) -----
if [ -z "$DASHBOARD_USER" ] || [ -z "$DASHBOARD_PASSWORD" ]; then
    echo "[railway-auth] ERROR: DASHBOARD_USER and DASHBOARD_PASSWORD must be set."
    echo "[railway-auth] This template refuses to boot a public dashboard without auth."
    echo "[railway-auth] To intentionally run without a gate, set DASHBOARD_AUTH_ENABLED=false."
    exit 1
fi

# --- 4. htpasswd: generate once, regenerate only on credential change -------
CREDHASH="$(printf '%s' "$DASHBOARD_USER:$DASHBOARD_PASSWORD" | md5sum | cut -d' ' -f1)"
if [ -f "$HTPASSWD" ] && [ -f "$CREDHASH_FILE" ] && [ "$(cat "$CREDHASH_FILE" 2>/dev/null)" = "$CREDHASH" ]; then
    echo "[railway-auth] Credentials unchanged - htpasswd left untouched"
else
    mkdir -p /config/nginx
    TMP_HTP="$(mktemp)"
    if command -v htpasswd >/dev/null 2>&1; then
        htpasswd -b -c "$TMP_HTP" "$DASHBOARD_USER" "$DASHBOARD_PASSWORD" >/dev/null
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s:%s\n' "$DASHBOARD_USER" "$(openssl passwd -apr1 "$DASHBOARD_PASSWORD")" > "$TMP_HTP"
    else
        # last resort so the gate still works: nginx understands {PLAIN}
        printf '%s:{PLAIN}%s\n' "$DASHBOARD_USER" "$DASHBOARD_PASSWORD" > "$TMP_HTP"
    fi
    chmod 644 "$TMP_HTP"
    mv "$TMP_HTP" "$HTPASSWD"
    printf '%s\n' "$CREDHASH" > "$CREDHASH_FILE"
    echo "[railway-auth] htpasswd written for user '$DASHBOARD_USER'"
fi

# --- 5. Patch a pre-existing site conf: enable auth + healthz route ---------
# Covers volumes whose conf predates this wrapper or was regenerated from the
# stock sample: both stock auth blocks are commented; uncomment them in place.
if grep -q '^auth_basic_user_file' "$SITE_CONF"; then
    echo "[railway-auth] Auth already enabled in site conf"
else
    sed -i 's|^#auth_basic_user_file /config/nginx/.htpasswd;|auth_basic_user_file /config/nginx/.htpasswd;|' "$SITE_CONF"
    sed -i 's|^#auth_basic |auth_basic |' "$SITE_CONF"
    echo "[railway-auth] Enabled basic auth lines in existing site conf"
fi

if ! grep -q 'BEGIN RAILWAY HEALTHZ' "$SITE_CONF"; then
    HLTH="$(mktemp)"
    cat > "$HLTH" <<'EOF'
    # BEGIN RAILWAY HEALTHZ (managed by the Railway template - safe to delete)
    location = /healthz { auth_basic off; access_log off; add_header Content-Type text/plain; return 200 "ok\n"; }
    # END RAILWAY HEALTHZ
EOF
    sed -i '/server_name _;/r '"$HLTH" "$SITE_CONF"
    rm -f "$HLTH"
    echo "[railway-auth] Added unauthenticated /healthz route to site conf"
fi

echo "[railway-auth] Handing off to upstream init"
exec /init "$@"
