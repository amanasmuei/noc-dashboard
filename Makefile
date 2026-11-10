.PHONY: help run up down logs build ps backup reset deploy dist check pi-check pi pi-logs pi-pull pi-reset tunnel tunnel-off

PORT ?= 8080
PY   ?= python3
DATA := data/ntt.json

help:                     ## list targets
	@grep -E '^[a-z][a-z-]*:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## / — /'

run:                      ## run the local server in the foreground (PORT=8080)
	$(PY) serve.py $(PORT)

up:                       ## docker compose up -d --build
	docker compose up -d --build

down:                     ## stop the container
	docker compose down

logs:                     ## follow container logs
	docker compose logs -f

build:                    ## rebuild the image without starting it
	docker compose build

ps:                       ## container status + store health
	docker compose ps
	@curl -fsS localhost:$(PORT)/api/health && echo

check:                    ## is the server answering, and is the store valid JSON?
	@curl -fsS localhost:$(PORT)/api/health && echo
	@$(PY) -c "import json;d=json.load(open('$(DATA)'));print('store ok:',len(d),'docs')"

backup:                   ## copy the store to backups/ntt-<timestamp>.json
	@mkdir -p backups && cp $(DATA) backups/ntt-$$(date +%Y%m%d-%H%M%S).json && ls -1t backups | head -1

reset:                    ## DESTROY the store (asks first), then re-seed from the baked baseline
	@read -p "Delete $(DATA) and re-seed baseline? [y/N] " a; [ "$$a" = y ] || { echo aborted; exit 1; }
	-docker compose down
	rm -rf data
	docker compose up -d --build

dist:                     ## sync index.html into dist/ for static hosting
	cp index.html dist/index.html

deploy: dist              ## publish dist/ to Cloudflare Pages
	npx wrangler pages deploy dist --project-name noc-dashboard --branch main

# --- Raspberry Pi -------------------------------------------------------------------
PI      ?= pi@raspberrypi.local
PI_DIR  ?= /home/pi/noc

pi-check:                 ## is the Pi reachable and does it have docker + compose?
	ssh -o ConnectTimeout=5 $(PI) 'uname -m; docker --version; docker compose version'

pi:                       ## sync to the Pi, build, fix ./data ownership, restart, show status
	rsync -az --delete --exclude .git --exclude dist --exclude backups --exclude data \
	  --exclude .DS_Store --exclude .wrangler --exclude 'TNOC Dashboard*' ./ $(PI):$(PI_DIR)/
	ssh $(PI) 'cd $(PI_DIR) && docker compose build -q \
	  && docker compose run --rm --no-deps --user root noc sh -c "chown -R 10001:10001 /app/data && chmod -R a+r /app/data" \
	  && docker compose up -d && docker compose ps'

pi-logs:                  ## follow the Pi container logs
	ssh $(PI) 'cd $(PI_DIR) && docker compose logs -f --tail 50'

tunnel:                   ## quick public URL via trycloudflare.com (random host, no auth, LAN data leaves the house)
	ssh $(PI) 'cd $(PI_DIR) && docker compose --profile quick up -d quick \
	  && sleep 7 && docker compose logs --no-log-prefix quick 2>&1 | grep -o "https://[a-z0-9.-]*trycloudflare[.]com" | tail -1'

tunnel-off:               ## kill the quick tunnel
	ssh $(PI) 'cd $(PI_DIR) && docker compose --profile quick rm -sf quick'

pi-reset:                 ## DESTROY the Pi's store (asks first), then re-seed on next page load
	@read -p "Delete the store on $(PI)? [y/N] " a; [ "$$a" = y ] || { echo aborted; exit 1; }
	ssh $(PI) 'cd $(PI_DIR) && docker compose run --rm --no-deps --user root noc rm -f /app/data/ntt.json'
	@echo "store cleared - open the dashboard once to re-seed the baseline"

pi-pull:                  ## copy the Pi's live store down into backups/
	@mkdir -p backups && ssh $(PI) 'cat $(PI_DIR)/data/ntt.json' > backups/ntt-pi-$$(date +%Y%m%d-%H%M%S).json && ls -1t backups | head -1
