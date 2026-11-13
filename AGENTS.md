# AGENTS.md

Hands-on build of a WoW 3.3.5a (WotLK) private server: AzerothCore + mod-playerbots, sized for ~10 real players + 50+ bots. This repo holds the compose file, docs, and config references only — the server source is cloned and its Docker images built in a separate working directory.

## How it is wired

- Server source: clone `mod-playerbots/azerothcore-wotlk` branch **`Playerbot`** (NOT upstream AzerothCore master) into a separate WORK_DIR, then clone the modules listed in `docs/server.md` into its `modules/` dir. Build there: `DOCKER_IMAGE_TAG=<tag> docker compose build`.
- `docker compose up` runs from **this repo root**. Services use prebuilt/built images `acore/ac-wotlk-{db-import,worldserver,authserver,client-data}:${DOCKER_IMAGE_TAG}` (default tag `master`).
- Local customization is done **directly in `docker-compose.yml`** (mysql.cnf mount + per-service `mem_limit` are in there; the file's upstream "don't edit me" header no longer reflects this repo's practice — no `docker-compose.override.yml` exists). MySQL tuning lives in `conf/mysql.cnf` → `ac-database:/etc/mysql/conf.d/custom.cnf:ro`, path overridable via `$MYSQL_CNF` (exported by `start-server.sh` to `$RUNTIME_DIR/conf/mysql.cnf`); apply with `docker compose up -d ac-database`, then bring world/auth back up.
- **Host RAM is dominated by a local LLM (~100G); the WoW server must stay within ~20G.** Memory limits (`mem_limit`, env-overridable like `DOCKER_WORLD_MEM_LIMIT`): db 6g (must stay > `innodb_buffer_pool_size` = 4g in mysql.cnf), world 8g, auth 512m, db-import 1g, client-data-init 256m, tools 4g (run that profile with the LLM unloaded). If world/auth restart-loop after load, check `docker inspect --format '{{.State.OOMKilled}}'` before debugging anything else.
- `docs/server.md` is the authoritative module set & build flow; `docs/client.md` is still a stub.
- Laptop → Strix Halo PC code sync: `bash sync-to-pc.sh --target-ip <ip> [--port <n>] [--folder <path>] [--dry-run]` (one-way rsync; excludes `.git`, `opencode.json*`, `.DS_Store`; never touches the PC's `$HOME/WtoLK/runtime`). On the PC follow up with `start-server.sh --refresh-conf`. Git remote (`origin`, GitHub) is the durable path; the sync script is for fast test iteration.

## Starting the server

1. `bash start-server.sh [--image-tag <tag>] [--runtime-dir <dir>] [--db-password-file <file>] [--compose-file <file>] [--refresh-conf]` — bootstrap only: creates `$HOME/WtoLK/runtime/{conf,db,data,logs}`, prompts to copy repo `conf/*` templates into `$RUNTIME_DIR/conf/` (first time only; existing files are never overwritten, no-TTY defaults to copy), generates `$RUNTIME_DIR/db.password` if missing. `--refresh-conf` skips the prompt and force-syncs runtime conf from the repo (repo wins, recursive) — use it after every `git pull`/`rsync` that changed `conf/`, otherwise runtime copies go stale silently. It does **not** launch the server — it prints an `export ...` block plus `docker compose up -d` command to paste. `--compose-file` uses a custom compose file (printed as `docker compose -f <file> up -d`; note `-f` disables auto-loading of `docker-compose.override.yml`).
2. Run that printed block from this repo root. Defaults in compose (`./env/dist/...`, password `password`) are wrong for this setup — the env exports are required. Compose reads `$RUNTIME_DIR/conf/env.ac` via `env_file` for worldserver/authserver; without it compose fails.

## Gotchas

- Runtime dir defaults to `$HOME/WtoLK/runtime`, **not** the repo's `conf/` dir (the latter only holds templates: `env.ac`, `env.docker`).
- The `tools` compose profile (map extraction) has `dockerfile: apps/docker/Dockerfile` relative to `.` — it can only build inside the azerothcore clone, not from this repo root. Usually unneeded: `ac-client-data-init` populates the `ac-client-data` volume with maps.
- MySQL 8.4 container `ac-database`; databases: `acore_auth`, `acore_world`, `acore_characters`, `acore_playerbots`. First boot runs `ac-db-import`, which is slow — world/auth wait on it.
- Ports: 3724 auth, 8085 world, 7878 SOAP (RAS console).
- Docker daemon often needs an HTTP proxy set via systemd to pull packages during image builds (recipe in `docs/server.md`).
- `opencode.jsonc` is gitignored on purpose (local model/provider config).
