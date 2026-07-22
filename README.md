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

## Windows (PowerShell)

`install.sh` is Zsh/Oh My Zsh specific and doesn't apply to native Windows
PowerShell. `install.ps1` sets up the closest equivalents instead:

- [Starship](https://starship.rs/) prompt, using the same custom
  `starship.toml` (with the same bundled offline fallback). Tries `winget`
  in per-user scope first; if that's unavailable or needs admin rights you
  don't have (no UAC password, etc.), it falls back to downloading the
  official binary directly from GitHub releases into
  `%LOCALAPPDATA%\Programs\starship` and adding that folder to your **user**
  PATH — no admin rights or UAC prompt required either way.
- [PSReadLine](https://learn.microsoft.com/powershell/module/psreadline/)
  configured with predictive IntelliSense (history-based autosuggestions —
  the PowerShell analogue of `zsh-autosuggestions`) and colorized tokens
  (the analogue of `zsh-syntax-highlighting`).
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons) for file
  and folder icons in `Get-ChildItem` output. The `windows` well-known folder
  icon is overridden from the default `nf-fa-windows` to `nf-custom-windows`
  (`U+E62A`) via a generated custom icon theme — the vendor module files are
  never modified directly.

```powershell
git clone <this-repo>
cd oh-my-zsh-starship-terminal
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Every step is idempotent and backs up an existing `starship.toml` before
overwriting it. Requires PowerShell 5.1+. `winget` is used opportunistically
if present, but nothing in this script requires it or admin rights.

Restart your terminal, or run `. $PROFILE`, afterwards.
