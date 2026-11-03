import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { resolveReinstallSelection } from '../lib/programs/reinstall-selection.mjs';
import { buildActiveManifest, manifest } from '../lib/programs/manager.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const cli = path.join(root, 'bin/dotfiles.mjs');

function runCli(args, { formulas = [], casks = [], keepHome = false, setup } = {}) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'dotfiles-cli-'));
  const bin = path.join(temp, 'bin');
  fs.mkdirSync(bin);
  const brew = path.join(bin, 'brew');
  fs.writeFileSync(brew, `#!/bin/sh\nif [ "$1" = "--prefix" ]; then printf '/opt/homebrew\\n'; exit 0; fi\ncase "$1 $2" in\n  'list --formula') printf '%s\\n' ${formulas.map((value) => `'${value.replaceAll("'", "'\\''")}'`).join(' ')} ;;\n  'list --cask') printf '%s\\n' ${casks.map((value) => `'${value.replaceAll("'", "'\\''")}'`).join(' ')} ;;\n  *) exit 0 ;;\nesac\n`);
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
  const catalog = manifest;
  const ids = new Set(catalog.programs.map(({ id }) => id));
  assert.equal(ids.size, catalog.programs.length);
  assert.ok(catalog.programs.every(({ active }) => active === true));
  assert.deepEqual(
    catalog.programs.filter(({ id }) => ['qemu', 'docker', 'docker-buildx', 'tree-sitter-cli', 'cakebrew'].includes(id)).map(({ id }) => id),
    [],
  );
  assert.deepEqual([...new Set(catalog.programs.map(({ category }) => category))], [
    'Development', 'Languages', 'Tools', 'Communication', 'Office', 'Games', 'Others', 'LLM Tools',
  ]);
  for (const [name, members] of Object.entries(catalog.profiles)) {
    for (const id of members) assert.ok(ids.has(id), `${name} contains unknown ${id}`);
  }
});

test('inactive programs stay in source but are removed from profiles', () => {
  const source = {
    version: 1,
    programs: [
      { id: 'editor', active: true },
      { id: 'archive', active: false },
    ],
    profiles: { development: ['editor', 'archive'] },
  };
  const active = buildActiveManifest(source);
  assert.deepEqual(active.programs, [source.programs[0]]);
  assert.deepEqual(active.profiles, { development: ['editor'] });
  assert.equal(source.programs.length, 2);
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

test('list exposes Go and Rust under Languages', () => {
  const result = runCli(['list', '--category', 'Languages', '--json'], {
    formulas: ['go 1.24.0', 'rust 1.84.0'],
  });
  assert.equal(result.status, 0, result.stderr);
  const entries = JSON.parse(result.stdout);
  assert.deepEqual(entries.map(({ id }) => id), ['go', 'rust']);
  assert.ok(entries.every(({ category }) => category === 'Languages'));
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
  const catalog = manifest;
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
  assert.match(result.stdout, /Would run: brew install --formula tree-sitter-cli/);
  assert.match(result.stdout, /brew "install" "--cask" "--appdir=\/Applications\/Developments" "visual-studio-code"/);
  assert.match(result.stdout, /Would link .*init.lua/);
});

test('removing Neovim previews removal of Tree-sitter CLI', () => {
  const result = runCli(['remove', 'neovim', '--dry-run'], {
    formulas: ['neovim 0.12.0', 'tree-sitter-cli 0.24.0'],
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /brew "uninstall" "--formula" "neovim"/);
  assert.match(result.stdout, /Would run: brew uninstall --formula tree-sitter-cli/);
});

test('installing Colima previews its bundled formulas', () => {
  const result = runCli(['install', 'colima', '--dry-run']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /brew "install" "--formula" "colima"/);
  assert.match(result.stdout, /brew install --formula qemu docker docker-buildx/);
});

test('removing Colima previews removal of its bundled formulas', () => {
  const result = runCli(['remove', 'colima', '--dry-run'], {
    formulas: ['colima 0.6.0', 'qemu 10.2.0', 'docker 28.0.0', 'docker-buildx 0.17.0'],
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /brew "uninstall" "--formula" "colima"/);
  assert.match(result.stdout, /brew uninstall --formula qemu docker docker-buildx/);
});

test('installing Colima adds the Buildx plugin path without replacing Docker config', () => {
  const auths = { 'registry.example': { auth: 'token' } };
  const result = runCli(['install', 'colima'], {
    keepHome: true,
    setup: (home) => {
      const config = path.join(home, '.docker/config.json');
      fs.mkdirSync(path.dirname(config), { recursive: true });
      fs.writeFileSync(config, JSON.stringify({ auths, cliPluginsExtraDirs: ['/custom/docker/cli-plugins'] }));
    },
  });
  try {
    assert.equal(result.status, 0, result.stderr);
    const config = JSON.parse(fs.readFileSync(path.join(result.home, '.docker/config.json'), 'utf8'));
    assert.deepEqual(config.auths, auths);
    assert.deepEqual(config.cliPluginsExtraDirs, [
      '/custom/docker/cli-plugins', '/opt/homebrew/lib/docker/cli-plugins',
    ]);
  } finally {
    fs.rmSync(result.home, { recursive: true, force: true });
  }
});

test('installing Colima creates Docker config when none exists', () => {
  const result = runCli(['install', 'colima'], { keepHome: true });
  try {
    assert.equal(result.status, 0, result.stderr);
    const config = JSON.parse(fs.readFileSync(path.join(result.home, '.docker/config.json'), 'utf8'));
    assert.deepEqual(config.cliPluginsExtraDirs, ['/opt/homebrew/lib/docker/cli-plugins']);
  } finally {
    fs.rmSync(result.home, { recursive: true, force: true });
  }
});

test('installing Colima does not duplicate its Buildx plugin path', () => {
  const result = runCli(['install', 'colima'], {
    formulas: ['colima 0.6.0'],
    keepHome: true,
    setup: (home) => {
      const config = path.join(home, '.docker/config.json');
      fs.mkdirSync(path.dirname(config), { recursive: true });
      fs.writeFileSync(config, JSON.stringify({
        cliPluginsExtraDirs: ['/opt/homebrew/lib/docker/cli-plugins'],
      }));
    },
  });
  try {
    assert.equal(result.status, 0, result.stderr);
    const config = JSON.parse(fs.readFileSync(path.join(result.home, '.docker/config.json'), 'utf8'));
    assert.deepEqual(config.cliPluginsExtraDirs, ['/opt/homebrew/lib/docker/cli-plugins']);
  } finally {
    fs.rmSync(result.home, { recursive: true, force: true });
  }
});

test('removing Colima removes only its Buildx plugin path', () => {
  const auths = { 'registry.example': { auth: 'token' } };
  const result = runCli(['remove', 'colima', '--yes'], {
    formulas: ['colima 0.6.0', 'qemu 10.1.0', 'docker 28.0.0', 'docker-buildx 0.17.0'],
    keepHome: true,
    setup: (home) => {
      const config = path.join(home, '.docker/config.json');
      fs.mkdirSync(path.dirname(config), { recursive: true });
      fs.writeFileSync(config, JSON.stringify({
        auths,
        cliPluginsExtraDirs: ['/custom/docker/cli-plugins', '/opt/homebrew/lib/docker/cli-plugins'],
      }));
    },
  });
  try {
    assert.equal(result.status, 0, result.stderr);
    const config = JSON.parse(fs.readFileSync(path.join(result.home, '.docker/config.json'), 'utf8'));
    assert.deepEqual(config.auths, auths);
    assert.deepEqual(config.cliPluginsExtraDirs, ['/custom/docker/cli-plugins']);
  } finally {
    fs.rmSync(result.home, { recursive: true, force: true });
  }
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

test('removing Colima removes bundle members even when Colima is absent', () => {
  const result = runCli(['remove', 'colima', '--yes'], {
    keepHome: true,
    setup: (temp) => {
      const brew = path.join(temp, 'bin', 'brew');
      const calls = path.join(temp, 'brew-calls');
      fs.writeFileSync(brew, `#!/bin/sh
if [ "$1" = "--prefix" ]; then printf '/opt/homebrew\\n'; exit 0; fi
case "$1 $2" in
  'list --formula') printf '%s\\n' 'qemu 10.1' 'docker 28.0' 'docker-buildx 0.17' ;;
  'list --cask') ;;
  *) printf '%s\\n' "$*" >> '${calls}' ;;
esac
`);
      fs.chmodSync(brew, 0o755);
    },
  });
  try {
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Not installed: Colima/);
    assert.deepEqual(
      fs.readFileSync(path.join(result.home, 'brew-calls'), 'utf8').trim().split(/\r?\n/),
      ['uninstall --formula qemu docker docker-buildx'],
    );
  } finally {
    fs.rmSync(result.home, { recursive: true, force: true });
  }
});

test('unknown IDs fail without attempting installation', () => {
  const result = runCli(['install', 'definitely-not-a-program']);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Unknown program/);
});

test('pro profile installs its curated cross-category selection', () => {
  const result = runCli(['install', '--profile', 'pro', '--dry-run']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /visual-studio-code/);
  assert.match(result.stdout, /colima/);
  assert.doesNotMatch(result.stdout, /cakebrew/);
});
