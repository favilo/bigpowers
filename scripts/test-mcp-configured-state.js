#!/usr/bin/env node
// story: e81s02
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const repoRoot = path.resolve(__dirname, '..');
const serverPath = path.join(repoRoot, 'scripts', 'mcp-server.js');
const projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'bigpowers-mcp-'));
const marker = 'configured-mcp-state';

fs.mkdirSync(path.join(projectRoot, '.bigpowers'), { recursive: true });
fs.mkdirSync(path.join(projectRoot, '.specs'), { recursive: true });
fs.writeFileSync(
  path.join(projectRoot, '.bigpowers', 'config.yaml'),
  'specs_dir: .specs\nvcs: auto\n',
  'utf8'
);
fs.writeFileSync(
  path.join(projectRoot, '.specs', 'state.yaml'),
  `active_flow: ${marker}\n`,
  'utf8'
);

const child = spawn(process.execPath, [serverPath], {
  cwd: projectRoot,
  stdio: ['pipe', 'pipe', 'pipe']
});

const request = JSON.stringify({
  jsonrpc: '2.0',
  id: 1,
  method: 'tools/call',
  params: { name: 'bigpowers_get_state', arguments: {} }
});
child.stdin.write(`Content-Length: ${Buffer.byteLength(request)}\r\n\r\n${request}`);

let stdout = Buffer.alloc(0);
const timeout = setTimeout(() => finish(new Error('MCP state lookup timed out')), 3000);

child.stdout.on('data', chunk => {
  stdout = Buffer.concat([stdout, chunk]);
  const headerEnd = stdout.indexOf('\r\n\r\n');
  if (headerEnd < 0) return;
  const header = stdout.slice(0, headerEnd).toString();
  const match = header.match(/Content-Length:\s*(\d+)/i);
  if (!match) return;
  const bodyStart = headerEnd + 4;
  const bodyLength = Number(match[1]);
  if (stdout.length < bodyStart + bodyLength) return;

  try {
    const response = JSON.parse(stdout.slice(bodyStart, bodyStart + bodyLength).toString());
    const text = response.result.content[0].text;
    assert.ok(text.includes(marker), `expected configured state marker, got ${text}`);
    finish();
  } catch (error) {
    finish(error);
  }
});

child.on('error', finish);

let finished = false;
function finish(error) {
  if (finished) return;
  finished = true;
  clearTimeout(timeout);
  child.kill();
  fs.rmSync(projectRoot, { recursive: true, force: true });
  if (error) {
    console.error(`FAIL MCP configured state: ${error.message}`);
    process.exitCode = 1;
  } else {
    console.log('PASS MCP reads state from configured artifact root');
  }
}
