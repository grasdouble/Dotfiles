import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { applyNeovimRecipe, bundledFormula as neovimBundledFormula } from './neovim/recipe.mjs';
import { applyOmpRecipe } from './omp/recipe.mjs';
import { applyColimaRecipe, bundledFormulae as colimaBundledFormulae } from './colima/recipe.mjs';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const recipeLabels = JSON.parse(fs.readFileSync(path.join(root, 'config/programs/recipes.json'), 'utf8'));

function loadManifest() {
  const index = JSON.parse(fs.readFileSync(path.join(root, 'config/programs.json'), 'utf8'));
  if (index.version !== 1 || !Array.isArray(index.categories)) throw new Error('Invalid programs catalog index');
  const catalogDirectory = path.join(root, 'config/programs/catalog');
  const seenCategories = new Set();
  const programs = index.categories.flatMap(({ file, name }) => {
    if (typeof name !== 'string' || seenCategories.has(name) || !/^[a-z0-9]+(?:-[a-z0-9]+)*\.json$/.test(file)) {
      throw new Error(`Invalid catalog category entry: ${file}`);
    }
    seenCategories.add(name);
    const catalog = JSON.parse(fs.readFileSync(path.join(catalogDirectory, file), 'utf8'));
    if (!catalog || Array.isArray(catalog) || !Array.isArray(catalog.cask) || !Array.isArray(catalog.formula)) {
      throw new Error(`Invalid category catalog: ${file}`);
    }
    for (const kind of ['cask', 'formula']) {
      if (catalog[kind].some((entry) => !entry || typeof entry !== 'object' || Array.isArray(entry))) {
        throw new Error(`Invalid ${kind} entries in category catalog: ${file}`);
      }
    }
    return [
      ...catalog.cask.map((entry) => ({ ...entry, category: name, kind: 'cask' })),
      ...catalog.formula.map((entry) => ({ ...entry, category: name, kind: 'formula' })),
    ];
  });
  const profiles = JSON.parse(fs.readFileSync(path.join(root, 'config/programs/profiles.json'), 'utf8'));
  return { version: index.version, programs, profiles };
}
const sourceManifest = loadManifest();
const idPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function validateManifest(data) {
  if (data.version !== 1 || !Array.isArray(data.programs) || !data.profiles || typeof data.profiles !== 'object') {
    throw new Error('Invalid programs catalog structure');
  }
  const ids = new Set();
  for (const program of data.programs) {
    if (!idPattern.test(program.id) || ids.has(program.id)) throw new Error(`Invalid or duplicate program id: ${program.id}`);
    if (typeof program.active !== 'boolean') throw new Error(`Program active must be boolean: ${program.id}`);
    if (!program.name || !program.category || !['cask', 'formula'].includes(program.kind) || !program.package) {
      throw new Error(`Incomplete catalog entry: ${program.id}`);
    }
    if (program.appdir && !path.isAbsolute(program.appdir)) throw new Error(`appdir must be absolute: ${program.id}`);
    ids.add(program.id);
  }
  for (const [name, idsInProfile] of Object.entries(data.profiles)) {
    if (!Array.isArray(idsInProfile) || idsInProfile.some((id) => !ids.has(id))) throw new Error(`Invalid profile: ${name}`);
  }

  if (!recipeLabels || Array.isArray(recipeLabels) || typeof recipeLabels !== 'object') {
    throw new Error('Invalid recipe labels catalog');
  }
  const usedRecipes = new Set();
  for (const program of data.programs) {
    if (!program.recipe) continue;
    if (typeof recipeLabels[program.recipe] !== 'string') throw new Error(`Missing label for recipe: ${program.recipe}`);
    usedRecipes.add(program.recipe);
  }
  for (const recipe of Object.keys(recipeLabels)) {
    if (!usedRecipes.has(recipe)) throw new Error(`Unused recipe label: ${recipe}`);
  }
}
validateManifest(sourceManifest);

export function buildActiveManifest(data) {
  const programs = data.programs.filter(({ active }) => active);
  const activeIds = new Set(programs.map(({ id }) => id));
  const profiles = Object.fromEntries(Object.entries(data.profiles).map(([name, ids]) => [
    name,
    ids.filter((id) => activeIds.has(id)),
  ]));
  return { ...data, programs, profiles };
}

export const manifest = buildActiveManifest(sourceManifest);
const allPrograms = sourceManifest.programs;
const programById = new Map(allPrograms.map((entry) => [entry.id, entry]));
export function command(commandName, args, { capture = false } = {}) {
  return spawnSync(commandName, args, {
    cwd: root,
    encoding: 'utf8',
    stdio: capture ? ['ignore', 'pipe', 'ignore'] : 'inherit',
  });
}

function installedPackages(kind) {
  const result = command('brew', ['list', kind === 'cask' ? '--cask' : '--formula', '--versions'], { capture: true });
  if (result.error || result.status !== 0) return null;
  const packages = new Map();
  const entries = [];
  for (const line of (result.stdout || '').split(/\r?\n/).map((value) => value.trim()).filter(Boolean)) {
    const separator = line.search(/\s/);
    const name = separator === -1 ? line : line.slice(0, separator);
    const version = separator === -1 ? null : line.slice(separator).trim() || null;
    packages.set(name, version);
    packages.set(name.split('/').at(-1), version);
    entries.push({ kind, package: name, version });
  }
  return { packages, entries };
}

function readCaskInfo(casks, programs) {
  const needsCaskInfo = casks && programs.some((program) => {
    if (program.kind !== 'cask' || !program.appdir) return false;
    const shortName = program.package.split('/').at(-1);
    return casks.has(program.package) || casks.has(shortName);
  });
  const result = needsCaskInfo ? command('brew', ['info', '--json=v2', '--installed'], { capture: true }) : null;
  if (!result || result.error || result.status !== 0) return new Map();
  try {
    const data = JSON.parse(result.stdout || '{}');
    return new Map((data.casks || []).map((cask) => [cask.token, cask]));
  } catch {
    return new Map();
  }
}

function inventoryFromPackages(programs, formulae, casks, { includeAppTargets = false } = {}) {
  const caskInfo = readCaskInfo(casks, programs);
  return programs.map((program) => {
    const inventory = program.kind === 'cask' ? casks : formulae;
    const shortName = program.package.split('/').at(-1);
    const packageName = inventory?.has(program.package) ? program.package : shortName;
    const installed = inventory === null ? null : inventory.has(packageName);
    const artifacts = program.kind === 'cask' && installed && program.appdir
      ? caskInfo.get(shortName)?.artifacts || []
      : [];
    const appTargets = artifacts
      .filter((artifact) => Array.isArray(artifact.app)
        && typeof artifact.target === 'string'
        && path.isAbsolute(artifact.target)
        && path.extname(artifact.target).toLowerCase() === '.app'
        && artifact.app.includes(path.basename(artifact.target)))
      .map((artifact) => path.resolve(artifact.target));
    const outdatedAppTargets = appTargets.filter((target) =>
      path.resolve(path.dirname(target)) !== path.resolve(program.appdir));
    return {
      ...program,
      installed,
      version: installed ? inventory.get(packageName) : null,
      appdirOutdated: outdatedAppTargets.length > 0,
      ...(includeAppTargets ? { outdatedAppTargets } : {}),
    };
  });
}

export function getInventory({ includeInactive = false, includeAppTargets = false } = {}) {
  const programs = includeInactive ? allPrograms : manifest.programs;
  const formulae = installedPackages('formula');
  const casks = installedPackages('cask');
  return inventoryFromPackages(programs, formulae?.packages ?? null, casks?.packages ?? null, { includeAppTargets });
}

export function getDrift() {
  const formulae = installedPackages('formula');
  const casks = installedPackages('cask');
  const leavesResult = command('brew', ['leaves'], { capture: true });
  if (leavesResult.error || leavesResult.status !== 0) throw new Error('Cannot determine explicitly installed Homebrew formulae.');
  const leaves = new Set((leavesResult.stdout || '').split(/\r?\n/).map((name) => name.trim()).filter(Boolean));


  const inventory = inventoryFromPackages(manifest.programs, formulae.packages, casks.packages);
  const knownPackages = new Set([
    'git',
    'zsh',
    'asdf',
    neovimBundledFormula,
    ...colimaBundledFormulae,
    ...allPrograms.flatMap((program) => [
      program.package,
      program.package.split('/').at(-1),
    ]),
  ]);
  const unmanagedFormulae = formulae.entries.filter(({ package: name }) =>
    (leaves.has(name) || leaves.has(name.split('/').at(-1)))
      && !knownPackages.has(name) && !knownPackages.has(name.split('/').at(-1)));
  const unmanagedCasks = casks.entries.filter(({ package: name }) =>
    !knownPackages.has(name) && !knownPackages.has(name.split('/').at(-1)));
  const unmanaged = [...unmanagedFormulae, ...unmanagedCasks];
  return {
    missing: inventory.filter(({ installed }) => installed === false)
      .map(({ id, name, kind, package: packageName }) => ({ id, name, kind, package: packageName })),
    unmanaged,
    appdirOutdated: inventory.filter(({ appdirOutdated }) => appdirOutdated)
      .map(({ id, name, appdir, kind, package: packageName }) => ({ id, name, kind, package: packageName, appdir })),
  };
}


export function resolvePrograms(ids, { includeInactive = false } = {}) {
  const result = [];
  const seen = new Set();
  for (const id of ids) {
    const program = programById.get(id);
    if (!program) throw new Error(`Unknown program '${id}'. Run 'dotfiles list' to see available IDs.`);
    if (!program.active && !includeInactive) {
      throw new Error(`Program '${id}' is inactive. Set active to true to install it.`);
    }
    if (!seen.has(id)) result.push(program);
    seen.add(id);
  }
  if (!result.length) throw new Error('Select at least one program.');
  return result;
}

function brewArgs(program, operation) {
  const kindFlag = program.kind === 'cask' ? '--cask' : '--formula';
  if (operation === 'install' || operation === 'reinstall') {
    const args = [operation === 'reinstall' ? 'reinstall' : 'install', kindFlag];
    if (program.noQuarantine && operation === 'install') args.push('--no-quarantine');
    if (program.appdir) args.push(`--appdir=${program.appdir}`);
    args.push(program.package);
    return args;
  }
  return ['uninstall', kindFlag, program.package];
}

function applyRecipe(program, operation, dryRun) {
  if (program.recipe === 'neovim-stack') {
    return applyNeovimRecipe(operation, dryRun, { root, command });
  }
  if (program.recipe === 'omp-config') {
    return applyOmpRecipe(operation, dryRun, { root, command });
  }
  if (program.recipe === 'colima-stack') {
    return applyColimaRecipe(operation, dryRun, { command });
  }
  return true;
}

export function perform(operation, programs, { dryRun = false } = {}) {
  const includeAppTargets = operation === 'install' || operation === 'reinstall';
  const inventory = new Map(getInventory({
    includeInactive: operation === 'remove',
    includeAppTargets,
  }).map((entry) => [entry.id, entry]));
  let failures = 0;
  for (const program of programs) {
    const installedProgram = inventory.get(program.id);
    const installed = installedProgram?.installed;
    const relocate = ['install', 'reinstall'].includes(operation) && installed && installedProgram.appdirOutdated;
    if (installed === null || installed === undefined) {
      console.error(`Cannot determine whether ${program.name} is installed. Is Homebrew available?`);
      failures += 1;
      continue;
    }
    if (operation === 'install' && installed && !relocate) {
      console.log(`Already installed: ${program.name}`);
      if (program.recipe && !applyRecipe(program, operation, dryRun)) {
        console.error(`The install recipe failed for ${program.name}.`);
        failures += 1;
      }
      continue;
    }
    if (operation === 'reinstall' && !installed) {
      console.error(`Cannot reinstall ${program.name}: it is not installed. Use 'install' instead.`);
      failures += 1;
      continue;
    }
    if (operation === 'remove' && !installed) {
      console.log(`Not installed: ${program.name}`);
      if (program.recipe && !applyRecipe(program, operation, dryRun)) {
        console.error(`The remove recipe failed for ${program.name}.`);
        failures += 1;
      }
      continue;
    }
    const action = relocate ? 'reinstall' : operation;
    const args = brewArgs(program, action);
    if (dryRun) {
      console.log(`Would run: brew ${args.map((arg) => JSON.stringify(arg)).join(' ')}`);
      if (relocate) {
        for (const target of installedProgram.outdatedAppTargets || []) {
          console.log(`Would remove old app bundle after successful reinstall: ${target}`);
        }
      }
    } else {
      const actionLabel = action === 'install' ? 'Installing'
        : action === 'reinstall' ? 'Reinstalling' : 'Removing';
      console.log(`${actionLabel} ${program.name}…`);
      const result = command('brew', args);
      if (result.error || result.status !== 0) {
        console.error(`Failed to ${action} ${program.name}.`);
        failures += 1;
        continue;
      }
    }
    if (!applyRecipe(program, action, dryRun)) {
      console.error(`The ${action} recipe failed for ${program.name}.`);
      failures += 1;
      continue;
    }
    if (!dryRun && relocate) {
      for (const target of installedProgram.outdatedAppTargets || []) {
        try {
          const targetStat = fs.lstatSync(target, { throwIfNoEntry: false });
          if (!targetStat) continue;
          fs.rmSync(target, { recursive: true });
          console.log(`Removed old app bundle: ${target}`);
        } catch (error) {
          console.error(`Could not remove old app bundle ${target}: ${error.message}`);
          failures += 1;
        }
      }
    }
  }
  return failures === 0 ? 0 : 1;
}

export function listPrograms({ category, json = false } = {}) {
  const entries = getInventory().filter((program) => !category || program.category.toLowerCase() === category.toLowerCase());
  if (json) {
    console.log(JSON.stringify(entries, null, 2));
    return 0;
  }
  for (const categoryName of [...new Set(entries.map(({ category: name }) => name))]) {
    console.log(`\n${categoryName}`);
    for (const program of entries.filter((item) => item.category === categoryName)) {
      const status = program.installed === null ? 'unknown' : program.installed ? 'installed' : 'not installed';
      const version = program.installed && program.version ? ` · ${program.version}` : '';
      const appdir = program.appdirOutdated ? ' · appdir changed; reinstall needed' : '';
      console.log(`  ${program.id.padEnd(24)} ${program.name} (${status}${version}${appdir})`);
    }
  }
  return 0;
}

export const categories = ['All', ...new Set(manifest.programs.map(({ category }) => category))];
export function categoryProgramIds(name) {
  const matches = manifest.programs.filter((program) => program.category.toLowerCase() === name.toLowerCase());
  if (!matches.length) throw new Error(`Unknown category '${name}'. Available: ${categories.slice(1).join(', ')}`);
  return matches.map(({ id }) => id);
}
