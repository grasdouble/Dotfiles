import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const bundledFormulae = ['qemu', 'docker', 'docker-buildx'];

function resolveDockerPluginDirectory(command) {
  const result = command('brew', ['--prefix'], { capture: true });
  const prefix = (result.stdout || '').trim();
  if (result.error || result.status !== 0 || !prefix) {
    console.error('Could not resolve the Homebrew prefix for Docker Buildx.');
    return null;
  }
  return path.join(prefix, 'lib/docker/cli-plugins');
}

function updateDockerConfig(operation, pluginDirectory) {
  const configPath = path.join(process.env.HOME || os.homedir(), '.docker', 'config.json');
  let configFile = configPath;
  const linkStat = fs.lstatSync(configPath, { throwIfNoEntry: false });
  if (!linkStat && operation === 'remove') return true;
  if (linkStat?.isSymbolicLink()) {
    try {
      configFile = fs.realpathSync(configPath);
    } catch (error) {
      console.error(`Could not resolve Docker config symlink ${configPath}: ${error.message}`);
      return false;
    }
  } else if (linkStat && !linkStat.isFile()) {
    console.error(`Docker config path is not a regular file: ${configPath}`);
    return false;
  }

  let config = {};
  let fileStat;
  if (linkStat) {
    try {
      config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
      fileStat = fs.statSync(configFile);
    } catch (error) {
      console.error(`Could not read Docker config ${configPath}: ${error.message}`);
      return false;
    }
    if (!config || Array.isArray(config) || typeof config !== 'object' || !fileStat.isFile()) {
      console.error(`Docker config must contain a JSON object: ${configPath}`);
      return false;
    }
  }

  const pluginDirectories = config.cliPluginsExtraDirs;
  if (operation === 'install') {
    if (pluginDirectories !== undefined && !Array.isArray(pluginDirectories)) {
      console.error(`Docker config cliPluginsExtraDirs must be an array: ${configPath}`);
      return false;
    }
    if (pluginDirectories?.includes(pluginDirectory)) return true;
    config.cliPluginsExtraDirs = [...(pluginDirectories || []), pluginDirectory];
  } else {
    if (!Array.isArray(pluginDirectories)) return true;
    const remaining = pluginDirectories.filter((directory) => directory !== pluginDirectory);
    if (remaining.length === pluginDirectories.length) return true;
    if (remaining.length) config.cliPluginsExtraDirs = remaining;
    else delete config.cliPluginsExtraDirs;
  }

  const mode = fileStat ? fileStat.mode & 0o777 : 0o600;
  const temporaryPath = `${configFile}.dotfiles-${process.pid}.tmp`;
  try {
    fs.mkdirSync(path.dirname(configFile), { recursive: true });
    fs.writeFileSync(temporaryPath, `${JSON.stringify(config, null, 2)}\n`, { mode });
    fs.renameSync(temporaryPath, configFile);
    return true;
  } catch (error) {
    try { fs.rmSync(temporaryPath, { force: true }); } catch {}
    console.error(`Could not update Docker config ${configPath}: ${error.message}`);
    return false;
  }
}

export function applyColimaRecipe(operation, dryRun, { command }) {
  if (!['install', 'reinstall', 'remove'].includes(operation)) return true;
  const pluginDirectory = resolveDockerPluginDirectory(command);
  if (!pluginDirectory) return false;
  const brewOperation = operation === 'remove' ? 'uninstall' : 'install';
  if (dryRun) {
    console.log(`Would run: brew ${brewOperation} --formula ${bundledFormulae.join(' ')}`);
    console.log(`${operation === 'remove' ? 'Would remove' : 'Would add'} ${pluginDirectory} ${operation === 'remove' ? 'from' : 'to'} ${path.join(process.env.HOME || os.homedir(), '.docker', 'config.json')}.`);
    return true;
  }

  let formulae = bundledFormulae;
  if (operation === 'remove') {
    const result = command('brew', ['list', '--formula', '--versions'], { capture: true });
    if (result.error || result.status !== 0) return false;
    const installed = new Set((result.stdout || '').split(/\r?\n/)
      .map((line) => line.trim().split(/\s+/, 1)[0])
      .filter(Boolean)
      .map((name) => name.split('/').at(-1)));
    formulae = bundledFormulae.filter((name) => installed.has(name));
  }

  if (formulae.length) {
    const result = command('brew', [brewOperation, '--formula', ...formulae]);
    if (result.error || result.status !== 0) return false;
  }
  return updateDockerConfig(operation === 'remove' ? 'remove' : 'install', pluginDirectory);
}
