# Implementation Brief: UHT Autonomous Research Loop
# Hand this file to Claude Code as the opening prompt.
# claude --print "$(cat HANDOFF.md)"

---

## What you are building

A server-side autonomous research loop for the universalhex.org project.
The system runs on a Hetzner VPS (Ubuntu), wakes on a cron schedule, runs
a Claude Code session against a structured protocol, publishes a journal
entry to a static site, and sends a Telegram notification if findings
cross a significance threshold.

The loop is a research agent, not a product. It is designed to run
experiments on the Universal Hex Taxonomy (UHT) — a 32-bit semantic
classification system — using AIRGen (a requirements management platform)
as both a corpus to analyse and a structured store for experimental findings.

---

## Stack

- **OS**: Ubuntu on Hetzner VPS. nginx already running. Node.js and npm installed.
- **CLIs** (install globally if not present):
  - `npm install -g airgen-cli` — requirements management CLI
  - `npm install -g uht-substrate` — UHT semantic CLI
  - `claude` — Claude Code CLI (already installed)
- **Static site**: Astro (preferred) or Eleventy. Serve from nginx.
  Domain: `journal.universalhex.org` — DNS and nginx config needed.
- **Telegram bot**: `node-telegram-bot-api`. Runs as a systemd service.
- **Scheduler**: systemd timer (preferred over cron for logging).
- **Session protocol**: `/opt/uht-loop/session_protocol.md` — the prompt
  injected into each autonomous Claude Code session.

---

## Repository structure to create

```
/opt/uht-loop/
├── session_protocol.md       # The autonomous session prompt (provided below)
├── dispatcher.sh             # Runs claude, captures output, handles journal + telegram
├── .env                      # Credentials (not committed)
├── telegram-bot/
│   ├── bot.js                # Telegram bot listener
│   ├── package.json
│   └── bot.service           # systemd unit
└── journal/                  # Astro site
    ├── src/
    │   ├── pages/
    │   │   ├── index.astro
    │   │   └── [slug].astro
    │   └── content/
    │       └── posts/        # One .md file per journal entry
    ├── astro.config.mjs
    ├── package.json
    └── public/
```

---

## Credentials required

Create `/opt/uht-loop/.env`:

```bash
# AIRGen
AIRGEN_API_URL=https://api.airgen.studio/api
AIRGEN_EMAIL=<to be filled>
AIRGEN_PASSWORD=<to be filled>

# UHT Substrate
UHT_API_URL=https://substrate.universalhex.org/api
UHT_TOKEN=<to be filled>
UHT_API_KEY=<to be filled>   # airgen lint reads this key name

# Telegram
TELEGRAM_BOT_TOKEN=<to be filled>
TELEGRAM_CHAT_ID=<to be filled>

# Anthropic (for claude --print)
ANTHROPIC_API_KEY=<to be filled>

# Tenant
AIRGEN_TENANT=info-mgnzq4ln
```

The `.env` file is sourced by `dispatcher.sh` and loaded by the
Telegram bot. Do not commit it.

---

## Component 1: dispatcher.sh

`/opt/uht-loop/dispatcher.sh`

This is the heart of the system. The systemd timer calls this script.

Responsibilities:
1. Source `.env`
2. Export all env vars so `airgen` and `uht-substrate` CLIs pick them up
3. Run: `claude --print "$(cat /opt/uht-loop/session_protocol.md)"` and
   capture stdout to `/tmp/uht-session-output.md`
4. Extract the journal entry from the output. The agent outputs a markdown
   file with YAML front matter as its final stdout. Everything from the
   first `---` line to the end of output is the journal entry.
5. Write the journal entry to:
   `/opt/uht-loop/journal/src/content/posts/<YYYY-MM-DD>-<slug>.md`
   where slug is derived from the `title` field in the front matter
   (lowercase, spaces to hyphens, alphanumeric only).
6. Run the Astro build: `cd /opt/uht-loop/journal && npm run build`
7. Copy the built site to the nginx serve directory:
   `cp -r dist/* /var/www/journal.universalhex.org/`
8. Check for a pending Telegram notification by running:
   `uht-substrate facts query --predicate PENDING_NOTIFICATION --json`
   If a result exists, send the Telegram message and delete the fact.
9. Log session start/end times and exit code to
   `/var/log/uht-loop/sessions.log`

Error handling:
- If `claude --print` exits non-zero, log the error and send a Telegram
  message: "⚠️ UHT Loop — session failed. Check /var/log/uht-loop/"
- If the journal entry cannot be extracted (no front matter found),
  log a warning but do not send Telegram — the agent may have hit its
  budget limit and written a short entry without front matter.
- Never let a failed build block the Telegram notification step.

---

## Component 2: systemd timer

Create two files:

`/etc/systemd/system/uht-loop.service`:
```ini
[Unit]
Description=UHT Autonomous Research Loop Session
After=network.target

[Service]
Type=oneshot
User=steven
EnvironmentFile=/opt/uht-loop/.env
ExecStart=/opt/uht-loop/dispatcher.sh
StandardOutput=append:/var/log/uht-loop/sessions.log
StandardError=append:/var/log/uht-loop/sessions.log
```

`/etc/systemd/system/uht-loop.timer`:
```ini
[Unit]
Description=UHT Loop — run every 6 hours
Requires=uht-loop.service

[Timer]
OnCalendar=*-*-* 00,06,12,18:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable with: `systemctl enable --now uht-loop.timer`

Create the log directory: `mkdir -p /var/log/uht-loop`

---

## Component 3: Telegram bot

`/opt/uht-loop/telegram-bot/bot.js`

A Node.js service using `node-telegram-bot-api`. Listens for commands
and writes directives to the UHT fact store, which the next autonomous
session reads at initialisation.

Install: `npm install node-telegram-bot-api`

Commands to handle:

`/status` — query current loop state from UHT facts and reply:
```
UHT Loop Status
Session: #<n>
Last run: <timestamp>
Last task: <LAST_TASK_CLASS>
Last clean integrity check: <timestamp>
Next scheduled: ~<calculated from last run + 6h>
```

`/redirect <task_class>` — store a PENDING_DIRECTIVE fact:
`uht-substrate facts upsert "autonomous-loop" PENDING_DIRECTIVE "TASK:<task_class>"`
Valid values: INTEGRITY, TRACE_GAP, CALIBRATION, CORPUS_EXPANSION.
Reply: "✅ Next session will run <task_class>"

`/observe <project-slug>` — store an OBSERVE_PROJECT override:
`uht-substrate facts upsert "autonomous-loop" PENDING_DIRECTIVE "OBSERVE:<slug>"`
Reply: "✅ Next session will observe project: <slug>"

`/expand <domain>` — queue a corpus expansion target:
`uht-substrate facts store "autonomous-loop" EXPANSION_TARGET "<domain>"`
Reply: "✅ Corpus expansion queued: <domain>"

`/pause` — store a PENDING_DIRECTIVE of "PAUSE":
The dispatcher checks for this before running claude and skips the session,
logging "Paused by operator directive."
Reply: "⏸ Loop paused. Send /resume to restart."

`/resume` — delete any PAUSE directive.
Reply: "▶️ Loop resumed."

`/run-now` — trigger an immediate session by calling:
`systemctl start uht-loop.service`
Reply: "🔬 Session triggered. Journal entry will follow."

The bot must load credentials from the same `.env` file.

Systemd unit `/opt/uht-loop/telegram-bot/bot.service`:
```ini
[Unit]
Description=UHT Loop Telegram Bot
After=network.target

[Service]
Type=simple
User=steven
WorkingDirectory=/opt/uht-loop/telegram-bot
EnvironmentFile=/opt/uht-loop/.env
ExecStart=/usr/bin/node bot.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

## Component 4: Journal site (Astro)

Initialise with: `npm create astro@latest journal -- --template minimal`

Requirements:
- Clean, minimal design. Dark background preferred (#0f1117 or similar).
  Monospace or semi-monospace font for body text. High contrast.
- Index page: list of all entries, newest first, showing title, date,
  session number, and task class as a small tag.
- Entry page: full markdown rendered, front matter displayed as metadata
  below the title (date, session, task class).
- Comments: integrate Giscus (https://giscus.app). Add the script block
  to the entry page template. Leave repo/category fields as placeholders
  to be filled after the GitHub repo is created.
- The `src/content/posts/` directory is the content source. Each file
  is a markdown file with YAML front matter matching this schema:

```typescript
// src/content/config.ts
import { defineCollection, z } from 'astro:content';

const posts = defineCollection({
  schema: z.object({
    title: z.string(),
    date: z.string(),
    session: z.string(),
    session_type: z.enum(['autonomous', 'human']),
    task_class: z.string().optional(),
    status: z.enum(['published', 'draft']),
  }),
});

export const collections = { posts };
```

- Build output to `dist/`. The dispatcher copies `dist/*` to the nginx
  serve directory after each successful session.
- Include a `public/robots.txt` that allows all crawlers.
- Include an RSS feed (`/rss.xml`) using `@astrojs/rss`.

---

## Component 5: nginx config

Create `/etc/nginx/sites-available/journal.universalhex.org`:

```nginx
server {
    listen 80;
    server_name journal.universalhex.org;
    root /var/www/journal.universalhex.org;
    index index.html;

    location / {
        try_files $uri $uri/ $uri.html =404;
    }
}
```

Create the serve directory: `mkdir -p /var/www/journal.universalhex.org`
Enable: `ln -s /etc/nginx/sites-available/journal.universalhex.org /etc/nginx/sites-enabled/`
SSL: run `certbot --nginx -d journal.universalhex.org` after DNS is live.

---

## Session protocol

The file at `/opt/uht-loop/session_protocol.md` is the prompt injected
into every autonomous Claude Code session. Write this file verbatim from
the content below. Do not modify it — it is the operational document for
the agent and has been designed carefully.

```
[INSERT CONTENTS OF session_protocol.md HERE]
```

**Note for implementation:** The actual session_protocol.md content is
in a separate file. Copy it verbatim to `/opt/uht-loop/session_protocol.md`.
The dispatcher references it as `"$(cat /opt/uht-loop/session_protocol.md)"`.

---

## AIRGen uht-research project bootstrap

Before the first autonomous session runs, the `uht-research` project must
exist in AIRGen. Run this once manually to create it:

```bash
source /opt/uht-loop/.env
export AIRGEN_API_URL AIRGEN_EMAIL AIRGEN_PASSWORD

airgen projects create $AIRGEN_TENANT --name "UHT Research"

# Wait a moment, then create the four documents
airgen docs create $AIRGEN_TENANT uht-research \
  --title "Hypotheses" --kind structured
airgen docs create $AIRGEN_TENANT uht-research \
  --title "Results" --kind structured
airgen docs create $AIRGEN_TENANT uht-research \
  --title "Trait Proposals" --kind structured
airgen docs create $AIRGEN_TENANT uht-research \
  --title "Corpus Log" --kind structured

# Create an initial baseline
airgen bl create $AIRGEN_TENANT uht-research --name "INIT-$(date +%Y-%m-%d)"
```

Confirm with: `airgen projects list $AIRGEN_TENANT`

---

## Build and verification order

Build and verify in this order. Do not proceed past a failing step.

1. Install CLIs globally. Verify: `airgen tenants list --json` returns
   tenant data. `uht-substrate info` returns system info.

2. Create `/opt/uht-loop/.env` with all credentials.

3. Bootstrap the uht-research AIRGen project (manual step above).

4. Build the Astro journal site. Verify: `npm run build` completes,
   `dist/index.html` exists.

5. Configure nginx. Verify: `nginx -t` passes. The site serves at the
   server IP on port 80.

6. Write `dispatcher.sh`. Make executable: `chmod +x dispatcher.sh`.
   Do a dry run: call it with a mock `session_protocol.md` containing
   only the journal front matter block. Verify: the journal entry is
   written to the posts directory, the Astro build runs, and the output
   is copied to the nginx directory.

7. Install the systemd service and timer. Verify: `systemctl status
   uht-loop.timer` shows active. `systemctl start uht-loop.service`
   triggers a real session. Check the log.

8. Install and start the Telegram bot service. Verify: `/status` command
   returns current loop state. `/redirect INTEGRITY` stores the directive
   fact. `/run-now` triggers a session.

9. Run the first real autonomous session via `/run-now` from Telegram.
   Verify: session completes, journal entry appears on the site, Telegram
   notification received if threshold met.

---

## Notes and constraints

- The dispatcher must not run two sessions concurrently. Use a lockfile:
  `flock -n /tmp/uht-loop.lock dispatcher.sh` in the systemd service,
  or check for the lockfile at the start of the script.

- Journal entry filenames must be unique. If two sessions run on the same
  date (e.g., manual trigger + scheduled), append the session number:
  `<YYYY-MM-DD>-<session_n>-<slug>.md`

- The `claude --print` command may take 3-10 minutes for a full session.
  The systemd service has no timeout set — do not add one. The 60-tool-call
  budget in the session protocol is the natural bound.

- All credential references in scripts must come from the `.env` file via
  environment variables. No hardcoded values anywhere.

- The Telegram bot's `uht-substrate` calls must use the same environment
  variables as the dispatcher. The systemd EnvironmentFile directive
  handles this for both services.

- Do not create a GitHub repo or configure Giscus repo/category — leave
  those as clearly marked placeholders in the Astro template. The human
  will configure this separately.
