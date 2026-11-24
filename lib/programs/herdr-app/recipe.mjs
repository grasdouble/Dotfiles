import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export function applyHerdrAppRecipe(operation, dryRun, { root }) {
  if (operation !== 'install' && operation !== 'reinstall') return true;

  const appHome = process.env.HERDR_APP_HOME || path.join(os.homedir(), '.config/herdr-app');
  const links = ['layouts/dotfiles-orca.json', 'mods/dotfiles-projects'];
  const missing = [];
  try {
    for (const name of links) {
      const source = path.join(root, 'config/herdr-app', name);
      const target = path.resolve(appHome, name);
      const targetDir = path.dirname(target);
      const existing = fs.lstatSync(target, { throwIfNoEntry: false });
      if (!existing) {
        missing.push({ source, target, targetDir });
      } else if (!existing.isSymbolicLink() || path.resolve(targetDir, fs.readlinkSync(target)) !== source) {
        console.error(`Herdr App configuration already exists at ${target}; move it aside and rerun install herdr-app. It was left untouched.`);
        return false;
      }
    }
    for (const { source, target, targetDir } of missing) {
      if (dryRun) {
        console.log(`Would create Herdr App link: ${target} -> ${source}`);
      } else {
        fs.mkdirSync(targetDir, { recursive: true });
        fs.symlinkSync(source, target);
        console.log(`Created Herdr App link: ${target} -> ${source}`);
      }
    }
    return true;
  } catch (error) {
    console.error(`Could not link Herdr App configuration: ${error.message}`);
    return false;
  }
}
