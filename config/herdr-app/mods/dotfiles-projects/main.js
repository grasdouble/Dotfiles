import { View, div, image, svg } from "gpui-kit";
import { h_flex, v_flex, ScrollHandle } from "gpui-base";
import { agents, checking, exec, focused, layout, openOverlay, panes, run, shared, spaces, terminals, theme, window } from "herdr";
import { discoverProjectIcon, projectIcon } from "./project-icons.js";

const FOLD_KEY = "projects.folded";
const REFRESH_MS = 30_000;
const BRANCH_FIELD = "branch refs/heads/";
const STATUS_LABELS = { blocked: "Needs you", done: "Done", working: "Working", idle: "Idle" };
// Keep the activity indicator lit whenever at least one agent is still running.
const ACTIVITY_ORDER = ["working", "blocked", "done"];
function activityOf(sessions) {
  let activity = "idle";
  for (const { status } of sessions) {
    if (status === "working") return status;
    if (status === "blocked" || (status === "done" && activity === "idle")) activity = status;
  }
  return activity;
}
const EMPTY_CHECKOUT = { spaces: [], agents: [] };
const locationKey = (machine, path) => JSON.stringify([machine, path]);
const basename = path => path.split(/[/\\]/).filter(Boolean).pop() || path;
const icon = (name, color) => svg(`mods/workspace-chrome/${name}.svg`).size(13).flex_none().text_color(color);
const projectName = path => basename(path).replace(/\.git$/, "") || basename(path);

function locations() {
  const firstFolder = new Map(), paneFolders = new Map();
  for (const pane of panes()) {
    if (!pane.cwd) continue;
    paneFolders.set(pane.pane, pane.cwd);
    if (!firstFolder.has(pane.tab)) firstFolder.set(pane.tab, pane.cwd);
  }
  const entries = spaces().map(space => {
    const cwd = space.tabs.map(tab => firstFolder.get(tab.id)).find(Boolean) || space.folder;
    return { space, key: cwd ? locationKey(space.machine ?? null, cwd) : null };
  });
  const bySpace = new Map(entries.map(entry => [entry.space.id, entry]));
  const listed = agents();
  const seen = new Set(listed.map(agent => agent.address));
  const children = new Map();
  for (const terminal of terminals()) {
    if (terminal.state !== "live" || !terminal.parent || seen.has(terminal.address)) continue;
    if (!children.has(terminal.parent)) children.set(terminal.parent, []);
    children.get(terminal.parent).push(terminal);
  }
  const sessions = listed.flatMap(agent => {
    const owner = bySpace.get(agent.space);
    if (!owner) return [];
    const cwd = paneFolders.get(agent.pane);
    const machine = owner.space.machine ?? null;
    return [{ agent, machine, key: cwd ? locationKey(machine, cwd) : owner.key }];
  });
  // Workers without a pane inherit their parent's space, but use their own cwd when known.
  for (const { agent, machine, key } of sessions) {
    for (const worker of children.get(agent.address) ?? []) {
      if (seen.has(worker.address)) continue;
      seen.add(worker.address);
      sessions.push({
        agent: { ...worker, space: agent.space, title: worker.name || worker.template, status: worker.status === "error" ? "blocked" : worker.status },
        machine,
        key: worker.cwd ? locationKey(machine, worker.cwd) : key,
      });
    }
  }
  return { entries, sessions };
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

function groupProjects(entries, sessions, cache) {
  const machines = new Map(), bySpace = new Map();
  function machineRows(machine) {
    if (!machines.has(machine)) machines.set(machine, { groups: new Map(), rows: [] });
    return machines.get(machine);
  }
  function checkoutAt(machine, key) {
    const snapshot = cache.get(key);
    const info = snapshot?.info;
    if (!info) return null;
    const { groups, rows } = machineRows(machine);
    let project = groups.get(info.project);
    if (!project) {
      project = { id: info.project, byPath: new Map(), updated: -1 };
      groups.set(info.project, project);
      rows.push(project);
    }
    if (snapshot.at > project.updated) {
      project.trees = info.worktrees;
      project.logo = info.logo;
      project.updated = snapshot.at;
    }
    if (!project.byPath.has(info.checkout)) project.byPath.set(info.checkout, { spaces: [], agents: [] });
    return project.byPath.get(info.checkout);
  }
  for (const { space, key } of entries) {
    const machine = space.machine ?? null;
    const checkout = checkoutAt(machine, key);
    if (checkout) {
      checkout.spaces.push(space);
      bySpace.set(space.id, checkout);
    } else {
      const standalone = { space, agents: [] };
      machineRows(machine).rows.push(standalone);
      bySpace.set(space.id, standalone);
    }
  }
  for (const { agent, machine, key } of sessions) {
    const checkout = checkoutAt(machine, key) ?? bySpace.get(agent.space);
    checkout?.agents.push(agent);
  }
  return machines;
}

export default class Projects extends View {
  init(_props, cx) {
    this.cache = new Map();
    this.icons = new Map();
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
    const { entries, sessions } = locations();
    const keys = new Set([...entries, ...sessions].map(entry => entry.key).filter(Boolean));
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
          try {
            const info = await inspect(key);
            if (info) {
              if (!this.icons.has(info.project)) {
                const [machine, root] = JSON.parse(info.project);
                this.icons.set(info.project, discoverProjectIcon(info.project, projectName(root), root, !machine).catch(() => null));
              }
              info.logo = await this.icons.get(info.project);
            }
            this.cache.set(key, { info, at: Date.now(), checked: Date.now() });
          } catch { this.cache.set(key, { ...this.cache.get(key), checked: Date.now() }); }
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

  agentRows(sessions, shown, t, indent) {
    return sessions.map(agent => {
      const active = agent.address === shown;
      const status = STATUS_LABELS[agent.status] ?? "Agent";
      const program = agent.program;
      const title = agent.pane_name || agent.title?.replace(/^(?:\[ [!.] \] |[✦✋⏳⠁-⣿]\s*)+/u, "").trim();
      const label = title && !/^[~/]|^[A-Za-z]:\\/.test(title) ? title : program?.name || agent.address;
      const picture = program?.icon
        ? (program.tint ? svg(program.icon).text_color(t.muted) : image(program.icon)).size(13).flex_none()
        : svg("icons/agent.svg").text_color(t.muted).size(13).flex_none();
      const el = this.row(`agent-${agent.address}`, t, active, indent).h(25).text_size(12)
        .tooltip(`${label} · ${status}`)
        .on_click(() => run("agent.focus", { terminal: agent.address }))
        .child(picture)
        .child(div().flex_1().min_w(0).truncate().child(label))
        .child(this.statusDot(agent.status, t));
      return { el, active, focusedAgent: active };
    });
  }

  statusDot(status, t) {
    const dot = div().size(8).flex_none().rounded_full();
    return status === "idle" ? dot.border_1().border_color(t.dim) : dot.bg(t[status] ?? t.dim);
  }

  projectRows(project, machine, shown, t) {
    const primary = project.trees[0];
    const name = projectName(primary.path);
    const folded = this.folded.has(project.id);
    const checkouts = [...project.byPath.values()];
    const activeProject = checkouts.some(checkout => checkout.spaces.some(space => space.active) || checkout.agents.some(agent => agent.address === shown));
    const activityByCheckout = new Map(checkouts.map(checkout => [checkout, activityOf(checkout.agents)]));
    const activities = new Set(activityByCheckout.values());
    const activity = ACTIVITY_ORDER.find(status => activities.has(status)) ?? "idle";
    const mode = folded ? "Only running worktrees · Click to show all" : "All worktrees · Click to show only running";
    const header = this.row(`project-${project.id}`, t, folded && activeProject)
      .tooltip(`${primary.path} · ${STATUS_LABELS[activity]}\n${mode}`)
      .on_click((_event, cx) => {
        if (this.folded.has(project.id)) this.folded.delete(project.id);
        else this.folded.add(project.id);
        localStorage.setItem(FOLD_KEY, JSON.stringify([...this.folded]));
        cx.notify();
      })
      .child(icon(folded ? "chevron-right" : "chevron-down", t.dim))
      .child(projectIcon(project.id, name, project.logo))
      .child(div().flex_1().min_w(0).truncate().font_semibold().child(name))
      .child(this.statusDot(activity, t));
    const rows = [{ el: header, active: folded && activeProject }];

    const visiblePaths = new Set();
    const branchCounts = new Map();
    for (const tree of project.trees) {
      if (!tree.hidden) branchCounts.set(tree.branch, (branchCounts.get(tree.branch) ?? 0) + 1);
    }
    for (const tree of project.trees) {
      if (tree.hidden) continue;
      visiblePaths.add(tree.path);
      const checkout = project.byPath.get(tree.path) ?? EMPTY_CHECKOUT;
      const open = checkout.spaces;
      const active = open.find(space => space.active);
      const activity = activityByCheckout.get(checkout) ?? "idle";
      if (folded && activity !== "working") continue;
      const target = active ?? open[0];
      const label = branchCounts.get(tree.branch) > 1 ? `${tree.branch} · ${basename(tree.path)}` : tree.branch;
      const row = this.row(`tree-${project.id}-${tree.path}`, t, !!active && open.length === 1, 23)
        .tooltip(`${tree.path} · ${STATUS_LABELS[activity]}`)
        .on_click(() => target ? run("space.select", { id: target.id }) : run("space.new", { folder: tree.path, machine: machine ?? "" }))
        .when(!!target, el => el.on_mouse_down("right", () => this.spaceMenu(target)))
        .child(icon("branch", target ? t.accent : t.dim))
        .child(div().flex_1().min_w(0).truncate().child(label))
        .when(tree === primary, el => el.child(div().flex_none().text_size(10).text_color(t.dim).child("Primary")))
        .child(this.statusDot(activity, t));
      rows.push({ el: row, active: !!active && open.length === 1 });
      if (open.length > 1) {
        for (const space of open) rows.push({ el: this.spaceRow(space, t, 38), active: space.active });
      }
      rows.push(...this.agentRows(checkout.agents, shown, t, 38));
    }
    for (const [path, checkout] of project.byPath) {
      if (!visiblePaths.has(path) && (!folded || activityByCheckout.get(checkout) === "working")) {
        for (const space of checkout.spaces) rows.push({ el: this.spaceRow(space, t, 23), active: space.active });
        rows.push(...this.agentRows(checkout.agents, shown, t, 38));
      }
    }
    return rows;
  }

  render() {
    const t = theme();
    const { entries, sessions } = locations();
    const shown = focused()?.agent;
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
      const grouped = groupProjects(entries, sessions, this.cache);
      for (const [machine, { rows: projects }] of grouped) {
        if (machine || grouped.size > 1) rows.push({ el: h_flex().h(26).px(8).flex_none().items_center()
          .text_size(11).text_color(t.dim).child(machine ?? "This computer") });
        for (const project of projects) {
          if (project.space) {
            rows.push({ el: this.spaceRow(project.space, t), active: project.space.active });
            rows.push(...this.agentRows(project.agents, shown, t, 23));
          } else rows.push(...this.projectRows(project, machine, shown, t));
        }
      }
    }
    const active = entries.find(entry => entry.space.active)?.space.id;
    const focusedRow = rows.findIndex(row => row.focusedAgent);
    const index = focusedRow >= 0 ? focusedRow : rows.findIndex(row => row.active);
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
      .when(narrow, el => el.child(div().id("expand-projects").h(25).flex().items_center().justify_center()
        .hover(s => s.bg(t.hover)).tooltip("Expand sidebar")
        .on_click(() => run("layout.resize", { id: "sidebar", px: Math.max(160, shared("sidebar.width") ?? 280) }))
        .child(icon("chevron-right", t.muted))))
      .child(v_flex().flex_1().min_h(0).px(narrow ? 2 : 8).pb(8).overflow_y_scrollbar().track_scroll(this.scroll)
        .children(rows.map(row => row.el)));
  }
}
