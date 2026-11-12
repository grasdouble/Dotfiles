import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

type PresetConfig = {
  modelRoles?: Record<string, string>;
  defaultThinkingLevel?: string;
};

type ActiveConfig = {
  modelRoles?: Record<string, string>;
  modelPresets?: Record<string, PresetConfig>;
  defaultThinkingLevel?: string;
};

type RunCommand = (
  command: string,
  args: string[],
  cwd: string,
) => Promise<string | undefined>;

export function createPresetTracker(
  pi: Pick<ExtensionAPI, "getThinkingLevel">,
  run: RunCommand,
) {
  let label = "Unknown";
  let config: ActiveConfig | undefined;

  function identifyConfiguredPreset(activeConfig: ActiveConfig): string {
    const roles = activeConfig.modelRoles;
    const presets = activeConfig.modelPresets;
    if (!roles || !presets) return "Unknown";

    const matches = Object.entries(presets).filter(([, preset]) => {
      const presetRoles = preset.modelRoles;
      if (!presetRoles) return false;
      if (!Object.entries(presetRoles).every(([role, model]) => roles[role] === model)) return false;
      return !preset.defaultThinkingLevel || preset.defaultThinkingLevel === activeConfig.defaultThinkingLevel;
    });
    return matches.length === 1 ? matches[0][0] : "Custom";
  }

  async function refresh(ctx: ExtensionContext): Promise<void> {
    const [rolesOutput, presetsOutput, thinkingOutput] = await Promise.all([
      run("omp", ["config", "get", "modelRoles", "--json"], ctx.cwd),
      run("omp", ["config", "get", "modelPresets", "--json"], ctx.cwd),
      run("omp", ["config", "get", "defaultThinkingLevel", "--json"], ctx.cwd),
    ]);
    try {
      if (!rolesOutput || !presetsOutput || !thinkingOutput) throw new Error("Missing OMP configuration");
      const roles = JSON.parse(rolesOutput) as { value?: Record<string, string> };
      const presets = JSON.parse(presetsOutput) as { value?: Record<string, PresetConfig> };
      const thinking = JSON.parse(thinkingOutput) as { value?: string };
      config = {
        modelRoles: roles.value,
        modelPresets: presets.value,
        defaultThinkingLevel: thinking.value,
      };
      label = identifyConfiguredPreset(config);
    } catch {
      config = undefined;
      label = "Unknown";
    }
  }

  function select(name: string): void {
    label = config?.modelPresets?.[name] ? name : "Unknown";
  }

  function syncFromRuntime(ctx: ExtensionContext): boolean {
    const model = ctx.model;
    if (!model?.provider || !model.id) return false;
    const activeSelector = `${model.provider}/${model.id}`.toLowerCase();
    const thinking = pi.getThinkingLevel();
    const matches = Object.entries(config?.modelPresets ?? {}).filter(([, preset]) => {
      const selector = (preset.modelRoles?.default ?? "")
        .replace(/:(?:off|minimal|low|medium|high|max|xhigh|auto)$/i, "")
        .toLowerCase();
      return selector === activeSelector &&
        (!preset.defaultThinkingLevel || !thinking || preset.defaultThinkingLevel === thinking);
    });
    label = matches.length === 1 ? matches[0][0] : "Custom";
    return true;
  }

  function watchSelection(
    ctx: ExtensionContext,
    isVisible: () => boolean,
    onChange: () => void,
    initialState: string,
    attempts = 150,
  ): void {
    if (!isVisible() || attempts === 0) return;
    ctx.setTimeout(() => {
      const model = ctx.model;
      const state = `${model?.provider ?? ""}/${model?.id ?? ""}:${pi.getThinkingLevel() ?? ""}`;
      if (state !== initialState && syncFromRuntime(ctx)) {
        onChange();
        return;
      }
      watchSelection(ctx, isVisible, onChange, initialState, attempts - 1);
    }, 200);
  }

  function watchCurrentSelection(
    ctx: ExtensionContext,
    isVisible: () => boolean,
    onChange: () => void,
  ): void {
    const model = ctx.model;
    const initialState = `${model?.provider ?? ""}/${model?.id ?? ""}:${pi.getThinkingLevel() ?? ""}`;
    watchSelection(ctx, isVisible, onChange, initialState);
  }

  return {
    get label() {
      return label;
    },
    get modelRoles() {
      return config?.modelPresets?.[label]?.modelRoles;
    },
    refresh,
    select,
    syncFromRuntime,
    watchCurrentSelection,
  };
}
