export function applyOmpRecipe(operation, dryRun, { root, command }) {
  if (operation !== 'install' && operation !== 'reinstall') return true;
  if (dryRun) {
    console.log('Would synchronize pinned OMP plugins, ask whether to use the personal or professional OMP config, and link the selected config, extension, and French system prompt.');
    return true;
  }
  for (const script of ['sync_plugins.sh', 'link_config.sh', 'link_extension.sh']) {
    const result = command('bash', [`${root}/lib/programs/omp/scripts/${script}`]);
    if (result.error || result.status !== 0) return false;
  }
  return true;
}
