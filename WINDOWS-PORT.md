# Windows native launcher notes

Changes to `launch-windows.ps1` in this fork:

- Installs the full `chromadb` package into a separate `venv-chroma` (it conflicts with
  `chromadb-client` from `requirements.txt`) and starts it on `CHROMADB_HOST:CHROMADB_PORT`
  (default `localhost:8100`), like `start-macos.sh` does. It is stopped when the launcher exits.
- Sets `PYTHONUTF8=1` so text I/O does not use the legacy ANSI codepage.
- Warns when Node.js (`npx`) is missing, since the built-in Browser MCP server needs it.

## What was tested (Windows 11, Python 3.12/3.13, Node 26)

- Fresh extract of upstream `dev`: launcher creates both venvs, runs setup, starts ChromaDB and
  the server; `/api/health` is 200, login works, tool index loads (93 tools), all five built-in
  MCP servers connect.
- Interactive admin prompt appears on a real terminal (not driven through).
- Ctrl+C stops the server and ChromaDB; no processes or listeners remain.
- `build-windows-portable.ps1` output (`Odysseus.exe`) starts and reports healthy.

## Not verified

- Machine with no Python installed.
- Full test suite: about 379 tests fail on Windows (mostly Linux-only sandbox/containment and
  tests needing `npm install`). They were not triaged here.
