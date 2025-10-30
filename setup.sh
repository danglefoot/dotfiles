#!/bin/bash

# ============================================================================
# Dotfiles Setup Script (Cross-Platform)
# ============================================================================
# This script sets up symlinks for configurations across macOS, Linux, Windows
# - macOS/Linux: Uses GNU stow for most configs
# - Windows: Uses manual symlinks (stow often unavailable)
# ============================================================================

set -e  # Exit on error

DOTFILES_DIR="$HOME/.dotfiles"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WSL_DISTRO_NAME" ]]; then
    OS="windows"
else
    OS="unknown"
fi

echo "🚀 Setting up dotfiles for $OS..."

# ============================================================================
# Helper Functions
# ============================================================================

create_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"

    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        echo "  ✓ $name already symlinked"
    elif [ -f "$target" ]; then
        echo "  ⚠️  Backing up existing $name to ${name}.backup"
        mv "$target" "${target}.backup"
        ln -sf "$source" "$target"
        echo "  ✓ $name symlinked"
    else
        ln -sf "$source" "$target"
        echo "  ✓ $name symlinked"
    fi
}

# ============================================================================
# VSCode Configuration
# ============================================================================
echo ""
echo "📝 Setting up VSCode configuration..."

case "$OS" in
    macos)
        VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
        ;;
    linux)
        VSCODE_USER_DIR="$HOME/.config/Code/User"
        ;;
    windows)
        # WSL/MSYS2/Cygwin can access Windows paths
        if [[ -n "$WSL_DISTRO_NAME" ]]; then
            # WSL: Access Windows AppData
            WIN_USERNAME=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
            VSCODE_USER_DIR="/mnt/c/Users/$WIN_USERNAME/AppData/Roaming/Code/User"
        elif [[ -n "$APPDATA" ]]; then
            # MSYS2/Cygwin: Use APPDATA environment variable
            VSCODE_USER_DIR="$APPDATA/Code/User"
        else
            echo "  ⚠️  Could not determine VSCode path on Windows"
            VSCODE_USER_DIR=""
        fi
        ;;
esac

if [ -n "$VSCODE_USER_DIR" ]; then
    create_symlink "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json" "keybindings.json"

    if [ -f "$DOTFILES_DIR/vscode/settings.json" ]; then
        create_symlink "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_USER_DIR/settings.json" "settings.json"
    fi
fi

# ============================================================================
# Windows Manual Symlinks (stow not reliable on Windows)
# ============================================================================
if [ "$OS" == "windows" ]; then
    echo ""
    echo "📝 Setting up Windows configurations (manual symlinks)..."

    # VsVim (uses _vsvimrc with underscore on Windows)
    create_symlink "$DOTFILES_DIR/vsvimrc/.vsvimrc" "$HOME/_vsvimrc" "_vsvimrc"

    # IdeaVim
    create_symlink "$DOTFILES_DIR/ideavimrc/.ideavimrc" "$HOME/.ideavimrc" ".ideavimrc"

    # Neovim
    create_symlink "$DOTFILES_DIR/nvim/.config/nvim" "$HOME/.config/nvim" "nvim"

    # Tmux (only if WSL - tmux doesn't work on native Windows)
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        create_symlink "$DOTFILES_DIR/tmux/.config/tmux" "$HOME/.config/tmux" "tmux"
    else
        echo "  ⏭️  Skipping tmux (not available on native Windows)"
    fi

# ============================================================================
# macOS/Linux: Use GNU Stow
# ============================================================================
else
    echo ""
    echo "📦 Setting up stow packages..."

    # Check if stow is installed
    if ! command -v stow &> /dev/null; then
        echo "  ⚠️  GNU stow not found."
        case "$OS" in
            macos)
                echo "      Install with: brew install stow"
                ;;
            linux)
                echo "      Install with: sudo apt install stow  (or your package manager)"
                ;;
        esac
        echo "  ⏭️  Skipping stow packages"
    else
        cd "$DOTFILES_DIR"

        # Stow Neovim
        if [ -d "nvim" ]; then
            stow -R nvim
            echo "  ✓ Neovim configuration stowed"
        fi

        # Stow tmux
        if [ -d "tmux" ]; then
            stow -R tmux
            echo "  ✓ Tmux configuration stowed"
        fi

        # Stow IdeaVim
        if [ -d "ideavimrc" ]; then
            stow -R ideavimrc
            echo "  ✓ IdeaVim configuration stowed"
        fi

        # Stow VsVim
        if [ -d "vsvimrc" ]; then
            stow -R vsvimrc
            echo "  ✓ VsVim configuration stowed"
        fi

        cd - > /dev/null
    fi
fi

# ============================================================================
# Done
# ============================================================================
echo ""
echo "✅ Dotfiles setup complete!"
echo ""
echo "Configurations installed:"
echo "  - VSCode: Symlinked from ~/.dotfiles/vscode/"
if [ "$OS" == "windows" ]; then
    echo "  - VsVim: Symlinked to ~/_vsvimrc (Windows uses underscore prefix)"
    echo "  - IdeaVim: Symlinked to ~/.ideavimrc"
    echo "  - Neovim: Symlinked to ~/.config/nvim"
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        echo "  - Tmux: Symlinked to ~/.config/tmux"
    fi
else
    echo "  - VsVim: Managed by stow"
    echo "  - IdeaVim: Managed by stow"
    echo "  - Neovim: Managed by stow"
    echo "  - Tmux: Managed by stow"
fi
echo ""
