#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# icloudpd-tui installer
# Detects OS, installs dependencies, clones the repo, and launches.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/pnaaberi/icloudpd-tui/main/setup.sh | bash
# ─────────────────────────────────────────────────────────────────────────────

# When piped from curl, re-exec from a temp file so subcommands
# don't consume stdin (which is the script itself).
if [[ ! -t 0 && "${_SETUP_REEXEC:-}" != "1" ]]; then
    tmp=$(mktemp /tmp/icloudpd-tui-setup.XXXXXX)
    cat > "$tmp"
    chmod +x "$tmp"
    _SETUP_REEXEC=1 exec bash "$tmp" "$@"
fi

set -euo pipefail

G='\033[38;2;95;138;114m'
B='\033[1m'
W='\033[1;37m'
D='\033[38;2;100;130;115m'
RED='\033[31m'
R='\033[0m'

info()  { printf "${G}▸${R} %s\n" "$*"; }
err()   { printf "${RED}✗${R} %s\n" "$*" >&2; }
step()  { printf "\n${G}━━ %s${R}\n\n" "$*"; }
ok()    { printf "  ${G}✓${R} %s\n" "$*"; }
skip()  { printf "  ${D}– %s (already installed)${R}\n" "$*"; }

INSTALL_DIR="${HOME}/.local/share/icloudpd-tui"
BIN_DIR="${HOME}/.local/bin"
LOG_FILE="/tmp/icloudpd-tui-setup.log"

# ── Spinner ───────────────────────────────────────────────────────────────────
# Run a command in background with animated spinner + live log tail

run_with_spinner() {
    local msg="$1"; shift
    local log="$LOG_FILE"
    > "$log"

    "$@" >> "$log" 2>&1 &
    local pid=$!

    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0 last_line=""
    local start_ts
    start_ts=$(date +%s)

    tput civis 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        local now_ts elapsed_s elapsed_fmt
        now_ts=$(date +%s)
        elapsed_s=$(( now_ts - start_ts ))
        if (( elapsed_s >= 60 )); then
            elapsed_fmt="$(( elapsed_s / 60 ))m$(( elapsed_s % 60 ))s"
        else
            elapsed_fmt="${elapsed_s}s"
        fi

        last_line=$(tail -1 "$log" 2>/dev/null | cut -c1-50) || last_line=""
        # Clean up common brew/apt noise
        last_line=$(echo "$last_line" | sed 's/==> //; s/^  //; s/Fetching/Downloading/; s/Pouring/Installing/')

        printf '\r\033[K  %b%s%b %s %b[%s]%b  %b%s%b' \
            "$G" "${frames:i%${#frames}:1}" "$R" \
            "$msg" \
            "$D" "$elapsed_fmt" "$R" \
            "$D" "$last_line" "$R"
        i=$((i + 1))
        sleep 0.08
    done

    wait "$pid" 2>/dev/null
    local rc=$?

    printf '\r\033[K'
    tput cnorm 2>/dev/null || true

    if (( rc == 0 )); then
        ok "$msg"
    else
        err "$msg — failed (see $LOG_FILE)"
        printf "\n${D}  Last lines from log:${R}\n"
        tail -5 "$log" | sed 's/^/  /'
        echo
    fi

    return $rc
}

# ── Detect OS ─────────────────────────────────────────────────────────────────

OS="unknown"
case "$(uname -s)" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="macos" ;;
esac

if [[ "$OS" == "unknown" ]]; then
    err "Unsupported OS: $(uname -s). Supports Linux and macOS."
    exit 1
fi

# ── Banner ────────────────────────────────────────────────────────────────────

echo
printf "${G}  ╭─────────────────────────────────╮${R}\n"
printf "${G}  │${R}${B}  icloudpd-tui installer         ${R}${G}│${R}\n"
printf "${G}  ╰─────────────────────────────────╯${R}\n"
printf "${D}  Detected: %s${R}\n" "$OS"
echo

# ── Install deps ──────────────────────────────────────────────────────────────

step "Installing dependencies"

if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &>/dev/null; then
        info "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        skip "Homebrew"
    fi

    for pkg in bash fzf gawk pipx; do
        if brew list "$pkg" &>/dev/null; then
            skip "$pkg"
        else
            run_with_spinner "Installing $pkg" brew install "$pkg"
        fi
    done

elif [[ "$OS" == "linux" ]]; then
    if command -v pacman &>/dev/null; then
        for pkg in fzf gawk; do
            if pacman -Qi "$pkg" &>/dev/null 2>&1; then
                skip "$pkg"
            else
                run_with_spinner "Installing $pkg" sudo pacman -S --needed --noconfirm "$pkg"
            fi
        done
    elif command -v apt-get &>/dev/null; then
        run_with_spinner "Updating package list" sudo apt-get update -qq
        for pkg in fzf gawk; do
            if dpkg -s "$pkg" &>/dev/null 2>&1; then
                skip "$pkg"
            else
                run_with_spinner "Installing $pkg" sudo apt-get install -y -qq "$pkg"
            fi
        done
    elif command -v dnf &>/dev/null; then
        for pkg in fzf gawk; do
            if rpm -q "$pkg" &>/dev/null 2>&1; then
                skip "$pkg"
            else
                run_with_spinner "Installing $pkg" sudo dnf install -y "$pkg"
            fi
        done
    else
        err "No supported package manager found (pacman, apt, dnf)."
        err "Install fzf and gawk manually, then re-run."
        exit 1
    fi

    if ! command -v pipx &>/dev/null; then
        if command -v pacman &>/dev/null; then
            run_with_spinner "Installing pipx" sudo pacman -S --needed --noconfirm python-pipx
        elif command -v apt-get &>/dev/null; then
            run_with_spinner "Installing pipx" sudo apt-get install -y -qq pipx
        elif command -v dnf &>/dev/null; then
            run_with_spinner "Installing pipx" sudo dnf install -y pipx
        else
            run_with_spinner "Installing pipx" python3 -m pip install --user pipx
        fi
    else
        skip "pipx"
    fi
fi

# ── Install icloudpd ─────────────────────────────────────────────────────────

step "Installing icloudpd"

if command -v icloudpd &>/dev/null; then
    skip "icloudpd"
else
    run_with_spinner "Installing icloudpd (this may take a minute)" pipx install icloudpd
fi

# ── Install icloudpd-tui ─────────────────────────────────────────────────────

step "Installing icloudpd-tui"

if [[ -d "$INSTALL_DIR" ]]; then
    run_with_spinner "Updating icloudpd-tui" git -C "$INSTALL_DIR" pull --quiet
else
    run_with_spinner "Cloning icloudpd-tui" git clone --quiet https://github.com/pnaaberi/icloudpd-tui.git "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/icloudpd-tui"

mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/icloudpd-tui" "$BIN_DIR/icloudpd-tui"
ok "Symlinked to $BIN_DIR/icloudpd-tui"

# Add to PATH if needed
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    local_rc=""
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
        [[ -f "$rc" ]] && local_rc="$rc" && break
    done
    if [[ -n "$local_rc" ]] && ! grep -q "$BIN_DIR" "$local_rc" 2>/dev/null; then
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$local_rc"
        info "Added $BIN_DIR to PATH in $local_rc"
    fi
    export PATH="$BIN_DIR:$PATH"
fi

# ── Verify ────────────────────────────────────────────────────────────────────

step "Verifying installation"

all_ok=true
for cmd in fzf gawk icloudpd icloudpd-tui; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd"
    else
        printf "  ${RED}✗${R} %s — not found\n" "$cmd"
        all_ok=false
    fi
done

if [[ "$OS" == "macos" ]]; then
    brew_bash=""
    for p in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ -x "$p" ]] && brew_bash="$p" && break
    done
    if [[ -n "$brew_bash" ]]; then
        ok "bash 4+ ($("$brew_bash" -c 'echo $BASH_VERSION'))"
    else
        printf "  ${RED}✗${R} bash 4+ — not found\n"
        all_ok=false
    fi
fi

if ! $all_ok; then
    echo
    err "Some dependencies are missing. Fix the issues above and try again."
    exit 1
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo
printf "${G}  ╭─────────────────────────────────╮${R}\n"
printf "${G}  │${R}${W}  Installation complete!          ${R}${G}│${R}\n"
printf "${G}  ╰─────────────────────────────────╯${R}\n"
echo
printf "  Run:  ${B}icloudpd-tui${R}\n"
echo
printf "${D}  Installed to: %s${R}\n" "$INSTALL_DIR"
printf "${D}  Binary:       %s/icloudpd-tui${R}\n" "$BIN_DIR"
echo

printf "  To start, run:\n\n"
printf "    ${B}icloudpd-tui${R}\n\n"
