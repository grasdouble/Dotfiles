import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex, ScrollHandle } from "gpui-base";
import { checking, exec, layout, openOverlay, panes, run, spaces, theme, window } from "herdr";

const FOLD_KEY = "projects.folded";
const REFRESH_MS = 30_000;
const BRANCH_FIELD = "branch refs/heads/";
const locationKey = (machine, path) => JSON.stringify([machine, path]);
const basename = path => path.split(/[/\\]/).filter(Boolean).pop() || path;
const icon = (name, color) => svg(`mods/workspace-chrome/${name}.svg`).size(13).flex_none().text_color(color);

function locations() {
  const firstFolder = new Map();
  for (const pane of panes()) {
    if (pane.cwd && !firstFolder.has(pane.tab)) firstFolder.set(pane.tab, pane.cwd);
  }
  return spaces().map(space => {
    const cwd = space.tabs.map(tab => firstFolder.get(tab.id)).find(Boolean) || space.folder;
    return { space, key: cwd ? locationKey(space.machine ?? null, cwd) : null };
  });
}

function parseWorktrees(output) {
  const worktrees = [];
  let entry;
  for (const field of output.split("\0")) {
    if (field.startsWith("worktree ")) {
      entry = { path: field.slice(9), branch: "Detached HEAD" };
      worktrees.push(entry);
    } else if (entry && field.startsWith(BRANCH_FIELD)) {
      entry.branch = field.slice(BRANCH_FIELD.length);
    } else if (entry && (field === "bare" || field === "prunable" || field.startsWith("prunable "))) {
      entry.hidden = true;
    }
  }
  return worktrees;
}

async function inspect(key) {
  const [machine, cwd] = JSON.parse(key);
  const options = { cwd, on: machine, timeout: 5000 };
  const root = await exec("git", ["rev-parse", "--show-toplevel"], options);
  if (root.code !== 0) return null;
  const result = await exec("git", ["worktree", "list", "--porcelain", "-z"], options);
  // Git emits the primary checkout first, even when queried from a linked worktree.
  if (result.code !== 0) throw new Error(result.stderr);
  const worktrees = parseWorktrees(result.stdout);
  const checkout = root.stdout.replace(/\r?\n$/, "");
  if (!worktrees.some(tree => tree.path === checkout)) return null;
  return { checkout, worktrees, project: locationKey(machine, worktrees[0].path) };
}

function groupProjects(entries, cache) {
  const machines = new Map();
  for (const { space, key } of entries) {
    const machine = space.machine ?? null;
    if (!machines.has(machine)) machines.set(machine, { groups: new Map(), rows: [] });
    const { groups, rows } = machines.get(machine);
    const snapshot = cache.get(key);
    const info = snapshot?.info;
    if (!info) {
      rows.push({ space });
      continue;
    }
    let project = groups.get(info.project);
    if (!project) {
      project = { id: info.project, trees: [], byPath: new Map(), active: false, updated: -1 };
      groups.set(info.project, project);
      rows.push(project);
    }
    if (snapshot.at > project.updated) {
      project.trees = info.worktrees;
      project.updated = snapshot.at;
    }
    if (!project.byPath.has(info.checkout)) project.byPath.set(info.checkout, []);
    project.byPath.get(info.checkout).push(space);
    project.active ||= space.active;
  }
  return machines;
}

export default class Projects extends View {
  init(_props, cx) {
    this.cache = new Map();
    this.scroll = ScrollHandle.new();
    try { this.folded = new Set(JSON.parse(localStorage.getItem(FOLD_KEY) ?? "[]")); }
    catch { this.folded = new Set(); }
    if (!checking()) {
      this.refresh(cx);
      cx.timer.every(1000, cx => { if (window()?.visible) this.refresh(cx); });
    }
  }

  refresh(cx) {
    if (this.refreshing) return;
    const keys = new Set(locations().map(entry => entry.key).filter(Boolean));
    for (const key of this.cache.keys()) if (!keys.has(key)) this.cache.delete(key);
    const now = Date.now();
    const pending = [...keys].filter(key => now - (this.cache.get(key)?.checked ?? 0) >= REFRESH_MS);
    if (!pending.length) return;
    this.refreshing = true;
    cx.spawn(async cx => {
      let next = 0;
      await Promise.all(Array.from({ length: Math.min(4, pending.length) }, async () => {
        while (next < pending.length) {
          const key = pending[next++];
          try { this.cache.set(key, { info: await inspect(key), at: Date.now(), checked: Date.now() }); }
          catch { this.cache.set(key, { ...this.cache.get(key), checked: Date.now() }); }
        }
      }));
      this.refreshing = false;
      cx.notify();
    });
  }

  row(id, t, active, indent = 8) {
    return h_flex().id(id).h(28).flex_none().pl(indent).pr(8).gap(7).items_center().rounded(6)
      .cursor_pointer().text_color(active ? t.foreground : t.muted)
      .when(active, el => el.bg(t.selected)).when(!active, el => el.hover(s => s.bg(t.hover).text_color(t.foreground)));
  }

  spaceMenu(space) {
    openOverlay({ mod: "menu", kind: "popup", props: { tab: "space", target: { id: space.id } } });
  }

  spaceRow(space, t, indent = 8) {
    return this.row(`space-${space.id}`, t, space.active, indent)
      .on_click(() => run("space.select", { id: space.id }))
      .on_mouse_down("right", () => this.spaceMenu(space))
      .child(icon("folder", t.dim)).child(div().min_w(0).truncate().child(space.name));
  }

  projectRows(project, machine, t) {
    const primary = project.trees[0];
    const name = basename(primary.path).replace(/\.git$/, "");
    const folded = this.folded.has(project.id);
    const header = this.row(`project-${project.id}`, t, folded && project.active)
      .tooltip(primary.path)
      .on_click((_event, cx) => {
        if (this.folded.has(project.id)) this.folded.delete(project.id);
        else this.folded.add(project.id);
        localStorage.setItem(FOLD_KEY, JSON.stringify([...this.folded]));
        cx.notify();
      })
      .child(icon(folded ? "chevron-right" : "chevron-down", t.dim))
      .child(icon("folder", t.accent))
      .child(div().flex_1().min_w(0).truncate().font_semibold().child(name));
    const rows = [{ el: header, active: folded && project.active }];
    if (folded) return rows;

    const visiblePaths = new Set();
    const branchCounts = new Map();
    for (const tree of project.trees) {
      if (!tree.hidden) branchCounts.set(tree.branch, (branchCounts.get(tree.branch) ?? 0) + 1);
    }
    for (const tree of project.trees) {
      if (tree.hidden) continue;
      visiblePaths.add(tree.path);
      const open = project.byPath.get(tree.path) ?? [];
      const active = open.find(space => space.active);
      const target = active ?? open[0];
      const label = branchCounts.get(tree.branch) > 1 ? `${tree.branch} · ${basename(tree.path)}` : tree.branch;
      const row = this.row(`tree-${project.id}-${tree.path}`, t, !!active && open.length === 1, 23)
        .tooltip(tree.path)
        .on_click(() => target ? run("space.select", { id: target.id }) : run("space.new", { folder: tree.path, machine: machine ?? "" }))
        .when(!!target, el => el.on_mouse_down("right", () => this.spaceMenu(target)))
        .child(icon("branch", target ? t.accent : t.dim))
        .child(div().flex_1().min_w(0).truncate().child(label))
        .when(tree === primary, el => el.child(div().flex_none().text_size(10).text_color(t.dim).child("Primary")));
      rows.push({ el: row, active: !!active && open.length === 1 });
      if (open.length > 1) {
        for (const space of open) rows.push({ el: this.spaceRow(space, t, 38), active: space.active });
      }
    }
    for (const [path, open] of project.byPath) {
      if (!visiblePaths.has(path)) {
        for (const space of open) rows.push({ el: this.spaceRow(space, t, 23), active: space.active });
      }
    }
    return rows;
  }

  render() {
    const t = theme();
    const entries = locations();
    const sidebar = layout()?.children?.find(node => node.id === "body")?.children?.find(node => node.id === "sidebar");
    const narrow = (sidebar?.size?.px ?? 280) < 160;
    const rows = [];
    if (narrow) {
      entries.forEach(({ space }, index) => rows.push({
        el: this.row(`space-${space.id}`, t, space.active, 0).justify_center().pr(0).tooltip(space.name)
          .on_click(() => run("space.select", { id: space.id })).child(String(index + 1)),
        active: space.active,
      }));
    } else {
      const grouped = groupProjects(entries, this.cache);
      for (const [machine, { rows: projects }] of grouped) {
        if (machine || grouped.size > 1) rows.push({ el: h_flex().h(26).px(8).flex_none().items_center()
          .text_size(11).text_color(t.dim).child(machine ?? "This computer") });
        for (const project of projects) {
          if (project.space) rows.push({ el: this.spaceRow(project.space, t), active: project.space.active });
          else rows.push(...this.projectRows(project, machine, t));
        }
      }
    }
    const active = entries.find(entry => entry.space.active)?.space.id;
    const index = rows.findIndex(row => row.active);
    if (active !== this.active || index !== this.activeIndex) {
      this.active = active;
      this.activeIndex = index;
      if (index >= 0) this.scroll.scroll_to_item(index);
    }
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .child(h_flex().h(31).flex_none().px(10).items_center().justify_between().text_size(11.5).text_color(t.dim)
        .when(narrow, el => el.px(0).justify_center())
        .when(!narrow, el => el.child("Projects"))
        .child(div().id("project-new").size(26).flex().items_center().justify_center().rounded(6)
          .hover(s => s.bg(t.hover)).tooltip("New space").on_click(() => run("space.new")).child(icon("plus", t.muted))))
      .child(v_flex().flex_1().min_h(0).px(narrow ? 2 : 8).pb(8).overflow_y_scrollbar().track_scroll(this.scroll)
        .children(rows.map(row => row.el)));
  }
}
