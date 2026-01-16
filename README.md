# dotfiles

Personal dotfiles managed with [dotbot](https://github.com/anishathalye/dotbot).

## Installation

1. Clone the repository:
```bash
git clone https://github.com/ashneyderman/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

2. Run the installation script:
```bash
./install
```

The installation script will:
- Initialize and update the dotbot submodule
- Create symbolic links for configuration files and directories
- Link shell configurations (zsh, aliases, functions)
- Link application configs (nvim, tmux, wezterm, alacritty, starship)
- Link utility scripts in `~/bin`

## What gets linked

The installation creates symlinks from this repository to your home directory:
- Shell: `~/.zshrc`, `~/.aliases`, `~/.functions.sh`, `~/.sshagent`
- Neovim: `~/.config/nvim`
- Terminal: `~/.config/tmux`, `~/.config/wezterm`, `~/.config/alacritty`
- Other: `~/.config/starship`, `~/bin`
- macOS: `~/.aerospace.toml` (Darwin only)
