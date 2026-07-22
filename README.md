# oh-my-zsh-starship-terminal

End-to-end installer that sets up a Zsh terminal with Oh My Zsh, autosuggestions,
syntax highlighting, and the Starship prompt using a custom config.

## What it does

1. Installs `zsh` (via `apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, or `brew`,
   whichever is detected).
2. Installs [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) unattended.
3. Installs and enables plugins:
   - [`zsh-autosuggestions`](https://github.com/zsh-users/zsh-autosuggestions)
   - [`zsh-syntax-highlighting`](https://github.com/zsh-users/zsh-syntax-highlighting)
4. Installs [Starship](https://starship.rs/) and wires up `eval "$(starship init zsh)"`
   in `~/.zshrc`.
5. Downloads a custom `starship.toml` to `~/.config/starship.toml` from:
   `https://gist.githubusercontent.com/rifkhan107/a49706cb2e69ac0e467a585278a23d99/raw/666e5238c043a6eba8406715b36bbf70ddd9f912/ubuntu-starship.toml`
6. Overrides `LS_COLORS` so world-writable directories (`chmod 777`) render as
   plain bold blue instead of the default hard-to-read blue-on-green.
7. Sets `zsh` as the default login shell.

Every step is idempotent (safe to re-run) and backs up existing `.zshrc` /
`starship.toml` files before overwriting them.

## Usage

```bash
git clone <this-repo>
cd oh-my-zsh-starship-terminal
./install.sh
```

Or run it directly:

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/oh-my-zsh-starship-terminal/main/install.sh | bash
```

## Options (environment variables)

| Variable       | Default | Description                                   |
|----------------|---------|------------------------------------------------|
| `SKIP_CHSH`    | `false` | Set to `true` to skip changing the default shell |

## Requirements

- A [Nerd Font](https://www.nerdfonts.com/) installed and enabled in your
  terminal, so Starship's icons render correctly.
- `curl` and `git` (curl is auto-installed if missing on apt-based systems).

## After install

Restart your terminal, or run:

```bash
exec zsh
```
