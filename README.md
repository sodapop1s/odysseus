<p align="center">
  <img src="assets/branding/odysseus-wordmark.png" alt="Odysseus" width="238">
</p>

<p align="center">
  A self-hosted AI workspace for chat, agents, research, documents, email, notes, calendar, and local model workflows.
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> ·
  <a href="website/setup.md">Setup Guide</a> ·
  <a href="CONTRIBUTING.md">Contributing</a> ·
  <a href="ROADMAP.md">Roadmap</a>
</p>

<p align="center">
  <a href="https://repology.org/project/odysseus-ai/versions"><img src="https://repology.org/badge/vertical-allrepos/odysseus-ai.svg" alt="Packaging status"></a>
</p>

<p align="center">
  <img src="assets/branding/odysseus-browser.jpg" alt="Odysseus interface">
</p>

---

## Quick Start (Windows, native, no Docker)

> This is a fork of [odysseus-dev/odysseus](https://github.com/odysseus-dev/odysseus) focused on running natively on Windows. The Windows changes live on the `windows-launcher-chromadb` branch. Upstream does not actively test Windows; see [WINDOWS-PORT.md](WINDOWS-PORT.md) for exactly what was and was not verified here.

**1. Install the prerequisites** (PowerShell):

```powershell
winget install -e --id Python.Python.3.12
winget install -e --id Git.Git
winget install -e --id OpenJS.NodeJS.LTS
```

Python 3.11+ and Git are required. Node.js is optional but needed for the built-in Browser tool. Open a new terminal afterwards so the new programs are on `PATH`.

**2. Get the code and start it:**

```powershell
git clone --branch windows-launcher-chromadb https://github.com/sodapop1s/odysseus.git
cd odysseus
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1
```

The first run takes a few minutes. The launcher is safe to re-run, and it:

1. finds Python 3.11+ and creates a `venv`;
2. installs the dependencies from `requirements.txt`;
3. installs ChromaDB into a separate `venv-chroma` (used for the tool index, RAG and semantic memory);
4. runs first-time setup and asks you to choose an admin username and password;
5. starts ChromaDB on `127.0.0.1:8100`, then the web server.

**3. Open `http://127.0.0.1:7000`** and sign in with the admin account you created. Add a model endpoint (for example a local Ollama, or an API key) under Settings before chatting.

Press **Ctrl+C** in the terminal to stop. That stops both the web server and ChromaDB.

### Options

```powershell
# different port, or expose on your LAN (only if you mean to)
powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 -Port 7001 -BindHost 0.0.0.0
```

| Setting | How to change it |
|---|---|
| ChromaDB host/port | `CHROMADB_HOST` / `CHROMADB_PORT` environment variables (a non-local host is not started for you) |
| Admin account without a prompt | set `ODYSSEUS_ADMIN_USER` and `ODYSSEUS_ADMIN_PASSWORD` before the first run |
| Other settings | `.env` (created from `.env.example` on first run), see the [setup guide](website/setup.md) |

All user data lives in `data\` and logs in `logs\`. Both are git-ignored.

### Portable `.exe`

To build a standalone `Odysseus.exe` (system-tray app, opens your browser on port 7011):

```powershell
powershell -ExecutionPolicy Bypass -File .\build-windows-portable.ps1
```

The output is in `dist\Odysseus`. Keep the whole folder together.

### Troubleshooting

- **"running scripts is disabled"**: use the `-ExecutionPolicy Bypass -File` form shown above instead of running the script directly.
- **Path errors while extracting or cloning**: keep the checkout in a short path such as `C:\odysseus` (Windows long paths are off by default).
- **Browser tool unavailable**: install Node.js (`winget install OpenJS.NodeJS.LTS`) and restart the launcher.
- **Vector memory or RAG shows as degraded**: check `logs\chromadb.err.log`, and make sure nothing else is using port 8100.
- **Shell and sandbox tools**: Linux-only sandboxing (bwrap and similar) is not available on Windows, so the agent's shell tool reports "containment unavailable". Installing Git for Windows provides `bash.exe` for Cookbook background downloads.

### Docker

Docker still works as upstream documents it. See the [setup guide](website/setup.md) for the compose instructions and production tag pinning.

Native installs, GPU notes, Windows/macOS instructions, HTTPS, and configuration live in the [setup guide](website/setup.md).

## Features

- **Chat + Agents** — local/API models, tools, MCP, files, shell, skills, and memory.
- **Cookbook** — hardware-aware model recommendations, downloads, and serving.
- **Deep Research** — multi-step web research with source reading and report generation.
- **Compare** — blind side-by-side model testing and synthesis.
- **Documents** — writing-first editor with AI edits, suggestions, Markdown, HTML, CSV, and syntax highlighting.
- **Email** — IMAP/SMTP inbox with triage, tags, summaries, reminders, and reply drafts.
- **Notes, Tasks + Calendar** — reminders, todos, scheduled agent tasks, and CalDAV sync.
- **Extras** — gallery/image editor, themes, uploads, web search, presets, sessions, and 2FA.

## Demo

A full hover-to-play tour lives on the [Odysseus landing page](https://odysseus-dev.github.io/odysseus/). Its source lives under [`website/`](website/).

## Contributing

Help is welcome. The best entry points are fresh-install testing, provider setup bugs, mobile/editor polish, docs, and small focused refactors. See [CONTRIBUTING.md](CONTRIBUTING.md) and [ROADMAP.md](ROADMAP.md).

## Security

Odysseus is a self-hosted workspace with powerful local tools. Keep auth enabled, keep private data out of Git, and do not expose raw model/service ports publicly.

- Keep `AUTH_ENABLED=true` for any network-accessible deployment.
- Keep `LOCALHOST_BYPASS=false` outside local development.

Deployment details are in the [setup guide](website/setup.md#security-notes).

## Community & Growth

<p align="center">
  <a href="https://trendshift.io/repositories/43167">
      <a href="https://trendshift.io/repositories/43167?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-43167" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/43167/monthly" alt="odysseus-dev%2Fodysseus | Trendshift" width="230"/></a>
  </a>
</p>

<p align="center">
  <a href="https://star-history.dera.page/#odysseus-dev/odysseus&type=date&legend=top-left">
    <picture>
      <source
        media="(prefers-color-scheme: dark)"
        srcset="https://star-history.dera.page/svg?repos=odysseus-dev/odysseus&type=date&theme=dark&legend=top-left"
      />
      <source
        media="(prefers-color-scheme: light)"
        srcset="https://star-history.dera.page/svg?repos=odysseus-dev/odysseus&type=date&legend=top-left"
      />
      <img
        src="https://star-history.dera.page/svg?repos=odysseus-dev/odysseus&type=date&legend=top-left"
        alt="Odysseus GitHub star history"
        width="100%"
      />
    </picture>
  </a>
</p>

## License

AGPL-3.0-or-later -- see [LICENSE](LICENSE) and [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).
