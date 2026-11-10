import fs from 'node:fs';
import path from 'node:path';

export const bundledFormula = 'tree-sitter-cli';

function isBundledFormulaInstalled(command) {
  const result = command('brew', ['list', '--formula', '--versions'], { capture: true });
  if (result.error || result.status !== 0) return null;
  return (result.stdout || '').split(/\r?\n/).some((line) => {
    const name = line.trim().split(/\s+/, 1)[0];
    return name?.split('/').at(-1) === bundledFormula;
  });
}

export function applyNeovimRecipe(operation, dryRun, { root, command }) {
  if (operation === 'remove') {
    if (dryRun) {
      console.log(`Would run: brew uninstall --formula ${bundledFormula}`);
      return true;
    }
    const installed = isBundledFormulaInstalled(command);
    if (installed === null || !installed) return installed !== null;
    const result = command('brew', ['uninstall', '--formula', bundledFormula]);
    return !result.error && result.status === 0;
  }
  if (!['install', 'reinstall'].includes(operation)) return true;

  const configDir = path.join(process.env.HOME || '', '.config/nvim');
  const target = path.join(configDir, 'init.lua');
  const link = path.join(root, 'config/nvim/init.lua');
  const legacy = path.join(configDir, 'init.vim');
  const legacyLink = path.join(root, 'config/nvim/init.vim');
  if (dryRun) {
    console.log(`Would run: brew install --formula ${bundledFormula}`);
    console.log(`Would link ${link} to ${target} if no user config exists; migrate the legacy link if present.`);
    return true;
  }
  const result = command('brew', ['install', '--formula', bundledFormula]);
  if (result.error || result.status !== 0) return false;
  fs.mkdirSync(configDir, { recursive: true });
  const targetStat = fs.lstatSync(target, { throwIfNoEntry: false });
  if (targetStat) {
    if (targetStat.isSymbolicLink() && fs.readlinkSync(target) === link) return true;
    console.log(`Keeping existing Neovim configuration: ${target}`);
    return true;
  }
  const legacyStat = fs.lstatSync(legacy, { throwIfNoEntry: false });
  if (legacyStat?.isSymbolicLink() && fs.readlinkSync(legacy) === legacyLink) {
    fs.symlinkSync(link, target);
    fs.rmSync(legacy);
    console.log(`Migrated the Neovim config link to ${target}.`);
  } else if (legacyStat) {
    console.log(`Keeping existing legacy Neovim configuration: ${legacy}`);
  } else {
    fs.symlinkSync(link, target);
  }
  return true;
}
