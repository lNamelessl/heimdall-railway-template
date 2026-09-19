# Heimdall on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/heimdall-template)

The [Heimdall](https://github.com/linuxserver/Heimdall) application dashboard (linuxserver.io) — every service and link you run behind one clean start page — deployed **auth-protected by default**, with full persistence, in one click. Pinned to the stable `lscr.io/linuxserver/heimdall` **2.8.3** build.

Upstream Heimdall ships with no authentication; on a public Railway domain that's an information-disclosure leak (your dashboard advertises every internal service you link). This template adds an HTTP basic-auth gate that is enforced by default and refuses to deploy without credentials.

## What you get on deploy

| | |
|---|---|
| Dashboard | Heimdall 2.8.3 (nginx + PHP + SQLite), served on your Railway domain |
| Auth gate | Basic auth in front of everything — anonymous visitors get a 401 challenge |
| Credentials | `DASHBOARD_PASSWORD` **auto-generated per deploy** (24 alphanum chars); user is `admin` |
| Persistence | Railway volume at `/config` — items, settings, users, icons, nginx confs survive restarts |
| Healthcheck | `/healthz` — an unauthenticated probe route the template wires into nginx (Railway's own probe can't pass an auth gate) |
| Internal pings | `ALLOW_INTERNAL_REQUESTS=true` baked in, so status pings to `<service>.railway.internal` hostnames work |

There is nothing to type at deploy time — the deploy form shows a single variable (`DASHBOARD_PASSWORD`) already set to auto-generate.

## First login

1. Open your deployment's public domain — your browser shows a basic-auth prompt.
2. User: `admin` · Password: the `DASHBOARD_PASSWORD` value from your service's **Variables** tab (or `railway variables`).
3. Click **+** in the dashboard to add links and applications (name, URL, icon). They render immediately and persist across restarts.

## The auth mechanism (how it works)

A small entrypoint wrapper ([`railway-entrypoint.sh`](./railway-entrypoint.sh)) runs before the image's s6 init and:

1. **Seeds a hardened nginx conf** — the stock linuxserver site conf with its two commented `auth_basic` blocks enabled, plus the `/healthz` probe route — into `/config/nginx/site-confs/default.conf` on first boot only (the stock init never overwrites an existing conf, and neither do we).
2. **Generates `/config/nginx/.htpasswd`** from `DASHBOARD_USER`/`DASHBOARD_PASSWORD`. A credential hash marker (`.railway-credhash`) makes this idempotent: a restart with unchanged variables never rewrites the file, while changing a variable and redeploying updates it on the next boot.
3. **Fails closed** — if credentials are missing the container exits with an explanation, so the dashboard can never boot publicly unprotected. (`DASHBOARD_AUTH_ENABLED=false` is the explicit opt-out.)
4. Then execs the untouched upstream init.

If you already have a conf on the volume without auth (or the stock one), the wrapper re-enables the auth lines in place and adds `/healthz` — marker-checked, idempotent.

## Customizing

- **Change the password / username**: edit `DASHBOARD_PASSWORD` / `DASHBOARD_USER` in the Variables tab and redeploy. The wrapper regenerates the htpasswd automatically (it only rewrites when the variables changed).
- **Baked defaults** (override any of them with a service variable): `DASHBOARD_USER=admin`, `PUID=1000`, `PGID=1000`, `TZ=Etc/UTC`, `ALLOW_INTERNAL_REQUESTS=true`.
- **Items/apps**: added in the GUI (+ button). Everything is stored in SQLite at `/config/www/app.sqlite` on the volume.
- **Nginx tweaks**: edit `/config/nginx/site-confs/default.conf` on the volume (`railway ssh`, then vi). Your edits are never overwritten; delete the file to get the hardened default back on next boot.
- **Status pings**: point items at `http://<service>.railway.internal:<port>` for Railway-internal health pings (green/red at a glance). Works because `ALLOW_INTERNAL_REQUESTS=true`.

## Cost

A single Heimdall service + its `/config` volume runs around **$3–5/month** on Railway's usage-based pricing (the service is mostly idle; the volume is the floor).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Password rejected | User is `admin`; password is `DASHBOARD_PASSWORD` in the Variables tab. |
| Locked out after changing the password variable | Redeploy — the htpasswd regenerates on next boot. |
| Deploy fails with `[railway-auth] ERROR: DASHBOARD_USER and DASHBOARD_PASSWORD must be set` | You deleted `DASHBOARD_PASSWORD`. Re-add it, or set `DASHBOARD_AUTH_ENABLED=false` to deliberately run open (not recommended). |
| Items gone after redeploy | The `/config` volume was removed. Re-attach it; seeded configs return on next boot. |
| Internal status pings red | Use the internal hostname `http://<service>.railway.internal:<port>` and keep `ALLOW_INTERNAL_REQUESTS=true`. |

## Links

- Upstream: https://github.com/linuxserver/Heimdall · Image docs: https://docs.linuxserver.io/images/docker-heimdall/
- Marketplace: https://railway.com/deploy/heimdall-template
