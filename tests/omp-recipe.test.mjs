import assert from 'node:assert/strict';
import test from 'node:test';
import { applyOmpRecipe } from '../lib/programs/omp/recipe.mjs';

test('reinstall reruns all OMP configuration steps', () => {
  const calls = [];
  const result = applyOmpRecipe('reinstall', false, {
    root: '/dotfiles',
    command: (executable, args) => {
      calls.push([executable, ...args]);
      return { status: 0 };
    },
  });

  assert.equal(result, true);
  assert.deepEqual(calls, [
    ['bash', '/dotfiles/lib/programs/omp/scripts/sync_plugins.sh'],
    ['bash', '/dotfiles/lib/programs/omp/scripts/link_config.sh'],
    ['bash', '/dotfiles/lib/programs/omp/scripts/link_extension.sh'],
  ]);
});
