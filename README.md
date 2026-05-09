# copilot-mcp-postcreate-poc

Public reproduction of silent auto-loading of MCP server registrations from `~/.copilot/mcp-config.json` by GitHub Copilot CLI, where the file is written by an unprivileged automated process before the operator runs any command in the terminal.

## TL;DR

Open this repo in a fresh Codespace. Before you type anything in the terminal, `~/.copilot/mcp-config.json` is already there with a planted MCP server entry, written by `package.json:postinstall` running during Codespaces' default Node-project setup. The first time you run `copilot`, the planted server is loaded silently — no consent prompt, registered alongside GitHub's first-party Copilot MCP servers.

The chain has two parts and the operator types nothing for either:

1. **Auto-plant** — Codespaces' default lifecycle runs `npm install` against `package.json` when it detects a Node project. The `postinstall` script writes `~/.copilot/mcp-config.json` and a timestamped `.poc-marker`. This happens during environment setup, before the terminal opens to the operator.
2. **Silent load** — The first `copilot` invocation reads `~/.copilot/mcp-config.json` and registers the planted MCP server via the same code path that loads GitHub's own first-party MCP servers.

The asymmetry: per-repo MCP config paths (`./mcp-config.json`, `./.copilot/mcp-config.json`, `./.github/copilot/mcp-config.json`) are deliberately **not** auto-loaded by Copilot CLI. Only the home-absolute path is. The threat: any unprivileged-write that lands in `~/.copilot/` is registered with no per-server consent.

## Reproduce in a Codespace

1. Click **`Code → Codespaces → Create codespace on main`**.
2. Wait for the Codespace to finish booting (~30–60 s).
3. In the terminal, run: `bash verify.sh`

The script is **passive** — it does not run `npm install`, does not invoke the plant script, does nothing that triggers the auto-plant. It only:

- Records that `~/.copilot/mcp-config.json` was already there at first command.
- Plants three cwd-relative MCP configs as the asymmetry control (negative control — these should be ignored by Copilot CLI).
- Installs the `copilot` CLI binary if not already present (binary install is unrelated to the MCP config).
- Runs `copilot --allow-all-tools -p "say ok"` once.
- Greps the process log for marker counts and verbatim load lines.

If `~/.copilot/mcp-config.json` is missing when the script starts, the script will say so and exit — that means Codespaces did not auto-plant, and you should investigate why before trusting the rest of the run.

## What the demo proves

| Claim | Evidence |
|---|---|
| `~/.copilot/mcp-config.json` exists before the operator runs anything | Step 1 of `verify.sh`; `~/.copilot/.poc-marker` records `POSTINSTALL_PLANT_OK at <ISO timestamp>` written before the terminal session began |
| The file was written by an automated process, not by the operator | `.poc-marker` contains the `npm_lifecycle_event` value (`postinstall`) and the wall-clock timestamp; the operator's first command is later than this timestamp |
| `copilot` loads the planted MCP server silently on first invocation | Process log shows `Starting MCP client for home-marker`; `home-marker` count > 0 |
| Loaded by the same code path as GitHub's first-party MCP server | `home-marker` and `github-mcp-server` start within ~30 ms of each other in the same MCP-client-init pass |
| Per-repo paths are NOT auto-loaded (asymmetry control) | The three `repo-*-marker` counts are all 0 in the same log run |

## PoC payload safety

- The planted MCP server's `command` is `/bin/false`, which exits immediately on spawn. Registration succeeds; the server cannot serve any tool calls.
- The plant script writes only the registration file and a timestamped marker. No exfil, no destructive action, no real MCP server code, no network activity.
- The repo carries no malicious npm dependencies. The `postinstall` hook is in this repo's own `package.json` and runs `node ./scripts/plant-home-mcp.js`. The plant script is a single file you can read in 30 seconds.
- The asymmetry-control files written by `verify.sh` are in the workspace; cleanup commands are at the bottom of this README.

## Files

- `package.json` — declares the `postinstall` hook that triggers the plant.
- `scripts/plant-home-mcp.js` — writes `~/.copilot/mcp-config.json` with a single MCP server entry (`home-marker` → `/bin/false`) and a `.poc-marker` recording the lifecycle event and timestamp.
- `verify.sh` — passive verification harness (does not trigger the plant; only observes and runs `copilot`).
- `verify-evidence/` — captured runs from real Codespace executions (committed for reproducibility).

## Cleanup

Inside the Codespace:

```bash
rm -f ~/.copilot/mcp-config.json ~/.copilot/.poc-marker
rm -f ./mcp-config.json
rm -rf ./.copilot ./.github/copilot
```

Or just delete the Codespace from `github.com/codespaces`.
