import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const proj = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const need = [
  'AGENTS.md',
  'Package.swift',
  'Sources/AppleIDGuard/Engine/RiskEngine.swift',
  'Sources/AppleIDGuard/AppleIDGuardApp.swift',
  'Sources/ShareExtension/ShareViewController.swift',
  'AppleIDGuard.entitlements',
  'AppleIDGuardShare.entitlements',
];

test('project smoke: critical files exist', () => {
  for (const rel of need) {
    assert.ok(fs.existsSync(path.join(proj, rel)), `missing ${rel}`);
  }
});

test('project has identity', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(proj, 'package.json'), 'utf8'));
  assert.equal(pkg.name, 'apple-id-guard');
});
