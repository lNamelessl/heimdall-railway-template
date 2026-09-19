# Heimdall on Railway — your service dashboard, auth-protected in one click

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/WIKRNI)

Heimdall (by linuxserver.io) is the minimal application dashboard: every link, service, and tool you run, behind one clean start page. This template ships it the way a public deployment should be shipped — **with a login gate enforced by default** (upstream Heimdall has none), a persistent volume for your dashboard, and zero configuration required at deploy time.

Pinned to the stable `linuxserver/heimdall` **2.8.3** build. Deploys as a single service: nginx + PHP app + SQLite, all state on one volume.

| | |
|---|---|
| App | Heimdall 2.8.3 (linuxserver.io image), served on your Railway domain |
| Auth gate | HTTP basic auth in front of everything — anonymous visitors get a 401 challenge |
| Credentials | `DASHBOARD_PASSWORD` is **auto-generated per deploy** (user: `admin`) |
| Persistence | Railway volume at `/config` — items, settings, users, icons, nginx confs survive restarts |
| Healthcheck | `/healthz` (unauthenticated probe route, wired by the template) |

# Deploy and Host

## About Hosting

Deploying this template provisions exactly one Railway service:

- **heimdall** — built from the pinned `lscr.io/linuxserver/heimdall:2.8.3` image plus a small boot wrapper (`railway-entrypoint.sh`) that, before the app's init runs:
  1. seeds a hardened nginx site conf into `/config` (stock conf with basic auth enabled and the `/healthz` probe route added),
  2. writes `/config/nginx/.htpasswd` from the `DASHBOARD_USER` / `DASHBOARD_PASSWORD` variables (only when credentials changed — a restart with unchanged variables never rewrites it),
  3. hands off to the untouched upstream init.

One Railway volume is mounted at `/config` — Heimdall keeps its entire state there (SQLite database `app.sqlite`, app `.env`, nginx configs, icons/avatars/uploads), so your dashboard survives every restart and redeploy.

There is nothing to type at deploy time: the deploy form shows a single variable, `DASHBOARD_PASSWORD`, already set to auto-generate a 24-character random password per deployment. Read it after deploying in your service's **Variables** tab.

## Why Deploy

- **Upstream has no auth.** Stock Heimdall is wide open — on the public internet that's an information-disclosure leak (it advertises every internal service you link). This template refuses to deploy unprotected: the auth gate is on by default and the boot wrapper fails the deploy if credentials are missing.
- **The upstream installer is flaky; this image is not.** No install scripts at deploy time — a pinned, verified image build, with the app pre-installed and migrated on first request.
- **Private-network pings work.** `ALLOW_INTERNAL_REQUESTS` is baked in as `true`, so Heimdall's status pings against Railway-internal hostnames (`http://xxx.railway.internal:port`) are allowed instead of refused.
- **One volume, one service** — the whole deployment is a single billable line, roughly **$3–5/month** on Railway's usage-based pricing.

## Common Use Cases

- **Personal start page**: pin links to Proxmox, Router, NAS, Sonarr, Grafana — one HTTPS bookmark instead of twenty.
- **Team/agency service map**: a shared landing page of tools (with a password, not open to the world).
- **Homelab-on-Railway companion**: link and status-ping your other Railway services via their `.railway.internal` hostnames — Heimdall shows green/red at a glance.
- **Client hand-off portal**: deploy a fresh gated dashboard per client from this one-click template.

After deploying: open your Railway domain → log in with user `admin` and the generated `DASHBOARD_PASSWORD` (Variables tab) → click **+** to add links/apps (name, URL, icon) → they render on the dashboard and persist.

## Dependencies for

Almost none by design — the template is self-contained.

### Deployment Dependencies

- A Railway account (Hobby plan is sufficient; ~$3–5/mo for this service + volume).
- No external database — Heimdall uses SQLite stored on the `/config` volume.
- No deploy-form inputs: `DASHBOARD_PASSWORD` auto-generates; `PUID`/`PGID`/`TZ`/`ALLOW_INTERNAL_REQUESTS`/`DASHBOARD_USER` are baked as image defaults (`admin`, `1000`, `Etc/UTC`, `true`) and can be overridden later as service variables.
- Status pings against Railway-internal hostnames need nothing extra (internal requests are allowed by the baked default). Pinged services must expose the port you reference.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Browser keeps asking for a password | The user is `admin` and the password is the `DASHBOARD_PASSWORD` value in your service's **Variables** tab (values are hidden until you reveal them). |
| Locked out after changing `DASHBOARD_PASSWORD` | Set the variable, then redeploy — the boot wrapper regenerates the htpasswd on the next boot (it only rewrites when the variables changed). |
| Deploy fails with auth errors in logs | You deleted `DASHBOARD_PASSWORD`. The wrapper refuses to boot a public dashboard without credentials. Re-add it (or set `DASHBOARD_AUTH_ENABLED=false` to deliberately run open — not recommended). |
| Items disappeared after redeploy | You removed the volume or its mount. Re-attach a volume at `/config`; the seeded configs return on the next boot. |
| Status pings show red for internal services | Use the target service's Railway-internal hostname in the form `http://SERVICE.railway.internal:PORT` (e.g. `http://myapp-production.up.railway.internal:3000`), and make sure `ALLOW_INTERNAL_REQUESTS` is `true` (it is by default in this template). |
| Want to turn the auth gate off | Set `DASHBOARD_AUTH_ENABLED=false` and redeploy. Not recommended on a public domain. |

## Links

- Upstream: https://github.com/linuxserver/Heimdall · Image docs: https://docs.linuxserver.io/images/docker-heimdall/
- Template repo: https://github.com/lNamelessl/heimdall-railway-template
