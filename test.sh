#!/bin/bash
# Test the model parsing logic

set -euo pipefail

echo "=== Testing Model.js ==="

# Test with a sample status line
node -e "
const fs = require('fs');
const code = fs.readFileSync('$(dirname "$0")/Model.js', 'utf8');
eval(code);

// Test default status
let s = defaultStatus();
console.assert(s.ok === false, 'default not ok');
console.assert(s.connected === false, 'default not connected');
console.assert(s.left.level === LEVEL_UNKNOWN, 'default left level unknown');
console.log('PASS: defaultStatus');

// Test parse with valid JSON
let raw = JSON.stringify({
  schema_version: 1,
  connected: true,
  device_name: 'Test Ear',
  model_name: 'Nothing Ear (a)',
  firmware_version: '1.0.0',
  serial_number: 'SH12345',
  anc_mode: 5,
  eq_preset: 1,
  in_ear_detection: true,
  low_latency_mode: false,
  left: { available: true, level: 85, charging: false, in_ear: true },
  right: { available: true, level: 90, charging: true, in_ear: false },
  case: { available: true, level: 70, charging: false, in_ear: false }
});
s = parseStatus(raw);
console.assert(s.ok === true, 'parsed ok');
console.assert(s.connected === true, 'parsed connected');
console.assert(s.deviceName === 'Test Ear', 'parsed deviceName');
console.assert(s.left.level === 85, 'parsed left level');
console.assert(s.right.charging === true, 'parsed right charging');
console.assert(s.caseBattery.level === 70, 'parsed case level');
console.assert(s.ancMode === 5, 'parsed anc mode');
console.assert(s.eqPreset === 1, 'parsed eq preset');
console.log('PASS: parseStatus valid JSON');

// Test empty string
s = parseStatus('');
console.assert(s.ok === false, 'empty not ok');
console.assert(s.lastError !== '', 'empty has error');
console.log('PASS: parseStatus empty');

// Test invalid JSON
s = parseStatus('not json');
console.assert(s.ok === false, 'invalid not ok');
console.log('PASS: parseStatus invalid');

// Test mode names
console.assert(ancModeName(0) === 'Off', 'anc off');
console.assert(ancModeName(5) === 'Transparency', 'anc transparency');
console.assert(eqPresetName(0) === 'Balanced', 'eq balanced');
console.assert(eqPresetName(3) === 'Voice', 'eq voice');
console.log('PASS: names');

// Test level helpers
console.assert(levelText(LEVEL_UNKNOWN) === '--', 'level unknown');
console.assert(levelText(50) === '50%', 'level 50');
console.assert(levelFraction(0) === 0, 'fraction 0');
console.assert(levelFraction(100) === 1, 'fraction 100');
console.log('PASS: level helpers');

console.log('All tests passed!');
"
