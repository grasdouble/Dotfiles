import React, { useEffect, useMemo, useState } from 'react';
import { Box, Text, useInput, useStdout } from 'ink';
import {
  categories,
  getInventory,
  perform,
  recipeLabels,
  resolvePrograms,
} from '../../lib/programs/manager.mjs';
import { resolveReinstallSelection } from '../../lib/programs/reinstall-selection.mjs';


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


export function statusFor(program) {
  if (program.appdirOutdated) return 'APPDIR OLD';
  return program.installed === null ? 'UNKNOWN' : program.installed ? 'INSTALLED' : 'AVAILABLE';
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
  let installedCount = 0;
  let availableCount = 0;
  for (const program of inventory) {
    if (program.installed === true) installedCount += 1;
    else if (program.installed === false) availableCount += 1;
  }
  const normalizedQuery = query.toLowerCase();
  const visible = inventory.filter((program) =>
    (view !== 'installed' || program.installed === true) &&
    (categories[categoryIndex] === 'All' || program.category === categories[categoryIndex]) &&
    `${program.id} ${program.name} ${program.package} ${program.appdirOutdated ? 'appdir changed' : ''}`
      .toLowerCase().includes(normalizedQuery));
  const activeIndex = Math.min(cursor, Math.max(0, visible.length - 1));
  const active = visible[activeIndex];
  const sideBySide = showDetails && columns >= 78;
  const panelWidth = Math.max(1, columns - 4);
  const listWidth = sideBySide ? Math.floor((panelWidth - 1) * 0.62) : panelWidth;
  const detailsWidth = sideBySide ? panelWidth - listWidth - 1 : panelWidth;
  const listInner = Math.max(12, listWidth - 4);
  const detailInner = Math.max(12, detailsWidth - 4);
  const viewportBase = sideBySide ? 22 : showDetails ? 30 : columns < 78 ? 30 : 22;
  const viewport = Math.max(1, rows - viewportBase);
  const first = Math.max(0, Math.min(activeIndex - viewport + 1, visible.length - viewport));
  const page = visible.slice(first, first + viewport);
  const pageRange = visible.length ? `${first + 1}-${first + page.length}` : '0-0';
  const statusColor = (program) => program.appdirOutdated
    ? 'yellow' : program.installed === true ? 'green' : program.installed === false ? 'gray' : 'yellow';
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
    ...(active.appdirOutdated ? [['APPDIR STATUS', 'Reinstall required']] : []),
    ...(active.noQuarantine ? [['OPTION', 'Install without quarantine']] : []),
    ...(active.recipe ? [['RECIPE', recipeLabels[active.recipe] ?? active.recipe]] : []),
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

  return React.createElement(Box, { flexDirection: 'column', height: rows, width: columns, paddingX: 1 },
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
export default Dashboard;