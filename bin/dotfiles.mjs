#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import React, { useEffect, useMemo, useState } from 'react';
import { Box, Text, render, useInput, useStdout } from 'ink';
import { resolveReinstallSelection } from '../lib/reinstall-selection.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const manifestPath = path.join(root, 'config/programs.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const idPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function validateManifest(data) {
  if (data.version !== 1 || !Array.isArray(data.programs) || !data.profiles || typeof data.profiles !== 'object') {
    throw new Error('Invalid programs catalog structure');
  }
  const ids = new Set();
  for (const program of data.programs) {
    if (!idPattern.test(program.id) || ids.has(program.id)) throw new Error(`Invalid or duplicate program id: ${program.id}`);
    if (!program.name || !program.category || !['cask', 'formula'].includes(program.kind) || !program.package) {
      throw new Error(`Incomplete catalog entry: ${program.id}`);
    }
    if (program.appdir && !path.isAbsolute(program.appdir)) throw new Error(`appdir must be absolute: ${program.id}`);
    ids.add(program.id);
  }
  for (const [name, idsInProfile] of Object.entries(data.profiles)) {
    if (!Array.isArray(idsInProfile) || idsInProfile.some((id) => !ids.has(id))) throw new Error(`Invalid profile: ${name}`);
  }
}
validateManifest(manifest);
const programById = new Map(manifest.programs.map((entry) => [entry.id, entry]));

function command(commandName, args, { capture = false } = {}) {
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
  for (const line of (result.stdout || '').split(/\r?\n/).map((value) => value.trim()).filter(Boolean)) {
    const separator = line.search(/\s/);
    const name = separator === -1 ? line : line.slice(0, separator);
    const version = separator === -1 ? null : line.slice(separator).trim() || null;
    packages.set(name, version);
    packages.set(name.split('/').at(-1), version);
  }
  return packages;
}

function getInventory() {
  const formulae = installedPackages('formula');
  const casks = installedPackages('cask');
  return manifest.programs.map((program) => {
    const inventory = program.kind === 'cask' ? casks : formulae;
    const shortName = program.package.split('/').at(-1);
    const packageName = inventory?.has(program.package) ? program.package : shortName;
    const installed = inventory === null ? null : inventory.has(packageName);
    return {
      ...program,
      installed,
      version: installed ? inventory.get(packageName) : null,
    };
  });
}

function resolvePrograms(ids) {
  const result = [];
  const seen = new Set();
  for (const id of ids) {
    const program = programById.get(id);
    if (!program) throw new Error(`Unknown program '${id}'. Run 'dotfiles list' to see available IDs.`);
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
  if (program.recipe === 'neovim-config' && ['install', 'reinstall'].includes(operation)) {
    const configDir = path.join(process.env.HOME || '', '.config/nvim');
    const target = path.join(configDir, 'init.lua');
    const link = path.join(root, 'config/nvim/init.lua');
    const legacy = path.join(configDir, 'init.vim');
    const legacyLink = path.join(root, 'config/nvim/init.vim');
    if (dryRun) {
      console.log(`Would link ${link} to ${target} if no user config exists; migrate the legacy link if present.`);
      return true;
    }
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
  }
  if (program.recipe === 'omp-config' && operation === 'install') {
    if (dryRun) {
      console.log('Would synchronize the pinned OMP plugins and link the repository OMP config and extension.');
      return true;
    }
    for (const script of ['sync_omp_plugins.sh', 'link_omp_config.sh', 'link_omp_extension.sh']) {
      const result = command('bash', [path.join(root, 'scripts', script)]);
      if (result.error || result.status !== 0) return false;
    }
  }
  return true;
}

function perform(operation, programs, { dryRun = false } = {}) {
  const inventory = new Map(getInventory().map((entry) => [entry.id, entry.installed]));
  let failures = 0;
  for (const program of programs) {
    const installed = inventory.get(program.id);
    if (installed === null) {
      console.error(`Cannot determine whether ${program.name} is installed. Is Homebrew available?`);
      failures += 1;
      continue;
    }
    if (operation === 'install' && installed) {
      console.log(`Already installed: ${program.name}`);
      if (program.recipe && !applyRecipe(program, operation, dryRun)) {
        console.error(`The post-install recipe failed for ${program.name}.`);
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
      continue;
    }
    const args = brewArgs(program, operation);
    if (dryRun) {
      console.log(`Would run: brew ${args.map((arg) => JSON.stringify(arg)).join(' ')}`);
    } else {
      const actionLabel = operation === 'install' ? 'Installing'
        : operation === 'reinstall' ? 'Reinstalling' : 'Removing';
      console.log(`${actionLabel} ${program.name}…`);
      const result = command('brew', args);
      if (result.error || result.status !== 0) {
        console.error(`Failed to ${operation} ${program.name}.`);
        failures += 1;
        continue;
      }
    }
    if (!applyRecipe(program, operation, dryRun)) {
      console.error(`The post-install recipe failed for ${program.name}.`);
      failures += 1;
    }
  }
  return failures === 0 ? 0 : 1;
}

function listPrograms({ category, json = false } = {}) {
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
      console.log(`  ${program.id.padEnd(24)} ${program.name} (${status}${version})`);
    }
  }
  return 0;
}

function parseListOptions(args) {
  let category;
  let json = false;
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === '--json') json = true;
    else if (args[index] === '--category' && args[index + 1]) category = args[++index];
    else throw new Error(`Unknown list option: ${args[index]}`);
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

const categories = ['All', ...new Set(manifest.programs.map(({ category }) => category))];
function categoryProgramIds(name) {
  const matches = manifest.programs.filter((program) => program.category.toLowerCase() === name.toLowerCase());
  if (!matches.length) throw new Error(`Unknown category '${name}'. Available: ${categories.slice(1).join(', ')}`);
  return matches.map(({ id }) => id);
}

function Panel({ title, color = 'cyan', width, marginLeft = 0, children }) {
  return React.createElement(Box, {
    flexDirection: 'column',
    borderStyle: 'single',
    borderColor: color,
    paddingX: 1,
    width,
    marginLeft,
  },
  React.createElement(Text, { bold: true, color }, title),
  children);
}

function fitCell(value, width) {
  const text = String(value);
  if (width < 1) return '';
  if (text.length > width) return `${text.slice(0, Math.max(0, width - 1))}…`;
  return text.padEnd(width);
}
function useTerminalSize() {
  const { stdout } = useStdout();
  const [size, setSize] = useState(() => ({
    columns: stdout.columns || 80,
    rows: stdout.rows || 24,
  }));
  useEffect(() => {
    const updateSize = () => setSize({
      columns: stdout.columns || 80,
      rows: stdout.rows || 24,
    });
    stdout.on('resize', updateSize);
    return () => stdout.off('resize', updateSize);
  }, [stdout]);
  return size;
}


function Dashboard({ onExit }) {
  const { columns, rows } = useTerminalSize();
  const [categoryIndex, setCategoryIndex] = useState(0);
  const [cursor, setCursor] = useState(0);
  const [selected, setSelected] = useState(() => new Set());
  const [confirmRemoval, setConfirmRemoval] = useState(false);
  const [refreshInventory, setRefreshInventory] = useState(0);
  const [message, setMessage] = useState('Ready · select programs to install or remove');
  const [query, setQuery] = useState('');
  const [filtering, setFiltering] = useState(false);
  const [view, setView] = useState('catalog');
  const [showDetails, setShowDetails] = useState(columns >= 78);
  const inventory = useMemo(() => getInventory(), [refreshInventory]);
  const installedCount = inventory.filter((program) => program.installed === true).length;
  const availableCount = inventory.filter((program) => program.installed === false).length;
  const visible = inventory.filter((program) =>
    (view !== 'installed' || program.installed === true) &&
    (categories[categoryIndex] === 'All' || program.category === categories[categoryIndex]) &&
    `${program.id} ${program.name} ${program.package}`.toLowerCase().includes(query.toLowerCase()));
  const activeIndex = Math.min(cursor, Math.max(0, visible.length - 1));
  const active = visible[activeIndex];
  const sideBySide = showDetails && columns >= 78;
  const panelWidth = Math.max(1, columns - 4);
  const listWidth = sideBySide ? Math.floor((panelWidth - 1) * 0.62) : panelWidth;
  const detailsWidth = sideBySide ? panelWidth - listWidth - 1 : panelWidth;
  const listInner = Math.max(12, listWidth - 4);
  const detailInner = Math.max(12, detailsWidth - 4);
  const viewportBase = sideBySide ? 22 : showDetails ? 30 : columns < 78 ? 30 : 22;
  const viewport = Math.max(1, Math.min(12, rows - viewportBase));
  const first = Math.max(0, Math.min(activeIndex - viewport + 1, visible.length - viewport));
  const page = visible.slice(first, first + viewport);
  const pageRange = visible.length ? `${first + 1}-${first + page.length}` : '0-0';
  const statusFor = (program) => program.installed === null
    ? 'UNKNOWN' : program.installed ? 'INSTALLED' : 'AVAILABLE';
  const statusColor = (program) => program.installed === true
    ? 'green' : program.installed === false ? 'gray' : 'yellow';
  const categoryLabel = categories[categoryIndex] === 'All' ? 'ALL CATEGORIES' : categories[categoryIndex].toUpperCase();
  const summaryCards = [
    { title: 'PROGRAMS', value: inventory.length, note: 'in catalog', color: 'cyan' },
    { title: 'INSTALLED', value: installedCount, note: 'managed by Homebrew', color: 'green' },
    { title: 'AVAILABLE', value: availableCount, note: 'ready to install', color: 'yellow' },
  ];
  const gap = 1;
  const cardWidth = Math.floor((panelWidth - gap * 2) / 3);
  const cards = React.createElement(Box, {
    flexDirection: columns >= 78 ? 'row' : 'column',
    alignItems: 'stretch',
  }, ...summaryCards.map((card, index) => React.createElement(Panel, {
    key: card.title,
    title: card.title,
    color: card.color,
    width: columns >= 78 ? cardWidth : panelWidth,
    marginLeft: columns >= 78 && index ? gap : 0,
  },
  React.createElement(Text, { bold: true, color: card.color }, String(card.value).padStart(2, '0')),
  React.createElement(Text, { dimColor: true }, fitCell(card.note, Math.max(1, (columns >= 78 ? cardWidth : panelWidth) - 4))))));

  useInput((input, key) => {
    if (confirmRemoval) {
      if (input === 'y') {
        const status = perform('remove', resolvePrograms([...selected]));
        setMessage(status === 0 ? 'Removal completed' : 'Some removals failed');
        setSelected(new Set());
        setConfirmRemoval(false);
        setRefreshInventory((value) => value + 1);
      } else if (input === 'n' || key.escape) {
        setConfirmRemoval(false);
        setMessage('Removal cancelled');
      }
      return;
    }
    if (filtering) {
      if (key.escape || key.return) setFiltering(false);
      else if (key.backspace || key.delete) setQuery((value) => value.slice(0, -1));
      else if (input && input.length === 1 && input >= ' ') setQuery((value) => value + input);
      setCursor(0);
      return;
    }
    if (input === 'q' || key.escape) { onExit(); return; }
    if (input === '/') { setFiltering(true); return; }
    if (key.tab) {
      setView((value) => value === 'catalog' ? 'installed' : 'catalog');
      setCursor(0);
      return;
    }
    if (input === 'd') { setShowDetails((value) => !value); return; }
    if (key.leftArrow || key.rightArrow) {
      setCategoryIndex((index) => (index + (key.rightArrow ? 1 : categories.length - 1)) % categories.length);
      setCursor(0);
      return;
    }
    if (input === 'a' || input === 'A') {
      if (view !== 'catalog' || categories[categoryIndex] === 'All') {
        setMessage('Choose a specific category in the catalog before selecting all its programs.');
      } else {
        const categoryPrograms = inventory.filter((program) => program.category === categories[categoryIndex]);
        setSelected((current) => new Set([...current, ...categoryPrograms.map(({ id }) => id)]));
        setMessage(`Selected all ${categoryPrograms.length} programs in ${categories[categoryIndex]}. Press Enter to install.`);
      }
      return;
    }
    if (key.upArrow) setCursor((index) => (index + visible.length - 1) % Math.max(visible.length, 1));
    if (key.downArrow) setCursor((index) => (index + 1) % Math.max(visible.length, 1));
    if ((input === ' ' || input === 'x') && active) {
      setSelected((current) => {
        const next = new Set(current);
        if (next.has(active.id)) next.delete(active.id); else next.add(active.id);
        return next;
      });
    }
    if (key.return && selected.size) {
      const status = perform('install', resolvePrograms([...selected]));
      setMessage(status === 0 ? 'Installation completed' : 'Some installations failed');
      setSelected(new Set());
      setRefreshInventory((value) => value + 1);
    }
    if (input === 'I' || input === 'i') {
      const { programs: reinstallSelection, skipped } = resolveReinstallSelection(selected, active, inventory);
      if (!reinstallSelection.length) {
        const reason = selected.size
          ? 'None of the selected programs is installed; select an installed program to reinstall.'
          : active ? `${active.name} is not installed; focus an installed program to reinstall it.` : 'No program is available to reinstall.';
        setMessage(reason);
      } else {
        const status = perform('reinstall', reinstallSelection);
        setMessage(status === 0
          ? `Reinstallation completed${skipped ? ` · skipped ${skipped} uninstalled selection(s)` : ''}`
          : 'Some selected programs could not be reinstalled');
        setSelected(new Set());
        setRefreshInventory((value) => value + 1);
      }
      return;
    }
    if (input === 'r' && selected.size) {
      setConfirmRemoval(true);
      setMessage(`Remove ${selected.size} selected program(s)? Confirm with y; cancel with n.`);
    }
  });

  const nameWidth = Math.max(8, Math.floor((listInner - 24) * 0.65));
  const categoryWidth = Math.max(6, listInner - 24 - nameWidth);
  const tableHeader = [
    fitCell('', 2), fitCell('STATUS', 10), fitCell('PROGRAM', nameWidth),
    fitCell('TYPE', 8), fitCell('CATEGORY', categoryWidth),
  ].join(' ');
  const tableRows = page.length ? page.map((program, index) => {
    const rowIndex = first + index;
    const selectedRow = rowIndex === activeIndex;
    const line = [
      fitCell(selected.has(program.id) ? '◉' : selectedRow ? '›' : ' ', 2),
      fitCell(statusFor(program), 10),
      fitCell(program.name, nameWidth),
      fitCell(program.kind === 'cask' ? 'APP' : 'CLI', 8),
      fitCell(program.category, categoryWidth),
    ].join(' ');
    return React.createElement(Text, {
      key: program.id,
      color: selectedRow ? 'cyan' : statusColor(program),
      bold: selectedRow,
    }, line);
  }) : [React.createElement(Text, { key: 'empty', dimColor: true }, 'No matching programs.')];
  while (tableRows.length < viewport) tableRows.push(React.createElement(Text, { key: `empty-${tableRows.length}` }, ' '));

  const detailRows = active ? [
    ['ID', active.id],
    ['CATEGORY', active.category],
    ['PACKAGE', active.package],
    ['STATUS', statusFor(active)],
    ['INSTALLED VERSION', active.installed ? active.version || 'Not reported' : '—'],
    ...(active.appdir ? [['INSTALL TO', active.appdir]] : []),
    ...(active.noQuarantine ? [['OPTION', 'Install without quarantine']] : []),
    ...(active.recipe ? [['RECIPE', active.recipe === 'neovim-config' ? 'Preserve/migrate Neovim config' : 'Sync OMP config and plugins']] : []),
  ] : [['DETAILS', 'Select a program to inspect its installation metadata.']];
  const detailsPanel = React.createElement(Panel, {
    title: active ? `PROGRAM DETAILS · ${active.name}` : 'PROGRAM DETAILS',
    color: 'blue',
    width: sideBySide ? detailsWidth : undefined,
    marginLeft: sideBySide ? 1 : 0,
  }, ...detailRows.map(([label, value], index) => React.createElement(Text, {
    key: `detail-${index}`,
    color: label === 'STATUS' && active ? statusColor(active) : undefined,
  }, `${fitCell(label, 13)} ${fitCell(value, Math.max(1, detailInner - 14))}`)));
  const listPanel = React.createElement(Panel, {
    title: view === 'installed' ? 'INSTALLED PROGRAMS' : 'SOFTWARE CATALOG',
    width: sideBySide ? listWidth : undefined,
  },
  React.createElement(Text, { bold: true }, fitCell(
    `${categoryLabel} · ${visible.length}/${inventory.length} · ${pageRange}`,
    listInner,
  )),
  React.createElement(Text, { color: filtering || query ? 'cyan' : 'gray' },
    fitCell(`FILTER ${filtering ? `${query}▏` : query || '(press /)'}`, listInner)),
  React.createElement(Text, { bold: true }, fitCell(tableHeader, listInner)),
  ...tableRows);
  const panels = React.createElement(Box, {
    flexDirection: sideBySide ? 'row' : 'column',
    alignItems: 'stretch',
  }, listPanel, showDetails ? detailsPanel : null);
  const shortcutLines = confirmRemoval
    ? ['Y confirm removal · N/Esc cancel']
    : [
      '↑↓ move · Space select · A all in category · Enter install · I reinstall active/selected',
      'R remove · Tab view · / filter · ←→ category · D details · Q quit',
    ];

  return React.createElement(Box, { flexDirection: 'column', paddingX: 1 },
    React.createElement(Text, { dimColor: true, bold: true },
      fitCell('DOTFILES  /  PROGRAM MANAGER  ·  HOMEBREW CATALOG', panelWidth)),
    cards,
    React.createElement(Box, { marginTop: 1, flexDirection: 'row' },
      React.createElement(Text, {
        bold: view === 'catalog',
        color: view === 'catalog' ? 'cyan' : 'gray',
      }, ' CATALOG '),
      React.createElement(Text, { dimColor: true }, '│'),
      React.createElement(Text, {
        bold: view === 'installed',
        color: view === 'installed' ? 'cyan' : 'gray',
      }, ' INSTALLED ')),
    React.createElement(Box, {
      flexDirection: sideBySide ? 'row' : 'column',
      alignItems: 'stretch',
      marginTop: 1,
    }, panels),
    React.createElement(Panel, {
      title: confirmRemoval ? 'CONFIRM REMOVAL' : 'ACTIVITY',
      color: confirmRemoval ? 'yellow' : 'cyan',
      marginTop: 1,
    }, React.createElement(Text, null, fitCell(message, panelWidth - 4))),
    ...shortcutLines.map((line, index) => React.createElement(Text, {
      key: `shortcut-${index}`,
      dimColor: true,
      marginTop: index ? 0 : 1,
    }, fitCell(line, panelWidth))));
}

function printHelp() {
  console.log(`Dotfiles program manager\n\nUsage:\n  dotfiles [interactive]\n  dotfiles list [--category NAME] [--json]\n  dotfiles install <id... | --profile NAME | --category NAME> [--dry-run]\n  dotfiles reinstall <installed-id...> [--dry-run]\n  dotfiles remove <id...> [--dry-run] [--yes]\n  dotfiles profiles\n  dotfiles update [--dry-run]\n  dotfiles doctor\n  dotfiles core\n\nProfiles: ${Object.keys(manifest.profiles).join(', ')}\nInstall/reinstall/remove IDs are shown by 'dotfiles list'.`);
}

async function main(args) {
  const [commandName = 'interactive', ...argsRest] = args;
  if (['help', '--help', '-h'].includes(commandName)) { printHelp(); return 0; }
  if (commandName === 'list') return listPrograms(parseListOptions(argsRest));
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
    const programs = resolvePrograms([...ids, ...profileIds, ...categoryIds]);
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
