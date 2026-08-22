'use strict';

// story: e81s02
const fs = require('fs');
const path = require('path');

const DEFAULT_SPECS_DIR = 'specs';
const CONFIG_RELATIVE_PATH = path.join('.bigpowers', 'config.yaml');

function readTopLevelScalar(projectRoot, key) {
  const configPath = path.join(projectRoot, CONFIG_RELATIVE_PATH);
  if (!fs.existsSync(configPath)) return undefined;

  const lines = fs.readFileSync(configPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    if (/^\s*#/.test(line)) continue;
    const separator = line.indexOf(':');
    if (separator < 0) continue;
    if (line.slice(0, separator).trim() !== key) continue;

    const rawValue = line.slice(separator + 1).replace(/\s+#.*$/, '').trim();
    const quoted = rawValue.match(/^(['"])(.*)\1$/);
    return quoted ? quoted[2] : rawValue;
  }
  return undefined;
}

function specsDir(projectRoot, env = process.env) {
  const configured = Object.prototype.hasOwnProperty.call(env, 'BIGPOWERS_SPECS_DIR')
    ? env.BIGPOWERS_SPECS_DIR
    : readTopLevelScalar(projectRoot, 'specs_dir');
  const resolved = configured === undefined ? DEFAULT_SPECS_DIR : configured;
  if (!resolved) {
    throw new Error(
      'bigpowers config: specs_dir must not be empty; set it to specs, .specs, or another directory'
    );
  }
  return resolved;
}

function specsPath(projectRoot, ...segments) {
  const configuredDir = specsDir(projectRoot);
  const root = path.isAbsolute(configuredDir)
    ? configuredDir
    : path.join(projectRoot, configuredDir);
  return path.join(root, ...segments);
}

module.exports = { readTopLevelScalar, specsDir, specsPath };
