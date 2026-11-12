import { truncateToWidth, visibleWidth } from "@oh-my-pi/pi-tui";
import type { ExtensionContext } from "@oh-my-pi/pi-coding-agent";

export type WidgetColor = "accent" | "error" | "muted" | "success" | "warning";

export type WidgetData = {
  version: string;
  session: string;
  preset: string;
  vibeModels: { default?: string; fast?: string; good?: string } | undefined;
  project: string;
  git: string;
  gitColor: WidgetColor;
  usage: { tokens: number; contextWindow: number } | undefined;
  contextPercent: number | undefined;
  filled: number;
  contextColor: WidgetColor;
  quotaLines: { text: string; color: WidgetColor }[][];
};

export function mountWidget(
  ctx: ExtensionContext,
  getData: () => WidgetData | undefined,
  onRenderChange: (requestRender: (() => void) | undefined) => void,
): void {
  if (!ctx.hasUI) return;
  const compactTokens = new Intl.NumberFormat(undefined, {
    notation: "compact",
    maximumFractionDigits: 1,
  });

  ctx.ui.setWidget("dotfiles-info", (tui, theme) => {
    onRenderChange(() => tui.requestRender());
    return {
      render(width: number): readonly string[] {
        const data = getData();
        if (!data) return [];

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
          const leftPadding = leftColumnWidth - visibleWidth(leftText) + gutter;
          const middlePadding = middleColumnWidth - visibleWidth(middleText) + gutter;
          const rightPadding = rightColumnWidth - visibleWidth(rightText);
          return `${leftText}${" ".repeat(leftPadding)}${middleText}${" ".repeat(middlePadding)}${rightText}${" ".repeat(rightPadding)}`;
        };
        const formatRoleModel = (label: string, model: string | undefined) => {
          const value = model ?? "Unavailable";
          const match = value.match(/^(.*?)(:(?:off|minimal|low|medium|high|max|xhigh|auto))$/i);
          const formattedModel = match
            ? `${theme.fg("text", match[1])}${theme.fg("warning", match[2])}`
            : theme.fg("text", value);
          return `${theme.fg("accent", label)} ${formattedModel}`;
        };
        const context =
          data.usage && data.contextPercent !== undefined
            ? `${theme.fg(data.contextColor, "█".repeat(data.filled))}${theme.fg("muted", "░".repeat(8 - data.filled))} ${theme.fg(data.contextColor, `${data.contextPercent.toFixed(1)}%`)} ${theme.fg("muted", `· ${compactTokens.format(data.usage.tokens)}/${compactTokens.format(data.usage.contextWindow)}`)}`
            : theme.fg("muted", "Unavailable");
        const rows: [string, string, string][] = [
          [
            `${theme.fg("accent", "DOTFILES")} ${theme.fg("success", `OMP ${data.version}`)}`,
            `${theme.fg("accent", "SESSION")} ${theme.fg("text", data.session)}`,
            `${theme.fg("accent", "PRESET")} ${theme.fg("text", data.preset)}`,
          ],
          [
            `${theme.fg("accent", "PROJECT")} ${theme.fg("text", data.project)}`,
            `${theme.fg("accent", "GIT")} ${theme.fg(data.gitColor, data.git)}`,
            `${theme.fg("accent", "CONTEXT")} ${context}`,
          ],
        ];

        return [
          theme.fg("muted", "─".repeat(width)),
          ...rows.slice(0, 1).map(layoutRow),
          layoutRow(
            data.vibeModels
              ? [
                  formatRoleModel("DEFAULT", data.vibeModels.default),
                  formatRoleModel("FAST", data.vibeModels.fast),
                  formatRoleModel("GOOD", data.vibeModels.good),
                ]
              : [theme.fg("muted", "Unavailable"), "", ""],
          ),
          ...rows.slice(1).map(layoutRow),
          ...data.quotaLines.map((segments) =>
            truncateToWidth(
              segments.map(({ text, color }) => theme.fg(color, text)).join(""),
              width,
            ),
          ),
          theme.fg("muted", "─".repeat(width)),
        ];
      },
      dispose() {
        onRenderChange(undefined);
      },
    };
  }, { placement: "aboveEditor" });
}
