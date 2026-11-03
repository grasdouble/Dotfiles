import { truncateToWidth, visibleWidth } from "@oh-my-pi/pi-tui";
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { formatProviderQuota } from "../../../lib/programs/omp/provider-quota.mjs";


export default function dotfilesInfo(pi: ExtensionAPI) {
  let visible = false;
  let versionLabel: string | undefined;
  const compactTokens = new Intl.NumberFormat(undefined, {
    notation: "compact",
    maximumFractionDigits: 1,
  });

  let quotaProvider: string | undefined;
  let quotaReports: unknown[] = [];
  let quotaFetchedAt = 0;
  let quotaLoading = false;
  let quotaFetchFailed = false;
  let quotaRequest: Promise<void> | undefined;
  const quotaRefreshIntervalMs = 60_000;

  function refreshProviderQuota(ctx: ExtensionContext, provider: string | undefined) {
    if (!provider || quotaRequest) return;
    if (quotaProvider === provider && Date.now() - quotaFetchedAt < quotaRefreshIntervalMs) return;

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

  async function refreshWidget(ctx: ExtensionContext) {
    if (!ctx.hasUI || !visible) return;
    const activeProvider = ctx.model?.provider;
    refreshProviderQuota(ctx, activeProvider);


    const [version, branch, gitStatus] = await Promise.all([
      versionLabel
        ? Promise.resolve(undefined)
        : run("omp", ["--version"], ctx.cwd),
      run("git", ["branch", "--show-current"], ctx.cwd),
      run("git", ["status", "--porcelain=v1"], ctx.cwd),
    ]);
    if (version) versionLabel = version.replace(/^omp[\/\s]*v?/i, "");
    const usage = ctx.getContextUsage();
    const model = ctx.model?.name ?? ctx.model?.id ?? "Unknown";
    const provider = ctx.model?.provider ?? "Unknown";
    const thinking = pi.getThinkingLevel() ?? "default";
    const session = pi.getSessionName() || "Unnamed";
    const gitLines = gitStatus?.split(/\r?\n/).filter(Boolean) ?? [];
    const changed = gitLines.filter((line) => !line.startsWith("??")).length;
    const untracked = gitLines.length - changed;
    const git =
      gitStatus === undefined
        ? "Not a Git repository"
        : `${branch || "Detached HEAD"} · ${changed} changed · ${untracked} untracked`;
    const gitColor =
      gitStatus === undefined
        ? "error"
        : changed + untracked > 0
          ? "warning"
          : "success";
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

    if (!visible) return;
    ctx.ui.setWidget(
      "dotfiles-info",
      (_tui, theme) => ({
        render(width: number): readonly string[] {
          const layoutRow = (segments: [string, string, string]) => {
            const gutter = Math.min(2, Math.floor(width / 4));
            const contentWidth = width - gutter * 2;
            const leftColumnWidth = Math.floor(contentWidth * 0.25);
            const middleColumnWidth = Math.floor(contentWidth * 0.3);
            const rightColumnWidth =
              contentWidth - leftColumnWidth - middleColumnWidth;
            const [left, middle, right] = segments;
            const leftText = truncateToWidth(left, leftColumnWidth);
            const middleText = truncateToWidth(middle, middleColumnWidth);
            const rightText = truncateToWidth(right, rightColumnWidth);
            const leftPadding =
              leftColumnWidth - visibleWidth(leftText) + gutter;
            const middlePadding =
              middleColumnWidth - visibleWidth(middleText) + gutter;
            const rightPadding = rightColumnWidth - visibleWidth(rightText);

            return `${leftText}${" ".repeat(leftPadding)}${middleText}${" ".repeat(middlePadding)}${rightText}${" ".repeat(rightPadding)}`;
          };
          const context =
            usage && contextPercent !== undefined
              ? `${theme.fg(contextColor, "█".repeat(filled))}${theme.fg("muted", "░".repeat(8 - filled))} ${theme.fg(contextColor, `${contextPercent.toFixed(1)}%`)} ${theme.fg("muted", `· ${compactTokens.format(usage.tokens)}/${compactTokens.format(usage.contextWindow)}`)}`
              : theme.fg("muted", "Unavailable");
          const rows: [string, string, string][] = [
            [
              `${theme.fg("accent", "DOTFILES")} ${theme.fg("success", `OMP ${versionLabel || "unknown version"}`)}`,
              `${theme.fg("accent", "SESSION")} ${theme.fg("text", session)}`,
              `${theme.fg("accent", "PROVIDER")} ${theme.fg("text", provider)} · ${theme.fg("accent", "MODEL")} ${theme.fg("text", model)} ${theme.fg("warning", `· ${thinking}`)}`,
            ],
            [
              `${theme.fg("accent", "PROJECT")} ${theme.fg("text", project)}`,
              `${theme.fg("accent", "GIT")} ${theme.fg(gitColor, git)}`,
              `${theme.fg("accent", "CONTEXT")} ${context}`,
            ],
          ];

          return [
            theme.fg("muted", "─".repeat(width)),
            ...rows.map(layoutRow),
            ...quotaLines.map((segments) =>
              truncateToWidth(
                segments.map(({ text, color }) => theme.fg(color, text)).join(""),
                width,
              ),
            ),
            theme.fg("muted", "─".repeat(width)),
          ];
        },
      }),
      { placement: "belowEditor" },
    );
  }

  async function showWidget(ctx: ExtensionContext) {
    if (!ctx.hasUI) return;
    visible = true;
    await refreshWidget(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    await showWidget(ctx);
    if (ctx.hasUI) {
      ctx.setInterval(async () => {
        if (visible) await refreshWidget(ctx);
      }, 5000);
    }
  });

  pi.registerCommand("dotfiles-info", {
    description: "Toggle the auto-refreshing Dotfiles OMP information widget",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) return;
      if (visible) {
        ctx.ui.setWidget("dotfiles-info", undefined);
        visible = false;
        return;
      }

      await showWidget(ctx);
    },
  });
}
