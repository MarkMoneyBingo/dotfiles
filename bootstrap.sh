#!/bin/bash
# =============================================================================
# Instance Bootstrap Script
# Run on a fresh Ubuntu instance to set up everything from scratch.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/YOUR_REPO/bootstrap.sh | bash
#   OR
#   scp bootstrap.sh ubuntu@your-host:~ && ssh ubuntu@your-host "bash bootstrap.sh"
# =============================================================================

set -e

echo "============================================"
echo "  Instance Bootstrap - Starting Setup"
echo "============================================"

# -------------------------------------------
# 1. System updates
# -------------------------------------------
echo "[1/14] Updating system packages..."
sudo apt update && sudo apt upgrade -y

# -------------------------------------------
# 2. Essential packages
# -------------------------------------------
echo "[2/14] Installing essential packages..."
sudo apt install -y \
    git \
    curl \
    wget \
    unzip \
    htop \
    jq \
    tree \
    ncdu \
    tmux \
    rsync \
    build-essential \
    software-properties-common

# -------------------------------------------
# 3. GitHub CLI (gh)
# -------------------------------------------
echo "[3/14] Installing GitHub CLI..."
if ! command -v gh &> /dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
    echo "GitHub CLI installed. Run 'gh auth login' to authenticate."
else
    echo "GitHub CLI already installed, skipping."
fi

# -------------------------------------------
# 4. Security - fail2ban
# -------------------------------------------
echo "[4/14] Installing fail2ban..."
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# -------------------------------------------
# 4. Security - unattended upgrades
# -------------------------------------------
echo "[5/14] Setting up unattended security upgrades..."
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# -------------------------------------------
# 5. AWS CLI
# -------------------------------------------
echo "[6/14] Installing AWS CLI..."
if ! command -v aws &> /dev/null; then
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    echo "AWS CLI installed."
else
    echo "AWS CLI already installed, skipping."
fi

# -------------------------------------------
# 6. Docker
# -------------------------------------------
echo "[7/14] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker ubuntu
    echo "Docker installed. Log out and back in for group changes to take effect."
else
    echo "Docker already installed, skipping."
fi

# -------------------------------------------
# 7. Tailscale
# -------------------------------------------
echo "[8/14] Installing Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "Tailscale installed. Run 'sudo tailscale up' to connect."
else
    echo "Tailscale already installed, skipping."
fi

# -------------------------------------------
# 8. Node.js via nvm
# -------------------------------------------
echo "[9/14] Installing Node.js via nvm..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts
    echo "Node.js LTS installed."
else
    echo "nvm already installed, skipping."
fi

# -------------------------------------------
# 8. Python - pyenv and venv
# -------------------------------------------
echo "[10/14] Installing pyenv..."
if [ ! -d "$HOME/.pyenv" ]; then
    sudo apt install -y \
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
        libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

    curl https://pyenv.run | bash

    # Add pyenv to current session
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # Install latest Python 3
    LATEST_PY=$(pyenv install --list | grep -E "^\s+3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')
    pyenv install "$LATEST_PY"
    pyenv global "$LATEST_PY"
    echo "Python $LATEST_PY installed via pyenv."
else
    echo "pyenv already installed, skipping."
fi

# -------------------------------------------
# 9. Zsh + Oh My Zsh + Powerlevel10k
# -------------------------------------------
echo "[11/14] Installing zsh and oh-my-zsh..."
sudo apt install -y zsh

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    # Install oh-my-zsh non-interactively
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    # Install Powerlevel10k theme
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

    # Install plugins
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

    git clone https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    # Configure .zshrc
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    sed -i 's/plugins=(git)/plugins=(git z sudo zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc

    # Add pyenv to .zshrc
    cat >> ~/.zshrc << 'EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Disable AWS CLI pager
export AWS_PAGER=""
EOF

    echo "Zsh configured."
else
    echo "Oh My Zsh already installed, skipping."
fi

# Set zsh as default shell
sudo chsh -s $(which zsh) ubuntu

# -------------------------------------------
# 10. Tmux config
# -------------------------------------------
echo "[12/14] Setting up tmux config..."
cat > ~/.tmux.conf << 'EOF'
# Better prefix key (Ctrl+a instead of Ctrl+b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Mouse support
set -g mouse on

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Easy split panes
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Easy pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Increase scrollback
set -g history-limit 50000

# Faster key repetition
set -s escape-time 0

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Status bar
set -g status-style bg=black,fg=white
set -g status-left '[#S] '
set -g status-right '%H:%M %d-%b'
EOF

echo "Tmux configured."

# -------------------------------------------
# 12/13. Login welcome message
# -------------------------------------------
echo "[13/14] Setting up login welcome message..."
sudo tee /etc/update-motd.d/99-instance-info > /dev/null << 'MOTDEOF'
#!/bin/bash
echo ""
echo "============================================"
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "unknown")
echo "  Instance: $INSTANCE_ID ($INSTANCE_TYPE)"
echo "  Region:   $REGION"
echo "  Uptime:  $(uptime -p)"
echo "  Memory:  $(free -h | awk '/Mem:/ {printf "%s / %s (%.0f%%)", $3, $2, $3/$2*100}')"
echo "  Disk:    $(df -h / | awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}')"
echo "============================================"
echo ""
MOTDEOF
sudo chmod +x /etc/update-motd.d/99-instance-info

# -------------------------------------------
# 13/13. Auto-stop idle script
# -------------------------------------------
echo "[14/14] Setting up auto-stop on idle..."
sudo tee /opt/auto-stop.sh > /dev/null << 'EOF'
#!/bin/bash
# Auto-stop instance if no SSH sessions for 30 minutes

IDLE_FILE="/tmp/last-active"

# Check for active SSH sessions
ACTIVE=$(who | grep -c "pts/" 2>/dev/null || echo "0")

if [ "$ACTIVE" -gt 0 ]; then
    # Someone is connected, update the timestamp
    date +%s > "$IDLE_FILE"
else
    # No one connected - check how long it's been
    if [ ! -f "$IDLE_FILE" ]; then
        date +%s > "$IDLE_FILE"
        exit 0
    fi

    LAST_ACTIVE=$(cat "$IDLE_FILE")
    NOW=$(date +%s)
    IDLE_SECONDS=$((NOW - LAST_ACTIVE))

    # 1800 seconds = 30 minutes
    if [ "$IDLE_SECONDS" -ge 1800 ]; then
        sudo shutdown -h now
    fi
fi
EOF

sudo chmod +x /opt/auto-stop.sh
date +%s | sudo tee /tmp/last-active > /dev/null

# Add to root crontab if not already there
(sudo crontab -l 2>/dev/null | grep -v "auto-stop" ; echo "*/5 * * * * /opt/auto-stop.sh") | sudo crontab -

echo ""
echo "============================================"
echo "  Bootstrap Complete!"
echo "============================================"
echo ""
echo "What was set up:"
echo "  - System packages (htop, jq, tree, ncdu, tmux, rsync)"
echo "  - GitHub CLI (gh)"
echo "  - fail2ban (SSH brute force protection)"
echo "  - Unattended security upgrades"
echo "  - AWS CLI"
echo "  - Tailscale"
echo "  - Docker"
echo "  - Node.js LTS (via nvm)"
echo "  - Python (via pyenv)"
echo "  - Zsh + Oh My Zsh + Powerlevel10k"
echo "  - Tmux with sensible defaults"
echo "  - Login welcome message (instance info, memory, disk)"
echo "  - Auto-stop after 30 min idle"
echo ""

# =============================================================================
# Interactive setup
# =============================================================================

# -------------------------------------------
# Tailscale
# -------------------------------------------
echo "============================================"
echo "  Tailscale Setup"
echo "============================================"
echo ""
read -p "Connect to Tailscale now? (y/n): " SETUP_TS

if [ "$SETUP_TS" = "y" ] || [ "$SETUP_TS" = "Y" ]; then
    sudo tailscale up
    echo "Tailscale connected."
else
    echo "Skipped. Run 'sudo tailscale up' later."
fi

# -------------------------------------------
# Timezone
# -------------------------------------------
echo "============================================"
echo "  Timezone Setup"
echo "============================================"
echo ""
echo "Current timezone: $(timedatectl show --property=Timezone --value)"
echo ""
echo "Common options:"
echo "  Asia/Manila"
echo "  US/Eastern"
echo "  US/Pacific"
echo "  UTC"
echo ""
read -p "Set timezone (or press Enter to skip): " TZ_CHOICE

if [ -n "$TZ_CHOICE" ]; then
    sudo timedatectl set-timezone "$TZ_CHOICE"
    echo "Timezone set to $TZ_CHOICE"
else
    echo "Skipped, staying on UTC."
fi

# -------------------------------------------
# Fonts
# -------------------------------------------
# JetBrains Mono
sudo apt install fonts-jetbrains-mono
# Hack
sudo apt install fonts-hack
# Fira Code
sudo apt install fonts-firacode

# -------------------------------------------
# AWS CLI config
# -------------------------------------------
echo ""
echo "============================================"
echo "  AWS CLI Setup"
echo "============================================"
echo ""
read -p "Configure AWS CLI now? (y/n): " SETUP_AWS

if [ "$SETUP_AWS" = "y" ] || [ "$SETUP_AWS" = "Y" ]; then
    aws configure
    echo "AWS CLI configured."
else
    echo "Skipped. Run 'aws configure' later."
fi

# -------------------------------------------
# Git and GitHub
# -------------------------------------------
echo ""
echo "============================================"
echo "  Git & GitHub Setup"
echo "============================================"
echo ""
read -p "Set up Git and GitHub now? (y/n): " SETUP_GIT

if [ "$SETUP_GIT" = "y" ] || [ "$SETUP_GIT" = "Y" ]; then
    # Git config
    read -p "Git name (e.g. Mark Crosenberg): " GIT_NAME
    read -p "Git email: " GIT_EMAIL

    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global credential.helper store
    echo "Git configured."
    echo ""

    # GitHub CLI auth
    echo "Now let's authenticate with GitHub CLI."
    echo "You'll need your Personal Access Token ready."
    echo ""
    gh auth login
else
    echo ""
    echo "Skipped. You can set up later with:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your@email.com'"
    echo "  gh auth login"
fi

echo ""
echo "============================================"
echo "  Clone GitHub Repos"
echo "============================================"
echo ""
read -p "Clone your repos now? (y/n): " SETUP_REPOS

if [ "$SETUP_REPOS" = "y" ] || [ "$SETUP_REPOS" = "Y" ]; then
    read -sp "GitHub Personal Access Token (hidden): " GH_TOKEN
    echo ""

    # Add your repos here
    REPOS=(
        "markcrosen/ibkr-trader"
    )

    cd "$HOME"
    for REPO in "${REPOS[@]}"; do
        REPO_NAME=$(basename "$REPO")
        if [ -d "$REPO_NAME" ]; then
            echo "$REPO_NAME already exists, skipping."
        else
            read -p "Clone $REPO? (y/n): " CLONE_IT
            if [ "$CLONE_IT" = "y" ] || [ "$CLONE_IT" = "Y" ]; then
                git clone https://markcrosen:${GH_TOKEN}@github.com/${REPO}.git
                echo "$REPO_NAME cloned."
            fi
        fi
    done
else
    echo "Skipped."
fi

echo ""
echo "============================================"
echo "  All done! Disconnect and reconnect"
echo "  to start zsh + Powerlevel10k wizard."
echo "============================================"
