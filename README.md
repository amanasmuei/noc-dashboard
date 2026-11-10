# TNOC Dashboard 2026

Self-contained dashboard. One HTML page, no build step.

## Run locally (recommended)

```bash
python3 serve.py          # port 8080, or: python3 serve.py 8099
open http://localhost:8080
```

Share it on the LAN with `http://<this-mac-ip>:8080`. Every browser that opens that
address reads and writes the same store, so an upload is the latest data for everyone.

- **Store:** `data/ntt.json` — one doc per month (`ntt/m01`…`ntt/m12`), plus
  `ntt/faultrate`, `meta/seed` and the `uploads/` log. Written atomically.
- **Backup / history:** `git add data/` (or copy the folder). No cloud, no auth —
  anyone who can reach the port can publish, so run it on a trusted machine.
- **Reset to baked baseline:** stop the server, `rm -rf data/`, start again. First
  load seeds `data/ntt.json` from the dataset baked into `index.html`.

## Open `index.html` directly (no server)

Works, but the store falls back to `localStorage` of that one browser: uploads do not
cross browsers or machines, and clearing site data wipes them.

## Docker

```bash
docker compose up -d --build          # http://localhost:8080
docker compose logs -f
docker compose down
```

Data lives in `./data` (bind-mounted to `/app/data`), so rebuilds never touch it.
Reset = `docker compose down && rm -rf data && docker compose up -d`.

Plain docker:

```bash
docker build -t noc-dashboard .
docker run -d -p 8080:8080 -v "$PWD/data:/app/data" --restart unless-stopped noc-dashboard
```

Image is `python:3.12-alpine`, runs as uid 10001, has a `/api/health` healthcheck,
and honours `PORT` if you need a different internal port.

## Make

```bash
make help          # all targets
make run PORT=8090 # local python server, foreground
make up            # docker compose up -d --build (PORT=8080 by default)
make ps check logs down
make backup        # backups/ntt-<timestamp>.json
make reset         # asks first: wipe data/ and re-seed the baked baseline
make deploy        # dist/ -> Cloudflare Pages
```

`make run` and `make up` both take `PORT`; don't run both on the same port.

## Raspberry Pi

```bash
make pi-check PI=aman@192.168.1.116                       # arch + docker + compose
make pi       PI=aman@192.168.1.116 PI_DIR=/home/aman/noc  # sync, build, chown ./data, restart
make pi-logs  PI=…   PI_DIR=…
make pi-pull  PI=…   PI_DIR=…        # live store -> backups/ntt-pi-<ts>.json
make pi-reset PI=…   PI_DIR=…        # wipe the store, re-seed on next page load
```

Run mode is `docker compose` on the Pi, `restart: unless-stopped`, so it comes back after reboot.
The container runs as uid `10001`, so `./data` on the Pi is owned by that uid — use the targets
above instead of editing files there by hand (or prefix with `sudo`).
