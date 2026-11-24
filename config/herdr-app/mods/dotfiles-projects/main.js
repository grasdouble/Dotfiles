import { View, div, image, svg } from "gpui-kit";
import { h_flex, v_flex, ScrollHandle } from "gpui-base";
import { agents, checking, exec, focused, layout, openOverlay, panes, pickFolder, run, shared, spaces, terminals, theme, window } from "herdr";
import { discoverProjectIcon, projectIcon } from "./project-icons.js";

const FOLD_KEY = "projects.folded";
const AGENT_FOLD_KEY = "projects.agentGroupsFolded";
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
const panelIcon = (name, color) => svg(`mods/dotfiles-projects/${name}.svg`).size(13).flex_none().text_color(color);

function storedSet(key) {
  try { return new Set(JSON.parse(localStorage.getItem(key) ?? "[]")); }
  catch { return new Set(); }
}

function saveSet(key, values) {
  localStorage.setItem(key, JSON.stringify([...values]));
}

function elapsed(since, now) {
  if (!since) return "";
  const minutes = Math.max(0, Math.floor((now - since) / 60_000));
  if (!minutes) return "<1m";
  if (minutes < 60) return `${minutes}m`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)}h`;
  return `${Math.floor(minutes / 1440)}d`;
}

function locations() {
  const firstFolder = new Map(), paneFolders = new Map();
  for (const pane of panes()) {
    if (!pane.cwd) continue;
    paneFolders.set(pane.pane, pane.cwd);
    if (!firstFolder.has(pane.tab)) firstFolder.set(pane.tab, pane.cwd);
  }
  const changedByTab = new Map();
  const entries = spaces().map(space => {
    const cwd = space.tabs.map(tab => firstFolder.get(tab.id)).find(Boolean) || space.folder;
    for (const tab of space.tabs) changedByTab.set(tab.id, tab.changed_at);
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
    return [{ agent: { ...agent, changedAt: changedByTab.get(agent.tab) }, machine, key: cwd ? locationKey(machine, cwd) : owner.key }];
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
    this.folded = storedSet(FOLD_KEY);
    this.foldedAgents = storedSet(AGENT_FOLD_KEY);
    this.listHidden = false;
    if (!checking()) {
      this.refresh(cx);
      cx.timer.every(1000, cx => { if (window()?.visible) this.refresh(cx); });
      cx.timer.every(60_000, cx => { if (window()?.visible) cx.notify(); });
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

  agentRow(agent, shown, t, now) {
    const active = agent.address === shown;
    const status = STATUS_LABELS[agent.status] ?? "Agent";
    const program = agent.program;
    const title = agent.pane_name || agent.title?.replace(/^(?:\[ [!.] \] |[✦✋⏳⠁-⣿]\s*)+/u, "").trim();
    const label = title && !/^[~/]|^[A-Za-z]:\\/.test(title) ? title : program?.name || agent.address;
    const picture = program?.icon
      ? (program.tint ? svg(program.icon).text_color(t.muted) : image(program.icon)).size(12).flex_none()
      : svg("icons/agent.svg").text_color(t.muted).size(12).flex_none();
    return this.row(`agent-${agent.address}`, t, active, 31).h(25).gap(5).text_size(11)
      .tooltip(`${label} · ${status}`)
      .on_click(() => run("agent.focus", { terminal: agent.address }))
      .child(agent.status === "done" ? icon("circle-check", t.done) : this.statusDot(agent.status, t))
      .child(picture)
      .child(h_flex().flex_1().min_w(0).gap(5).items_center().overflow_hidden()
        .child(div().min_w(0).truncate().child(label))
        .when(Boolean(program?.name && program.name !== label), el =>
          el.child(div().flex_none().max_w(78).truncate().text_color(t.dim).text_size(10).child(program.name))))
      .child(this.timeLabel(agent.changedAt, now, t));
  }

  timeLabel(since, now, t) {
    return div().w(25).flex_none().text_right().text_size(10).text_color(t.dim).child(elapsed(since, now));
  }

  agentGroup(key, sessions, shown, t, now) {
    const group = v_flex();
    if (sessions.length === 0) return group;
    if (sessions.length === 1) return group.child(this.agentRow(sessions[0], shown, t, now));

    const folded = this.foldedAgents.has(key);
    const label = `${sessions.length} agents`;
    return group
      .child(this.row(`agents-${key}`, t, false, 31).h(25).text_size(11)
        .tooltip(folded ? "Show agents" : "Hide agents")
        .on_click((_event, cx) => {
          if (folded) this.foldedAgents.delete(key);
          else this.foldedAgents.add(key);
          saveSet(AGENT_FOLD_KEY, this.foldedAgents);
          cx.notify();
        })
        .child(div().flex_1().child(label))
        .child(icon(folded ? "chevron-right" : "chevron-down", t.dim)))
      .when(!folded, el => el.children(sessions.map(agent => this.agentRow(agent, shown, t, now))));
  }

  checkoutCard(key, checkout, active, shown, t) {
    const focusedAgent = checkout.agents.some(agent => agent.address === shown);
    const selected = active || focusedAgent;
    const el = v_flex().id(`checkout-${key}`).flex_none().my(2).pb(checkout.agents.length ? 4 : 0)
      .rounded(9).border_1().border_color(selected ? t.input : t.chrome)
      .bg(selected ? t.raised : t.chrome);
    return { el, active: selected, focusedAgent };
  }

  statusDot(status, t) {
    const dot = div().size(8).flex_none().rounded_full();
    return status === "idle" ? dot.border_1().border_color(t.dim) : dot.bg(t[status] ?? t.dim);
  }

  projectRows(project, machine, shown, t, now) {
    const primary = project.trees[0];
    const name = projectName(primary.path);
    const folded = this.folded.has(project.id);
    const checkouts = [...project.byPath.values()];
    const activeProject = checkouts.some(checkout => checkout.spaces.some(space => space.active) || checkout.agents.some(agent => agent.address === shown));
    const activityByCheckout = new Map(checkouts.map(checkout => [checkout, activityOf(checkout.agents)]));
    const activities = new Set(activityByCheckout.values());
    const activity = ACTIVITY_ORDER.find(status => activities.has(status)) ?? "idle";
    const mode = folded ? "Worktrees with activity · Click to show all" : "All worktrees · Click to hide idle worktrees";
    const header = this.row(`project-${project.id}`, t, folded && activeProject).h(36)
      .tooltip(`${primary.path} · ${STATUS_LABELS[activity]}\n${mode}`)
      .on_click((_event, cx) => {
        if (this.folded.has(project.id)) this.folded.delete(project.id);
        else this.folded.add(project.id);
        saveSet(FOLD_KEY, this.folded);
        cx.notify();
      })
      .child(projectIcon(project.id, name, project.logo))
      .child(div().flex_1().min_w(0).truncate().font_semibold().child(name))
      .child(this.statusDot(activity, t))
      .child(icon(folded ? "chevron-right" : "chevron-down", t.dim));
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
      if (folded && activity === "idle") continue;
      const target = active ?? open[0];
      const label = branchCounts.get(tree.branch) > 1 ? `${tree.branch} · ${basename(tree.path)}` : tree.branch;
      const key = locationKey(machine, tree.path);
      let changedAt = 0;
      for (const space of open) for (const tab of space.tabs) changedAt = Math.max(changedAt, tab.changed_at ?? 0);
      for (const agent of checkout.agents) changedAt = Math.max(changedAt, agent.changedAt ?? 0);
      const row = this.row(`tree-${key}`, t, false).h(30)
        .tooltip(`${tree.path} · ${STATUS_LABELS[activity]}`)
        .on_click(() => target ? run("space.select", { id: target.id }) : run("space.new", { folder: tree.path, machine: machine ?? "" }))
        .when(!!target, el => el.on_mouse_down("right", () => this.spaceMenu(target)))
        .child(icon("branch", target ? t.accent : t.dim))
        .child(h_flex().flex_1().min_w(0).gap(7).items_center()
          .child(div().min_w(0).truncate().child(label))
          .when(tree === primary, el => el.child(div().tooltip("Primary checkout").child(panelIcon("home", t.dim)))))
        .child(this.statusDot(activity, t))
        .child(this.timeLabel(changedAt, now, t));
      const card = this.checkoutCard(key, checkout, Boolean(active), shown, t);
      card.el.child(row);
      if (open.length > 1) {
        card.el.children(open.map(space => this.spaceRow(space, t, 24)));
      }
      if (checkout.agents.length) card.el.child(this.agentGroup(key, checkout.agents, shown, t, now));
      rows.push(card);
    }
    for (const [path, checkout] of project.byPath) {
      if (!visiblePaths.has(path) && (!folded || activityByCheckout.get(checkout) !== "idle")) {
        const key = locationKey(machine, path);
        const card = this.checkoutCard(key, checkout, checkout.spaces.some(space => space.active), shown, t);
        card.el.children(checkout.spaces.map(space => this.spaceRow(space, t)));
        if (checkout.agents.length) card.el.child(this.agentGroup(key, checkout.agents, shown, t, now));
        rows.push(card);
      }
    }
    return rows;
  }

  toolbar(projectIds, sessions, narrow, t) {
    const control = (id, label, action) => h_flex().id(id).h(24).min_w(24).px(3).flex_none()
      .gap(3).items_center().justify_center().rounded(5).cursor_pointer().text_color(t.muted)
      .hover(s => s.bg(t.hover).text_color(t.foreground)).tooltip(label).on_click(action);
    const add = control("project-new", "New space", () => run("space.new")).child(icon("plus", t.muted));
    const bar = h_flex().h(31).flex_none().px(9).gap(3).items_center().text_size(12).text_color(t.muted);
    if (narrow) return bar.px(0).justify_center().child(add);

    const waiting = sessions.filter(({ agent }) => agent.status === "blocked" || agent.status === "done");
    const next = waiting.find(({ agent }) => agent.status === "blocked") ?? waiting[0];
    const filtered = projectIds.length > 0 && projectIds.every(id => this.folded.has(id));
    return bar
      .child(control("projects-list-toggle", this.listHidden ? "Show projects" : "Hide projects", (_event, cx) => {
        this.listHidden = !this.listHidden;
        cx.notify();
      }).justify_start().flex_1().gap(6)
        .child(icon(this.listHidden ? "chevron-right" : "chevron-down", t.dim))
        .child(div().font_semibold().child("Projects")))
      .child(control("projects-attention", `${waiting.length} waiting or finished`, () => {
        if (next) run("agent.focus", { terminal: next.agent.address });
      }).child(panelIcon("bell", next ? t.accent : t.dim))
        .child(div().text_size(10).child(String(waiting.length))))
      .child(control("projects-filter", filtered ? "Show all worktrees" : "Hide idle worktrees in all projects", (_event, cx) => {
        for (const id of projectIds) {
          if (filtered) this.folded.delete(id);
          else this.folded.add(id);
        }
        saveSet(FOLD_KEY, this.folded);
        cx.notify();
      }).child(panelIcon("filter", filtered ? t.accent : t.muted)))
      .child(control("project-open-folder", "Open folder as a space", (_event, cx) => {
        cx.spawn(async () => {
          const folder = await pickFolder({ prompt: "Open folder as a space" });
          if (folder) run("space.new", { folder, machine: "" });
        });
      }).child(icon("folder-plus", t.muted)))
      .child(add);
  }

  render() {
    const t = theme();
    const { entries, sessions } = locations();
    const shown = focused()?.agent;
    const now = Date.now();
    const sidebar = layout()?.children?.find(node => node.id === "body")?.children?.find(node => node.id === "sidebar");
    const narrow = (sidebar?.size?.px ?? 280) < 160;
    const rows = [], projectIds = [];
    if (narrow) {
      entries.forEach(({ space }, index) => rows.push({
        el: this.row(`space-${space.id}`, t, space.active, 0).justify_center().pr(0).tooltip(space.name)
          .on_click(() => run("space.select", { id: space.id })).child(String(index + 1)),
        active: space.active,
      }));
    } else {
      const grouped = groupProjects(entries, sessions, this.cache);
      for (const [machine, { rows: projects }] of grouped) {
        if (!this.listHidden && (machine || grouped.size > 1)) rows.push({ el: h_flex().h(26).px(8).flex_none().items_center()
          .text_size(11).text_color(t.dim).child(machine ?? "This computer") });
        for (const project of projects) {
          if (!project.space) projectIds.push(project.id);
          if (this.listHidden) continue;
          if (project.space) {
            const { space } = project;
            const card = this.checkoutCard(space.id, project, space.active, shown, t);
            card.el.child(this.spaceRow(space, t));
            if (project.agents.length) card.el.child(this.agentGroup(space.id, project.agents, shown, t, now));
            rows.push(card);
          } else rows.push(...this.projectRows(project, machine, shown, t, now));
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
      .child(this.toolbar(projectIds, sessions, narrow, t))
      .when(narrow, el => el.child(div().id("expand-projects").h(25).flex().items_center().justify_center()
        .hover(s => s.bg(t.hover)).tooltip("Expand sidebar")
        .on_click(() => run("layout.resize", { id: "sidebar", px: Math.max(160, shared("sidebar.width") ?? 280) }))
        .child(icon("chevron-right", t.muted))))
      .child(v_flex().flex_1().min_h(0).px(narrow ? 2 : 8).pb(8).overflow_y_scrollbar().track_scroll(this.scroll)
        .children(rows.map(row => row.el)));
  }
}
