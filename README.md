```
  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
```

Personal macOS developer environment setup — by Noofreuuuh

## What gets installed

| Component | Description |
|-----------|-------------|
| [Homebrew](https://brew.sh/) | Package manager |
| [Git](https://git-scm.com/) | Version control — prompts for username & email |
| [Zsh + Oh My Zsh](https://ohmyz.sh/) | Shell + PowerLevel10k theme, plugins, aliases |
| [ASDF](https://asdf-vm.com/) | Runtime version manager — Node.js, pnpm, Python, Java |

Optional software bundles selectable from the interactive menu: Development, Tools, Communication, Office, Games, Others, LLM Tools, Pro Bundle.

## Usage

### One-liner (new machine)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/noofreuuuh/Dotfiles/main/bootstrap.sh)"
```

The script will ask where to clone the repo, then launch the interactive setup.

### Manual

```bash
git clone https://github.com/noofreuuuh/Dotfiles.git ~/Dotfiles
cd ~/Dotfiles
bash main.sh
```

### CLI flags

```bash
bash main.sh --dry-run              # Simulate without installing anything
bash main.sh --doctor               # Check environment health
bash main.sh --profile=core         # Install Brew + Git + Zsh + ASDF
bash main.sh --profile=dev          # core + Development bundle
bash main.sh --brew --zsh --asdf    # Pick individual components
```

## Repository structure

```
bootstrap.sh                  # One-liner entry point
main.sh                       # Orchestration + interactive menu
lib/
├── colors.sh                 # Colors, log helpers, progress bar
├── ui.sh                     # Banner, prerequisites check, summary
├── doctor.sh                 # Environment health check (--doctor)
├── install_core.sh           # Brew, Git, Zsh, ASDF
├── install_software.sh       # Software bundles
└── prompt_for_multiselect.sh # Interactive checkbox menu
config/
├── zsh/                      # Zsh config (preload, postload, aliases, p10k)
├── asdf/                     # tool-versions
└── nvim/                     # Neovim config
tests/                        # Bats test suite
```

## Zsh architecture

After install, `~/.zshrc` contains two injected blocks:

- **pre-omz** — sources `~/.zsh_preload.zsh` (theme, plugins) before Oh My Zsh loads
- **post-omz** — sources `~/.zsh_postload.zsh` (PATH, aliases, tools) at end of file

Personal overrides go in `~/.zsh_custom.zsh` — created once on first install, never overwritten.
