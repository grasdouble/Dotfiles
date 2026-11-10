#!/usr/bin/env node
import path from 'node:path';
import React from 'react';
import { render } from 'ink';
import Dashboard from './ui/dashboard.mjs';
import {
  categoryProgramIds,
  command,
  getDrift,
  listPrograms,
  manifest,
  perform,
  resolvePrograms,
  root,
} from '../lib/programs/manager.mjs';

function parseListOptions(args) {
  let category;
  let json = false;
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === '--json') json = true;
    else if (args[index] === '--category') {
      const categoryName = args[index + 1];
      if (!categoryName || categoryName.startsWith('-')) throw new Error('--category requires a category name.');
      category = args[++index];
    } else throw new Error(`Unknown list option: ${args[index]}`);
  }
  return { category, json };
}

function parseActionOptions(args) {
  const ids = [];
  let dryRun = false;
  let yes = false;
  let category;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--dry-run') dryRun = true;
    else if (arg === '--yes' || arg === '-y') yes = true;
    else if (arg === '--category') {
      if (!args[index + 1] || args[index + 1].startsWith('-')) throw new Error('--category requires a category name.');
      category = args[++index];
    } else if (arg.startsWith('-')) throw new Error(`Unknown option: ${arg}`);
    else ids.push(arg);
  }
  return { ids, dryRun, yes, category };
}

function printDrift({ missing, unmanaged, appdirOutdated }, json) {
  if (json) {
    console.log(JSON.stringify({ missing, unmanaged, appdirOutdated }, null, 2));
    return;
  }
  const total = missing.length + unmanaged.length + appdirOutdated.length;
  if (!total) {
    console.log('No drift detected.');
    return;
  }
  console.log(`Missing catalog programs (${missing.length})`);
  for (const program of missing) console.log(`  ${program.id} · ${program.name}`);
  console.log(`Unmanaged Homebrew packages (${unmanaged.length})`);
  for (const pkg of unmanaged) console.log(`  ${pkg.kind} ${pkg.package}${pkg.version ? ` · ${pkg.version}` : ''}`);
  console.log(`Changed app destinations (${appdirOutdated.length})`);
  for (const program of appdirOutdated) console.log(`  ${program.id} · expected ${program.appdir}`);
}

function printHelp() {
  console.log(`Dotfiles program manager\n\nUsage:\n  dotfiles [interactive]\n  dotfiles list [--category NAME] [--json]\n  dotfiles drift [--json]\n  dotfiles install <id... | --profile NAME | --category NAME> [--dry-run]\n  dotfiles reinstall <installed-id...> [--dry-run]\n  dotfiles remove <id...> [--dry-run] [--yes]\n  dotfiles profiles\n  dotfiles update [--dry-run]\n  dotfiles doctor\n  dotfiles core\n\nProfiles: ${Object.keys(manifest.profiles).join(', ')}\nInstall/reinstall/remove IDs are shown by 'dotfiles list'.`);
}

async function main(args) {
  const [commandName = 'interactive', ...argsRest] = args;
  if (['help', '--help', '-h'].includes(commandName)) { printHelp(); return 0; }
  if (commandName === 'list') return listPrograms(parseListOptions(argsRest));
  if (commandName === 'drift') {
    const unknownOptions = argsRest.filter((arg) => arg !== '--json');
    if (unknownOptions.length) throw new Error(`Unknown drift option: ${unknownOptions[0]}`);
    printDrift(getDrift(), argsRest.includes('--json'));
    return 0;
  }
  if (commandName === 'profiles') {
    for (const [name, ids] of Object.entries(manifest.profiles)) console.log(`${name}: ${ids.join(', ')}`);
    return 0;
  }
  if (['install', 'reinstall', 'remove'].includes(commandName)) {
    let actionArgs = argsRest;
    let profile;
    const profileAt = actionArgs.indexOf('--profile');
    if (profileAt >= 0) {
      profile = actionArgs[profileAt + 1];
      if (!profile) throw new Error('--profile requires a name.');
      actionArgs = actionArgs.filter((_, index) => index !== profileAt && index !== profileAt + 1);
    }
    const { ids, dryRun, yes, category } = parseActionOptions(actionArgs);
    if (profile && commandName !== 'install') throw new Error('Profiles can only be used with install.');
    if (category && commandName !== 'install') throw new Error('Categories can only be used with install.');
    if (profile && !manifest.profiles[profile]) throw new Error(`Unknown profile '${profile}'. Available: ${Object.keys(manifest.profiles).join(', ')}`);
    const profileIds = profile ? manifest.profiles[profile] : [];
    const categoryIds = category ? categoryProgramIds(category) : [];
    const programs = resolvePrograms([...ids, ...profileIds, ...categoryIds], { includeInactive: commandName === 'remove' });
    if (commandName === 'remove' && !dryRun && !yes && process.stdin.isTTY) {
      throw new Error('Removing Homebrew packages can affect other software. Re-run with --yes to confirm.');
    }
    if (commandName === 'remove' && !process.stdin.isTTY && !yes && !dryRun) throw new Error('Use --yes to confirm removal in non-interactive mode.');
    return perform(commandName, programs, { dryRun });
  }
  if (commandName === 'update' || commandName === 'doctor' || commandName === 'core') {
    const argsForMain = commandName === 'update' ? ['--update', ...argsRest]
      : commandName === 'doctor' ? ['--doctor', ...argsRest]
        : ['--profile=core', ...argsRest];
    const result = command('bash', [path.join(root, 'main.sh'), ...argsForMain]);
    return result.status ?? 1;
  }
  if (commandName === 'interactive') {
    if (!process.stdin.isTTY || !process.stdout.isTTY) throw new Error('Interactive mode requires a terminal; use dotfiles list/install instead.');
    const app = render(React.createElement(Dashboard, { onExit: () => app.unmount() }));
    await app.waitUntilExit();
    return 0;
  }
  throw new Error(`Unknown command '${commandName}'. Run 'dotfiles help'.`);
}

try {
  process.exitCode = await main(process.argv.slice(2));
} catch (error) {
  console.error(`Error: ${error.message}`);
  process.exitCode = 2;
}
