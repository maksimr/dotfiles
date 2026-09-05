// Run: node .pi/tests/auto-exit.test.mjs
import assert from 'node:assert/strict';
import autoExit from '../agent/extensions/auto-exit.ts';

const handlers = new Map();
let flag;
let shutdowns = 0;

autoExit({
  registerFlag(name, options) {
    assert.equal(name, 'auto-exit');
    assert.equal(options.type, 'boolean');
    assert.equal(options.default, false);
  },
  getFlag(name) {
    assert.equal(name, 'auto-exit');
    return flag;
  },
  on(event, handler) { handlers.set(event, handler); },
});

// No shutdown on startup, individual turns, or low-level run completion.
assert.deepEqual([...handlers.keys()], ['agent_settled']);
assert.equal(shutdowns, 0);
const ctx = { shutdown() { shutdowns++; } };
for (const value of [undefined, false, true]) {
  flag = value; // CLI values are resolved after the extension factory runs.
  await handlers.get('agent_settled')({ type: 'agent_settled' }, ctx);
  assert.equal(shutdowns, value === true ? 1 : 0);
}
console.log('auto-exit checks passed');
