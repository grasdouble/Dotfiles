import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { formatProviderQuota } from "../../../lib/programs/omp/provider-quota.mjs";
import { createPresetTracker } from "./dotfiles-info-presets.ts";
import { mountWidget, type WidgetData } from "./dotfiles-info-widget.ts";



export default function dotfilesInfo(pi: ExtensionAPI) {
  let visible = false;
  let versionLabel: string | undefined;
  let widgetData: WidgetData | undefined;
  let requestWidgetRender: (() => void) | undefined;
  let refreshInFlight = false;
  let refreshPending = false;
  let refreshGitPending = false;
  let refreshPendingContext: ExtensionContext | undefined;


  let quotaProvider: string | undefined;
  let quotaReports: unknown[] = [];
  let quotaFetchedAt = 0;
  let quotaLoading = false;
  let quotaFetchFailed = false;
  const quotaRefreshIntervalMs = 30_000;
  let quotaRefreshGeneration = 0;

  function scheduleQuotaRefresh(ctx: ExtensionContext, generation: number) {
    ctx.setTimeout(() => {
      if (!visible || generation !== quotaRefreshGeneration) return;
      void refreshWidget(ctx);
      if (generation === quotaRefreshGeneration) {
        scheduleQuotaRefresh(ctx, generation);
      }
    }, quotaRefreshIntervalMs);
  }
  function resetQuotaRefreshTimer(ctx: ExtensionContext) {
    const generation = ++quotaRefreshGeneration;
    if (visible) scheduleQuotaRefresh(ctx, generation);
  }

  function refreshProviderQuota(ctx: ExtensionContext, provider: string | undefined) {
    if (!provider || quotaRequest) return;
    if (quotaProvider === provider && Date.now() - quotaFetchedAt < quotaRefreshIntervalMs) return;
    resetQuotaRefreshTimer(ctx);

    quotaProvider = provider;
    quotaLoading = true;
    quotaFetchFailed = false;
    quotaRequest = (async () => {
      try {
        const reports = await ctx.modelRegistry.authStorage.usage.reports({
          provider,
          baseUrlResolver: (id) => ctx.modelRegistry.getProviderBaseUrl(id),
          signal: AbortSignal.timeout(10_000),
        });
        quotaReports = reports ?? [];
        quotaProvider = provider;
        quotaFetchFailed = reports === null;
      } catch {
        quotaFetchFailed = true;
      } finally {
        quotaFetchedAt = Date.now();
        quotaLoading = false;
        quotaRequest = undefined;
        if (visible && ctx.model?.provider === provider) void refreshWidget(ctx);
      }
    })();
  }

  async function run(
    command: string,
    args: string[],
    cwd: string,
  ): Promise<string | undefined> {
    try {
      const result = await pi.exec(command, args, { cwd, timeout: 2000 });
      return result.code === 0 ? result.stdout.trim() : undefined;
    } catch {
      return undefined;
    }
  }
  const presets = createPresetTracker(pi, run);



  async function refreshWidget(ctx: ExtensionContext, refreshGit = false) {
    if (!ctx.hasUI || !visible) return;
    if (refreshInFlight) {
      refreshPending = true;
      refreshGitPending ||= refreshGit;
      refreshPendingContext = ctx;
      return;
    }
    refreshInFlight = true;
    try {
      const activeProvider = ctx.model?.provider;
      refreshProviderQuota(ctx, activeProvider);

      const usage = ctx.getContextUsage();
      const contextPercent = usage
        ? Math.max(0, Math.min(100, usage.percent))
        : undefined;
      const filled =
        contextPercent === undefined ? 0 : Math.ceil((contextPercent / 100) * 8);
      const contextColor =
        contextPercent === undefined
          ? "muted"
          : contextPercent >= 90
            ? "error"
            : contextPercent >= 70
              ? "warning"
              : "success";
      const quota = formatProviderQuota(
        quotaProvider === activeProvider ? quotaReports : [],
        activeProvider,
      );
      const quotaLines = quota.length
        ? quota.map((entry) => [
            { text: `QUOTA ${activeProvider} · `, color: "accent" },
            ...entry.segments.map((segment) => ({ text: `${segment.text} · `, color: segment.status })),
          ])
        : [[{
            text: `QUOTA ${activeProvider || "provider"} · ${quotaLoading ? "checking" : quotaFetchFailed ? "unavailable" : "not reported"}`,
            color: quotaFetchFailed ? "warning" : "muted",
          }]];

      const home = process.env.HOME;
      const project =
        home && (ctx.cwd === home || ctx.cwd.startsWith(`${home}/`))
          ? `~${ctx.cwd.slice(home.length)}`
          : ctx.cwd;
      const roleModels = presets.modelRoles;
      const vibeModels = roleModels
        ? {
            default: roleModels.default,
            fast: roleModels.fast_worker,
            good: roleModels.good_worker,
          }
        : undefined;
      widgetData = {
        version: versionLabel || "unknown version",
        session: pi.getSessionName() || "Unnamed",
        preset: presets.label,
        vibeModels,
        project,
        git: widgetData?.git ?? "Checking Git…",
        gitColor: widgetData?.gitColor ?? "muted",
        usage,
        contextPercent,
        filled,
        contextColor,
        quotaLines,
      };
      requestWidgetRender?.();

      if (refreshGit) {
        const [version, gitStatus] = await Promise.all([
          versionLabel
            ? Promise.resolve(undefined)
            : run("omp", ["--version"], ctx.cwd),
          run("git", ["status", "--porcelain=v1", "--branch"], ctx.cwd),
        ]);
        if (!visible) return;
        if (version) versionLabel = version.replace(/^omp[\/\s]*v?/i, "");

        let git = "Not a Git repository";
        let gitColor: WidgetColor = "error";
        if (gitStatus !== undefined) {
          const [branchLine, ...gitLines] = gitStatus.split(/\r?\n/).filter(Boolean);
          const branchStatus = branchLine?.replace(/^## /, "") ?? "";
          const branch =
            branchStatus.includes("(no branch)") || branchStatus === "HEAD"
              ? "Detached HEAD"
              : branchStatus
                  .replace(/^No commits yet on /, "")
                  .replace(/\.\.\..*$/, "")
                  .replace(/ \[.*$/, "") || "Detached HEAD";
          const changed = gitLines.filter((line) => !line.startsWith("??")).length;
          const untracked = gitLines.length - changed;
          git = `${branch} · ${changed} changed · ${untracked} untracked`;
          gitColor = changed + untracked > 0 ? "warning" : "success";
        }

        if (widgetData) {
          widgetData = {
            ...widgetData,
            version: versionLabel || "unknown version",
            git,
            gitColor,
          };
          requestWidgetRender?.();
        }
      }
    } finally {
      refreshInFlight = false;
      if (refreshPending && visible) {
        const nextContext = refreshPendingContext ?? ctx;
        const refreshGitNext = refreshGitPending;
        refreshPending = false;
        refreshGitPending = false;
        refreshPendingContext = undefined;
        void refreshWidget(nextContext, refreshGitNext);
      }
    }
  }


  async function showWidget(ctx: ExtensionContext) {
    visible = true;
    resetQuotaRefreshTimer(ctx);
    mountWidget(
      ctx,
      () => widgetData,
      (requestRender) => { requestWidgetRender = requestRender; },
    );
    await presets.refresh(ctx);
    await refreshWidget(ctx, true);
  }

  function hideWidget(ctx: ExtensionContext) {
    visible = false;
    quotaRefreshGeneration += 1;
    refreshPending = false;
    refreshGitPending = false;
    refreshPendingContext = undefined;
    if (ctx.hasUI) ctx.ui.setWidget("dotfiles-info", undefined);
  }

  pi.on("session_start", async (_event, ctx) => {
    await showWidget(ctx);
  });

  pi.on("turn_start", (_event, ctx) => {
    void refreshWidget(ctx, true);
  });

  pi.on("turn_end", (_event, ctx) => {
    void refreshWidget(ctx);
  });

  pi.on("agent_end", (_event, ctx) => {
    void refreshWidget(ctx, true);
  });

  pi.on("tool_result", (event, ctx) => {
    const mayChangeFiles = ["bash", "edit", "write"].includes(event.toolName);
    void refreshWidget(ctx, mayChangeFiles);
  });

  pi.on("session_switch", (_event, ctx) => {
    void refreshWidget(ctx, true);
  });

  pi.on("session_branch", (_event, ctx) => {
    void refreshWidget(ctx, true);
  });

  pi.on("session_tree", (_event, ctx) => {
    void refreshWidget(ctx, true);
  });

  pi.on("session_compact", (_event, ctx) => {
    void refreshWidget(ctx);
  });

  pi.on("mode_changed", (_event, ctx) => {
    void refreshWidget(ctx);
  });

  // OMP exposes no model/thinking-level event; direct commands are refreshed
  // after their built-in handlers apply the change. The interactive preset
  // picker is followed by observing its active model and thinking level.
  pi.on("input", (event, ctx) => {
    const input = event.text.trim();
    const presetSwitch = input.match(/^\/modelpreset\s+switch\s+(\S+)/i);
    const presetPicker = /^\/modelpreset$/i.test(input);
    const modelCommand = /^\/model(?:\s+\S+)?$/i.test(input);
    const modelPicker = /^\/model$/i.test(input);
    if (presetSwitch) {
      presets.select(presetSwitch[1]);
    } else if (presetPicker || modelPicker) {
      presets.watchCurrentSelection(ctx, () => visible, () => void refreshWidget(ctx));
    }
    if (/^\/(?:switch|model|models|effort)\s+\S+/i.test(input) || presetSwitch) {
      ctx.setTimeout(() => {
        if (modelCommand) presets.syncFromRuntime(ctx);
        void refreshWidget(ctx, true);
      }, 50);
    }
  });

  pi.on("session_shutdown", (_event, ctx) => hideWidget(ctx));


  pi.registerCommand("dotfiles-info", {
    description: "Show, hide, or refresh the Dotfiles information widget",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) return;
      const action = args.trim().toLowerCase();
      switch (action) {
        case "show":
          if (visible) await refreshWidget(ctx, true);
          else await showWidget(ctx);
          return;
        case "hide":
          hideWidget(ctx);
          return;
        case "refresh":
          if (visible) await refreshWidget(ctx, true);
          else await showWidget(ctx);
          return;
        default:
          ctx.ui.notify(
            "Usage: /dotfiles-info [show|hide|refresh]\nshow  Display the widget\nhide  Hide the widget\nrefresh  Update widget data now",
            "info",
          );
      }
    },
  });

}

