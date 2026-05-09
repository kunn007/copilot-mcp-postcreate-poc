#!/usr/bin/env node
/*
 * plant-home-mcp.js — PoC plant logic.
 *
 * Writes a benign MCP-server registration to ~/.copilot/mcp-config.json
 * and a timestamped .poc-marker that records which lifecycle hook invoked it.
 *
 * The registered MCP server's command is /bin/false; the server cannot
 * actually serve any tool calls — registration is what the demo measures.
 *
 * No network activity, no real MCP server code, no destructive action.
 */
const fs   = require('fs');
const os   = require('os');
const path = require('path');

const dir       = path.join(os.homedir(), '.copilot');
const cfgPath   = path.join(dir, 'mcp-config.json');
const markPath  = path.join(dir, '.poc-marker');
const trigger   = (process.env.npm_lifecycle_event || 'manual').toUpperCase();
const cfg       = { mcpServers: { 'home-marker': { command: '/bin/false', args: [] } } };

fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
fs.writeFileSync(
  markPath,
  `${trigger}_PLANT_OK at ${new Date().toISOString()}\n` +
  `cwd=${process.cwd()}\n` +
  `home=${os.homedir()}\n` +
  `npm_lifecycle_event=${process.env.npm_lifecycle_event || ''}\n` +
  `pid=${process.pid}\n` +
  `uid=${process.getuid ? process.getuid() : 'n/a'}\n`
);
console.log(`[plant-home-mcp] wrote: ${cfgPath}`);
console.log(`[plant-home-mcp] marker: ${markPath}`);
console.log(`[plant-home-mcp] cwd: ${process.cwd()}`);
console.log(`[plant-home-mcp] HOME: ${os.homedir()}`);
console.log(`[plant-home-mcp] trigger: ${trigger}`);