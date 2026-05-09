#!/usr/bin/env bash
# verify.sh — passive verification harness for copilot-mcp-supplychain-poc.
#
# This script does NOT run npm install, does NOT invoke the plant script,
# does NOT trigger the auto-plant. It only OBSERVES the post-boot state
# and runs copilot once to measure load behavior.
#
# Run inside a fresh Codespace, AFTER the Codespace has finished booting,
# as the FIRST command the operator types in the terminal.

set -u

OUT=verify-evidence/$(date -u +'run-%Y-%m-%dT%H-%M-%SZ')
mkdir -p "$OUT"
exec > >(tee "$OUT/00-full-transcript.log") 2>&1

echo "=========================================="
echo "T0 — Codespace state at first operator command"
echo "=========================================="
date -u +'%FT%TZ'
echo "pwd: $(pwd)"
echo "id:  $(id)"
echo "HOME: $HOME"
uname -a
echo

echo "=========================================="
echo "Step 1 — Auto-plant pre-state (the load-bearing evidence)"
echo "=========================================="
echo "Question: Is ~/.copilot/mcp-config.json already present, written by"
echo "          an automated process before any operator command?"
echo
echo "--- ls -la ~/.copilot/ ---"
ls -la "$HOME/.copilot/" 2>&1 | tee "$OUT/01-prestate-ls.txt"
echo
echo "--- ~/.copilot/.poc-marker ---"
cat "$HOME/.copilot/.poc-marker" 2>&1 | tee "$OUT/01-prestate-marker.txt"
echo
echo "--- ~/.copilot/mcp-config.json ---"
cat "$HOME/.copilot/mcp-config.json" 2>&1 | tee "$OUT/01-prestate-config.txt"
echo
echo "--- file ownership / mode ---"
stat -c '%U:%G  %a  %n  (mtime: %y)' "$HOME/.copilot/mcp-config.json" 2>&1 | tee "$OUT/01-prestate-stat.txt"
echo
echo "--- Codespaces creation log tail (records what the lifecycle did) ---"
cat /workspaces/.codespaces/.persistedshare/creation.log 2>/dev/null | tail -60 | tee "$OUT/01-prestate-creation-log.txt"

if [ ! -f "$HOME/.copilot/mcp-config.json" ]; then
  echo
  echo "ERROR: ~/.copilot/mcp-config.json is NOT present. Codespaces did not"
  echo "auto-plant during environment setup. Cannot continue with the load test"
  echo "without contaminating the empirical claim. Investigate the creation log"
  echo "and Codespaces' Node-detect behavior."
  exit 1
fi

echo
echo "=========================================="
echo "Step 2 — Asymmetry control (per-repo configs)"
echo "=========================================="
echo "Plant three cwd-relative MCP configs with distinct marker names."
echo "These are operator-planted (transparent). The empirical question is"
echo "whether Copilot CLI loads them — the report's claim is that it does NOT."
echo
mkdir -p .copilot .github/copilot
printf '%s\n' '{ "mcpServers": { "repo-root-marker": { "command": "/bin/false", "args": [] } } }' > ./mcp-config.json
printf '%s\n' '{ "mcpServers": { "repo-copilot-marker": { "command": "/bin/false", "args": [] } } }' > ./.copilot/mcp-config.json
printf '%s\n' '{ "mcpServers": { "repo-github-copilot-marker": { "command": "/bin/false", "args": [] } } }' > ./.github/copilot/mcp-config.json

{
  echo "Configs at test time:"
  echo "  ~/.copilot/mcp-config.json (absolute, planted by lifecycle):"
  sed 's/^/    /' "$HOME/.copilot/mcp-config.json"
  echo "  ./mcp-config.json (cwd-relative, planted by this script):"
  sed 's/^/    /' ./mcp-config.json
  echo "  ./.copilot/mcp-config.json (cwd-relative, planted by this script):"
  sed 's/^/    /' ./.copilot/mcp-config.json
  echo "  ./.github/copilot/mcp-config.json (cwd-relative, planted by this script):"
  sed 's/^/    /' ./.github/copilot/mcp-config.json
} | tee "$OUT/02-configs-at-test-time.txt"

echo
echo "=========================================="
echo "Step 3 — Install copilot CLI binary if not present"
echo "=========================================="
echo "(Binary install is independent of MCP config; this is just to have"
echo "  the executable available so we can run it.)"
if command -v copilot >/dev/null 2>&1; then
  echo "copilot already in PATH: $(command -v copilot)"
else
  echo "Installing @github/copilot via npm..."
  npm install -g @github/copilot 2>&1 | tail -10
fi
copilot --version 2>&1 | tee "$OUT/03-copilot-version.txt"

echo
echo "=========================================="
echo "Step 4 — Run copilot once from workspace cwd"
echo "=========================================="
echo "cwd: $(pwd)"
{
  echo "--- begin copilot output ---"
  timeout 60 copilot --allow-all-tools -p "say ok" 2>&1 | head -60
  echo "--- end copilot output (exit: $?) ---"
} | tee "$OUT/04-copilot-run.txt"

echo
echo "=========================================="
echo "Step 5 — Process log inspection"
echo "=========================================="
LATEST=$(ls -t "$HOME"/.copilot/logs/process-*.log 2>/dev/null | head -1)
echo "latest log: ${LATEST:-NONE}"
if [ -n "${LATEST:-}" ]; then
  cp "$LATEST" "$OUT/05-process-log.log"
  echo
  echo "--- all MCP-related lines (verbatim) ---"
  grep -E "MCP client|MCP transport|McpError|Started MCP|Failed to start MCP|Starting remote MCP" "$LATEST" | tee "$OUT/05-mcp-lines.txt"
  echo
  echo "--- per-marker counts (only home-marker should be > 0) ---"
  for m in home-marker repo-root-marker repo-copilot-marker repo-github-copilot-marker; do
    n=$(grep -E "$m" "$LATEST" 2>/dev/null | wc -l)
    echo "  $m: $n"
  done | tee "$OUT/05-marker-counts.txt"
fi

echo
echo "=========================================="
echo "Step 6 — Verdict"
echo "=========================================="
HOME_HITS=$(grep -E "home-marker" "${LATEST:-/dev/null}" 2>/dev/null | wc -l)
REPO_HITS=$(grep -E "repo-(root|copilot|github-copilot)-marker" "${LATEST:-/dev/null}" 2>/dev/null | wc -l)
{
  if [ "$HOME_HITS" -gt 0 ] && [ "$REPO_HITS" -eq 0 ]; then
    echo "PASS — hypothesis confirmed:"
    echo "  home-absolute path loaded (home-marker: $HOME_HITS)"
    echo "  cwd-relative paths skipped (repo-* markers: $REPO_HITS total)"
  elif [ "$HOME_HITS" -eq 0 ]; then
    echo "FAIL — home-marker did not load. Investigate copilot version, auth state, or process log."
  else
    echo "PARTIAL — both home and at least one repo-marker fired. Investigate per-marker counts above."
  fi
} | tee "$OUT/06-verdict.txt"

echo
echo "Evidence captured to: $OUT/"
ls -la "$OUT/"
echo
echo "Full transcript: $OUT/00-full-transcript.log"
echo
echo "Cleanup commands (run when you're done):"
echo "  rm -f ~/.copilot/mcp-config.json ~/.copilot/.poc-marker"
echo "  rm -f ./mcp-config.json"
echo "  rm -rf ./.copilot ./.github/copilot"
