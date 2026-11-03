export function applyOmpRecipe(operation, dryRun, { root, command }) {
  if (operation !== 'install') return true;
  if (dryRun) {
    console.log('Would synchronize the pinned OMP plugins and link the repository OMP config and extension.');
    return true;
  }
  for (const script of ['sync_plugins.sh', 'link_config.sh', 'link_extension.sh']) {
    const result = command('bash', [`${root}/lib/programs/omp/scripts/${script}`]);
    if (result.error || result.status !== 0) return false;
  }
  return true;
}
