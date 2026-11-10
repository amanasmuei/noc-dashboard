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
