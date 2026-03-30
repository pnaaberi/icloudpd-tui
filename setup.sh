#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# icloudpd-tui installer
# Detects OS, installs dependencies, clones the repo, and launches.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/pnaaberi/icloudpd-tui/main/setup.sh | bash
#
# Or:
#   wget -qO- https://raw.githubusercontent.com/pnaaberi/icloudpd-tui/main/setup.sh | bash
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

GREEN='\033[38;2;95;138;114m'
BOLD='\033[1m'
DIM='\033[38;2;100;130;115m'
RED='\033[31m'
RESET='\033[0m'

info()  { printf "${GREEN}▸${RESET} %s\n" "$*"; }
err()   { printf "${RED}✗${RESET} %s\n" "$*" >&2; }
step()  { printf "\n${BOLD}%s${RESET}\n" "$*"; }

INSTALL_DIR="${HOME}/.local/share/icloudpd-tui"
BIN_DIR="${HOME}/.local/bin"

# ── Detect OS ─────────────────────────────────────────────────────────────────

OS="unknown"
case "$(uname -s)" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="macos" ;;
esac

if [[ "$OS" == "unknown" ]]; then
    err "Unsupported operating system: $(uname -s)"
    err "icloudpd-tui supports Linux and macOS."
    exit 1
fi

step "Installing icloudpd-tui"
printf "${DIM}Detected: %s${RESET}\n" "$OS"

# ── Install package manager deps ──────────────────────────────────────────────

install_deps() {
    step "Installing dependencies..."

    if [[ "$OS" == "macos" ]]; then
        # Check for Homebrew
        if ! command -v brew &>/dev/null; then
            info "Homebrew not found. Installing..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # Add to PATH for this session
            if [[ -f /opt/homebrew/bin/brew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -f /usr/local/bin/brew ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi
        info "Installing bash, fzf, gawk, pipx..."
        brew install bash fzf gawk pipx 2>/dev/null || brew upgrade bash fzf gawk pipx 2>/dev/null || true

    elif [[ "$OS" == "linux" ]]; then
        if command -v pacman &>/dev/null; then
            info "Installing fzf, gawk (pacman)..."
            sudo pacman -S --needed --noconfirm fzf gawk
        elif command -v apt-get &>/dev/null; then
            info "Installing fzf, gawk (apt)..."
            sudo apt-get update -qq && sudo apt-get install -y -qq fzf gawk
        elif command -v dnf &>/dev/null; then
            info "Installing fzf, gawk (dnf)..."
            sudo dnf install -y fzf gawk
        else
            err "Could not detect package manager (tried pacman, apt, dnf)."
            err "Please install fzf and gawk manually, then re-run this script."
            exit 1
        fi

        # Install pipx if not available
        if ! command -v pipx &>/dev/null; then
            info "Installing pipx..."
            if command -v pacman &>/dev/null; then
                sudo pacman -S --needed --noconfirm python-pipx
            elif command -v apt-get &>/dev/null; then
                sudo apt-get install -y -qq pipx
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y pipx
            else
                python3 -m pip install --user pipx 2>/dev/null || true
            fi
        fi
    fi
}

install_icloudpd() {
    if command -v icloudpd &>/dev/null; then
        info "icloudpd already installed"
    else
        step "Installing icloudpd..."
        if command -v pipx &>/dev/null; then
            pipx install icloudpd
        else
            err "pipx not found. Install icloudpd manually: pipx install icloudpd"
            exit 1
        fi
    fi
}

install_tui() {
    step "Installing icloudpd-tui..."

    if [[ -d "$INSTALL_DIR" ]]; then
        info "Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull --quiet
    else
        info "Cloning repository..."
        git clone --quiet https://github.com/pnaaberi/icloudpd-tui.git "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    chmod +x icloudpd-tui

    # Add to PATH
    mkdir -p "$BIN_DIR"
    ln -sf "$INSTALL_DIR/icloudpd-tui" "$BIN_DIR/icloudpd-tui"

    # Check if BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        info "Adding $BIN_DIR to PATH..."
        local shell_rc=""
        if [[ -f "$HOME/.zshrc" ]]; then
            shell_rc="$HOME/.zshrc"
        elif [[ -f "$HOME/.bashrc" ]]; then
            shell_rc="$HOME/.bashrc"
        elif [[ -f "$HOME/.bash_profile" ]]; then
            shell_rc="$HOME/.bash_profile"
        fi
        if [[ -n "$shell_rc" ]]; then
            if ! grep -q "$BIN_DIR" "$shell_rc" 2>/dev/null; then
                echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$shell_rc"
                info "Added to $shell_rc (restart your shell or run: source $shell_rc)"
            fi
        fi
        export PATH="$BIN_DIR:$PATH"
    fi
}

verify() {
    step "Verifying installation..."
    local ok=true

    for cmd in bash fzf gawk icloudpd icloudpd-tui; do
        if command -v "$cmd" &>/dev/null; then
            printf "  ${GREEN}✓${RESET} %s\n" "$cmd"
        else
            printf "  ${RED}✗${RESET} %s — not found\n" "$cmd"
            ok=false
        fi
    done

    if [[ "$OS" == "macos" ]]; then
        local brew_bash=""
        for p in /opt/homebrew/bin/bash /usr/local/bin/bash; do
            [[ -x "$p" ]] && brew_bash="$p" && break
        done
        if [[ -n "$brew_bash" ]]; then
            local ver
            ver=$("$brew_bash" -c 'echo $BASH_VERSION')
            printf "  ${GREEN}✓${RESET} brew bash: %s\n" "$ver"
        else
            printf "  ${RED}✗${RESET} brew bash — not found\n"
            ok=false
        fi
    fi

    if ! $ok; then
        echo
        err "Some dependencies are missing. Fix the issues above and try again."
        exit 1
    fi
}

# ── Run ───────────────────────────────────────────────────────────────────────

install_deps
install_icloudpd
install_tui
verify

echo
printf "${GREEN}╭─────────────────────────────────────╮${RESET}\n"
printf "${GREEN}│${RESET}${BOLD}  icloudpd-tui installed!            ${RESET}${GREEN}│${RESET}\n"
printf "${GREEN}╰─────────────────────────────────────╯${RESET}\n"
echo
printf "  Run:  ${BOLD}icloudpd-tui${RESET}\n"
echo
printf "${DIM}  Installed to: %s${RESET}\n" "$INSTALL_DIR"
printf "${DIM}  Symlinked:    %s/icloudpd-tui${RESET}\n" "$BIN_DIR"
echo

# Ask to launch
read -rp "  Launch now? [Y/n] " launch
case "$launch" in
    [nN]*) ;;
    *) exec icloudpd-tui ;;
esac
