# Heimdall (application dashboard) on Railway, behind a basic-auth gate.
#
# Pinned to linuxserver.io's stable 2.8.3 release build of the image
# (lscr.io/linuxserver/heimdall tracks the same builds; "latest" is the
# moving tag - 2.8.3 is the pinned snapshot this template is verified on).
FROM lscr.io/linuxserver/heimdall:2.8.3

# Hardened nginx site conf (stock default + basic auth on + /healthz route),
# placed next to the stock samples; the entrypoint wrapper seeds it into
# /config on first boot only. /defaults already exists in the upstream image.
COPY seed/default.conf /defaults/railway-default.conf
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod 755 /usr/local/bin/railway-entrypoint.sh

# Upstream image facts (verified from linuxserver/docker-heimdall @ 2.8.3):
#   ENTRYPOINT ["/init"] (s6-overlay v3); EXPOSE 80 443; VOLUME /config
#   - our wrapper runs its prep, then execs /init unchanged
#   - all state persists on the /config volume: SQLite DB (/config/www/
#     app.sqlite), app .env, nginx confs (/config/nginx/), icons/uploads

# Sensible defaults baked into the image so the template deploys with zero
# form prompts. Every value can be overridden on Railway by adding a service
# variable with the same name (Variables tab) and redeploying.
ENV PUID=1000 \
    PGID=1000 \
    TZ=Etc/UTC \
    ALLOW_INTERNAL_REQUESTS=true \
    DASHBOARD_USER=admin

# The login password is NOT here on purpose: DASHBOARD_PASSWORD is a
# per-deploy generated secret (template variable default ${{secret(24)}}).
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
