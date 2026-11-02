import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { resolveReinstallSelection } from '../lib/reinstall-selection.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const cli = path.join(root, 'bin/dotfiles.mjs');

function runCli(args, { formulas = [], casks = [], keepHome = false, setup } = {}) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'dotfiles-cli-'));
  const bin = path.join(temp, 'bin');
  fs.mkdirSync(bin);
  const brew = path.join(bin, 'brew');
  fs.writeFileSync(brew, `#!/bin/sh\ncase "$1 $2" in\n  'list --formula') printf '%s\\n' ${formulas.map((value) => `'${value.replaceAll("'", "'\\''")}'`).join(' ')} ;;\n  'list --cask') printf '%s\\n' ${casks.map((value) => `'${value.replaceAll("'", "'\\''")}'`).join(' ')} ;;\n  *) exit 0 ;;\nesac\n`);
  fs.chmodSync(brew, 0o755);
  setup?.(temp);
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: root,
    encoding: 'utf8',
    env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, HOME: temp },
  });
  if (!keepHome) fs.rmSync(temp, { recursive: true, force: true });
  return { status: result.status, stdout: result.stdout, stderr: result.stderr, home: keepHome ? temp : null };
}

test('catalog exposes unique IDs and every profile resolves', () => {
  const catalog = JSON.parse(fs.readFileSync(path.join(root, 'config/programs.json'), 'utf8'));
  const ids = new Set(catalog.programs.map(({ id }) => id));
  assert.equal(ids.size, catalog.programs.length);
  for (const [name, members] of Object.entries(catalog.profiles)) {
    assert.ok(members.length > 0, `${name} profile should not be empty`);
    for (const id of members) assert.ok(ids.has(id), `${name} contains unknown ${id}`);
  }
});

test('list reports inventory state and filters by category', () => {
  const result = runCli(['list', '--category', 'Tools', '--json'], { casks: ['rectangle'] });
  assert.equal(result.status, 0, result.stderr);
  const entries = JSON.parse(result.stdout);
  assert.ok(entries.length > 1);
  assert.ok(entries.every(({ category }) => category === 'Tools'));
  assert.equal(entries.find(({ id }) => id === 'rectangle').installed, true);
  assert.equal(entries.find(({ id }) => id === 'clop').installed, false);
});

test('list exposes installed formula and cask versions and leaves missing versions null', () => {
  const result = runCli(['list', '--json'], {
    formulas: ['jq 1.8.0'],
    casks: ['rectangle 0.83.0', 'spotify'],
  });
  assert.equal(result.status, 0, result.stderr);
  const entries = JSON.parse(result.stdout);
  assert.equal(entries.find(({ id }) => id === 'jq').version, '1.8.0');
  assert.equal(entries.find(({ id }) => id === 'rectangle').version, '0.83.0');
  assert.equal(entries.find(({ id }) => id === 'spotify').version, null);
  assert.equal(entries.find(({ id }) => id === 'spotify').installed, true);

  const text = runCli(['list', '--category', 'Tools'], { casks: ['rectangle 0.83.0'] });
  assert.match(text.stdout, /rectangle.*installed · 0\.83\.0/);
});


test('install accepts a complete category and skips already installed members', () => {
  const catalog = JSON.parse(fs.readFileSync(path.join(root, 'config/programs.json'), 'utf8'));
  const games = catalog.programs.filter(({ category }) => category === 'Games');
  const result = runCli(['install', '--category', 'games', '--dry-run'], { casks: ['steam 6.0'] });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Already installed: Steam/);
  for (const program of games.filter(({ id }) => id !== 'steam')) {
    assert.ok(result.stdout.includes(JSON.stringify(program.package)), `missing category member ${program.id}`);
  }
  assert.doesNotMatch(result.stdout, /"spotify"/);
});

test('install rejects unknown categories', () => {
  const result = runCli(['install', '--category', 'Unknown', '--dry-run']);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Unknown category 'Unknown'/);
});
test('install dry-run previews exact formula and cask invocations', () => {
  const result = runCli(['install', 'neovim', 'visual-studio-code', '--dry-run']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /brew "install" "--formula" "neovim"/);
  assert.match(result.stdout, /brew "install" "--cask" "--appdir=\/Applications\/Developments" "visual-studio-code"/);
  assert.match(result.stdout, /Would link .*init.lua/);
});

test('installing an already-present Neovim preserves an existing user config', () => {
  const result = runCli(['install', 'neovim'], {
    formulas: ['neovim'],
    keepHome: true,
    setup: (home) => {
      const config = path.join(home, '.config/nvim/init.lua');
      fs.mkdirSync(path.dirname(config), { recursive: true });
      fs.writeFileSync(config, 'local configuration');
    },
  });
  try {
    assert.equal(result.status, 0, result.stderr);
    const target = path.join(result.home, '.config/nvim/init.lua');
    assert.equal(fs.readFileSync(target, 'utf8'), 'local configuration');
    assert.match(result.stdout, /Already installed: Neovim/);
  } finally {
    fs.rmSync(result.home, { recursive: true, force: true });
  }
});

test('installing Neovim migrates only the repository-owned legacy link', () => {
  const result = runCli(['install', 'neovim'], {
    formulas: ['neovim'],
    keepHome: true,
    setup: (home) => {
      const configDir = path.join(home, '.config/nvim');
      fs.mkdirSync(configDir, { recursive: true });
      fs.symlinkSync(path.join(root, 'config/nvim/init.vim'), path.join(configDir, 'init.vim'));
    },
  });
  try {
    assert.equal(result.status, 0, result.stderr);
    const configDir = path.join(result.home, '.config/nvim');
    assert.equal(fs.readlinkSync(path.join(configDir, 'init.lua')), path.join(root, 'config/nvim/init.lua'));
    assert.equal(fs.existsSync(path.join(configDir, 'init.vim')), false);
  } finally {
    fs.rmSync(result.home, { recursive: true, force: true });
  }
});

test('reinstall dry-run uses Homebrew reinstall for installed formulae and casks', () => {
  const result = runCli(['reinstall', 'rectangle', 'jq', 'spotify', '--dry-run'], {
    formulas: ['jq'],
    casks: ['rectangle', 'spotify'],
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /brew "reinstall" "--cask" "--appdir=\/Applications\/Tools" "rectangle"/);
  assert.match(result.stdout, /brew "reinstall" "--formula" "jq"/);
  assert.match(result.stdout, /brew "reinstall" "--cask" "--appdir=\/Applications\/Others" "spotify"/);
  assert.doesNotMatch(result.stdout, /"--no-quarantine"/);
});

test('reinstall refuses a program that is not installed', () => {
  const result = runCli(['reinstall', 'steam', '--dry-run']);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /it is not installed/);
  assert.doesNotMatch(result.stdout, /brew "reinstall"/);
});

test('reinstall targets the active installed program when selection is empty', () => {
  const steam = { id: 'steam', installed: true };
  const result = resolveReinstallSelection(new Set(), steam, [steam]);
  assert.deepEqual(result, { programs: [steam], skipped: 0 });
});

test('reinstall selection takes precedence and reports uninstalled selections', () => {
  const programs = [
    { id: 'steam', installed: true },
    { id: 'jq', installed: false },
  ];
  const result = resolveReinstallSelection(new Set(['steam', 'jq']), programs[1], programs);
  assert.deepEqual(result, { programs: [programs[0]], skipped: 1 });
});

test('reinstall does not target an active program that is not installed', () => {
  const active = { id: 'jq', installed: false };
  const result = resolveReinstallSelection(new Set(), active, [active]);
  assert.deepEqual(result, { programs: [], skipped: 1 });
});

test('remove dry-run uses the matching Homebrew package type', () => {
  const result = runCli(['remove', 'rectangle', 'jq', '--dry-run'], { formulas: ['jq'], casks: ['rectangle'] });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /brew "uninstall" "--cask" "rectangle"/);
  assert.match(result.stdout, /brew "uninstall" "--formula" "jq"/);
});

test('unknown IDs fail without attempting installation', () => {
  const result = runCli(['install', 'definitely-not-a-program']);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Unknown program/);
});

test('profiles expand into catalog entries for dry-run installation', () => {
  const result = runCli(['install', '--profile', 'office', '--dry-run']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /microsoft-office/);
});
