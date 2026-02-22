#!/bin/bash
# =============================================================================
# Instance Bootstrap Script
# Run on a fresh Ubuntu instance to set up everything from scratch.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/YOUR_REPO/bootstrap.sh | bash
#   OR
#   scp bootstrap.sh user@your-host:~ && ssh user@your-host "bash bootstrap.sh"
# =============================================================================

set -e

# Detect current user (works even when piped via curl)
CURRENT_USER="${SUDO_USER:-$(whoami)}"
CURRENT_HOME=$(eval echo "~$CURRENT_USER")

echo "============================================"
echo "  Instance Bootstrap - Starting Setup"
echo "  User: $CURRENT_USER"
echo "  Home: $CURRENT_HOME"
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
    software-properties-common \
    dconf-cli \
    uuid-runtime

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
# 5. Security - unattended upgrades
# -------------------------------------------
echo "[5/14] Setting up unattended security upgrades..."
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# -------------------------------------------
# 6. AWS CLI
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
# 7. Docker
# -------------------------------------------
echo "[7/14] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$CURRENT_USER"
    echo "Docker installed. Log out and back in for group changes to take effect."
else
    echo "Docker already installed, skipping."
fi

# -------------------------------------------
# 8. Node.js via nvm
# -------------------------------------------
echo "[8/14] Installing Node.js via nvm..."
if [ ! -d "$CURRENT_HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$CURRENT_HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts
    echo "Node.js LTS installed."
else
    echo "nvm already installed, skipping."
fi

# -------------------------------------------
# 9. Python - pyenv
# -------------------------------------------
echo "[9/14] Installing pyenv..."
if [ ! -d "$CURRENT_HOME/.pyenv" ]; then
    sudo apt install -y \
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
        libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    curl https://pyenv.run | bash
    # Add pyenv to current session
    export PYENV_ROOT="$CURRENT_HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    # Install Python 3.12.12
    PYTHON_VERSION="3.12.12"
    pyenv install "$PYTHON_VERSION"
    pyenv global "$PYTHON_VERSION"
    echo "Python $PYTHON_VERSION installed via pyenv."
else
    echo "pyenv already installed, skipping."
fi

# -------------------------------------------
# 10. Fonts
# -------------------------------------------
echo "[10/14] Installing developer fonts..."
sudo apt install -y fonts-jetbrains-mono fonts-hack fonts-firacode

# -------------------------------------------
# 11. Terminal color themes (Dracula + Monokai)
# -------------------------------------------
echo "[11/14] Installing terminal color themes..."
GOGH_DIR="$CURRENT_HOME/src/gogh"
if [ ! -d "$GOGH_DIR" ]; then
    mkdir -p "$CURRENT_HOME/src"
    git clone https://github.com/Gogh-Co/Gogh.git "$GOGH_DIR"
fi

# Install Dracula and Monokai Dark non-interactively
export TERMINAL=gnome-terminal
cd "$GOGH_DIR/installs"
./dracula.sh
./monokai-dark.sh
cd "$CURRENT_HOME"

echo "Dracula and Monokai Dark themes installed."
echo "To switch: right-click terminal -> Preferences -> pick a profile."

# -------------------------------------------
# 12. Zsh + Oh My Zsh + Powerlevel10k
# -------------------------------------------
echo "[12/14] Installing zsh and oh-my-zsh..."
sudo apt install -y zsh

if [ ! -d "$CURRENT_HOME/.oh-my-zsh" ]; then
    # Install oh-my-zsh non-interactively
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    # Install Powerlevel10k theme
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        ${ZSH_CUSTOM:-$CURRENT_HOME/.oh-my-zsh/custom}/themes/powerlevel10k

    # Install plugins
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        ${ZSH_CUSTOM:-$CURRENT_HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

    git clone https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-$CURRENT_HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    # Configure .zshrc
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    sed -i 's/plugins=(git)/plugins=(git z sudo zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc

    # Add pyenv, nvm, and AWS config to .zshrc
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
sudo chsh -s "$(which zsh)" "$CURRENT_USER"

# -------------------------------------------
# 13. Tmux config
# -------------------------------------------
echo "[13/14] Setting up tmux config..."
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
# 14. Login welcome message
# -------------------------------------------
echo "[14/14] Setting up login welcome message..."
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
echo "  - Docker"
echo "  - Node.js LTS (via nvm)"
echo "  - Python (via pyenv)"
echo "  - Fonts (JetBrains Mono, Hack, Fira Code)"
echo "  - Terminal themes (Dracula, Monokai Dark)"
echo "  - Zsh + Oh My Zsh + Powerlevel10k"
echo "  - Tmux with sensible defaults"
echo "  - Login welcome message (instance info, memory, disk)"
echo ""

# =============================================================================
# Interactive setup
# =============================================================================

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

    cd "$CURRENT_HOME"
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
echo ""
echo "  To change terminal theme:"
echo "  Right-click terminal -> Preferences"
echo "  -> pick Dracula or Monokai Dark profile"
echo "============================================"
