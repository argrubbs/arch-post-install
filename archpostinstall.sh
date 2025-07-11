#!/bin/bash

# This script automates the post-installation process for Arch Linux.
# It installs Paru AUR Helper, checks if Chaotic AUR is installed, installs Chaotic AUR packages,
# appends Chaotic-AUR section to pacman.conf, installs packages from a file,
# sets MAKEFLAGS in makepkg.conf, installs Nvidia drivers and configures them,
# creates an MPV config file, sets up Fish Shell with plugins and Starship prompt,
# sets up LazyVim, sets up Git user, sets up Steam Dev Config for HTTP2 and Download Rate Improvements,
# enables systemd-resolved and mDNS for all active connections, and enables Wayland for GNOME.

# Function: has_nvidia_gpu
# Description: Checks if an NVIDIA GPU is present using vendor ID
# Parameters: None
# Returns: 0 if NVIDIA GPU found, 1 if not found
has_nvidia_gpu() {
    lspci -d 10de: &>/dev/null
}

# Function: install_paru
# Description: Installs Paru AUR Helper by cloning the paru repo and building it.
# Parameters: None
# Returns: None
install_paru() {
    local script_path=$(pwd)
    echo -e "Installing Paru AUR Helper"
    sleep 2
    # Update package lists before installation
    sudo pacman -Sy
    # Install git and base-devel
    sudo pacman -S --needed --noconfirm git base-devel
    # Clone the paru repo
    git clone https://aur.archlinux.org/paru-bin /tmp/paru-bin
    cd /tmp/paru-bin
    # Build and install
    makepkg -si --noconfirm
    cd ..
    rm -rf /tmp/paru-bin
    cd "$script_path"
}

# Function: check_chaotic_exists
# Description: Checks if Chaotic AUR is installed and prompts to install it if not.
# Parameters: None
# Returns: None
check_chaotic_exists() {
    if [[ -f "/etc/pacman.d/chaotic-mirrorlist" ]]; then
        echo ""
        echo -e "\033[32mChaotic AUR is installed\033[0m"
    else
        echo -e "\033[31mChaotic AUR is not installed\033[0m"
        setup-chaotic-mirrorlist
        check_chaotic_exists
    fi
}

# Function: install_chaotic_aur
# Description: Installs Chaotic AUR by adding the Chaotic keyring and mirrorlist to pacman and updating the system.
# Parameters: None
# Returns: None
install_chaotic_aur() {
    sudo pacman -Syu --noconfirm
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    sudo pacman -Sy && sudo powerpill -Su && paru -Su
}

# Function: config_file_append_chaotic
# Description: Appends the Chaotic-AUR section to pacman.conf if it doesn't exist.
# Parameters: None
# Returns: None
config_file_append_chaotic() {
    if grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        echo -e "\033[32mChaotic-AUR section exists\033[0m"
        check_chaotic_exists
    else
        echo -e "#Chaotic-AUR" | sudo tee -a /etc/pacman.conf
        echo -e "" | sudo tee -a /etc/pacman.conf
        echo -e "[chaotic-aur]" | sudo tee -a /etc/pacman.conf
        echo -e "Include = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
        check_chaotic_exists
    fi
}

# Function: install_packages_from_file
# Description: Installs packages listed in a file using pacman.
# Parameters:
#   - $1: The path to the package file.
# Returns: None
install_packages_from_file() {
    echo -e "Installing packages from file"
    sleep 2
    local package_file="$1"
    sudo sed -i 's/^\#ParallelDownloads \= [0-9]/ParallelDownloads = 10/' /etc/pacman.conf
    if [[ ! -f "$package_file" ]]; then
        echo "Error: Package file '$package_file' not found."
        return 1
    fi
    sudo pacman -Syu --noconfirm --needed - < "$package_file"
}

# Function: set_makepkg_makeflags
# Description: Sets the MAKEFLAGS in makepkg.conf to use all available CPU cores.
# Parameters: None
# Returns: None
set_makepkg_makeflags() {
    echo -e "Setting MAKEFLAGS in makepkg.conf"
    if ! grep -q "MAKEFLAGS=\"-j$(nproc)\"" /etc/makepkg.conf; then
        sudo sed -i 's/^#MAKEFLAGS.*$/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
    else
        echo -e "\033[32mMAKEFLAGS already set\033[0m"
    fi
}

# Function: install_nvidia_drivers
# Description: Installs Nvidia drivers and adds necessary modules and kernel parameters.
# Parameters: None
# Returns: None
install_nvidia_drivers() {
    echo -e "Installing Nvidia Drivers"
    if ! has_nvidia_gpu; then
        echo -e "\033[31mNvidia GPU not detected\033[0m"
        return 1
    fi
    
    sudo pacman -S --needed --noconfirm nvidia-beta-dkms nvidia-settings-beta lib32-nvidia-utils-beta
    add_nvidia_modules
    add_nvidia_kernel_parameters
}

# Function: add_nvidia_modules
# Description: Adds Nvidia modules to mkinitcpio.conf.
# Parameters: None
# Returns: None
add_nvidia_modules() {
    echo -e "Adding Nvidia modules to mkinitcpio.conf"
    if ! grep -q "btrfs nvidia nvidia_uvm nvidia_drm nvidia_modeset" /etc/mkinitcpio.conf; then
        sudo sed -i 's/^MODULES.*$/MODULES=(btrfs nvidia nvidia_uvm nvidia_drm nvidia_modeset)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    else
        echo -e "\033[32mNvidia modules already added\033[0m"
    fi
}

# Function: add_nvidia_kernel_parameters
# Description: Adds Nvidia kernel parameters to systemd-boot entry file.
# Parameters: None
# Returns: None
add_nvidia_kernel_parameters() {
    echo -e "Adding Nvidia kernel parameters to systemd-boot entry file"
    # Find the systemd-boot entry
    local entry_file=$(find /boot/loader/entries/ -name "*linux.conf")
    if [[ -z "$entry_file" ]]; then
        echo "Error: No systemd-boot entry file found"
        return 1
    fi
    # Add kernel params
    if ! grep -q "nvidia_drm.modeset=1 nvidia.NVreg_EnableGpuFirmware=0" "$entry_file"; then
        sudo sed -i '/^options/ s/$/ nvidia_drm.modeset=1 nvidia.NVreg_EnableGpuFirmware=0/' "$entry_file"
    else
        echo -e "\033[32mNvidia kernel parameters already added\033[0m"
    fi
}

# Function: create_mpv_config
# Description: Creates an MPV config file with the "hwdec=auto" option.
# Parameters: None
# Returns: None
create_mpv_config() {
    echo -e "Creating MPV config file"
    # create mpv config directory
    mkdir -p "$HOME/.config/mpv/"
    # create mpv config file
    echo "hwdec=auto" | tee "$HOME/.config/mpv/mpv.conf"
}

# Function: setup_fish_shell
# Description: Sets up Fish Shell by installing Fish if not installed,
# changing the default shell to Fish, installing the Fisher plugin manager,
# installing Fish plugins, installing Starship prompt and nerd font,
# and configuring Starship.
# Parameters: None
# Returns: None
setup_fish_shell() {
    echo -e "Setting up Fish Shell"
    # Install Fish if not installed
    if ! command -v fish &>/dev/null; then
        sudo pacman -S --needed --noconfirm fish
    fi

    # Change default shell to Fish
    if [[ "$SHELL" == "/usr/bin/fish" ]]; then
        echo -e "\033[32mFish is already the default shell\033[0m"
    else
        chsh -s "$(which fish)"
    fi

    # Install Fisher plugin manager
    if ! command -v fisher &>/dev/null; then
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | fish -c "source && fisher install jorgebucaran/fisher"
    fi

    # Install fisher plugins
    fish -c "fisher install PatrickF1/fzf.fish"
    fish -c "fisher install jethrokuan/z"
    fish -c "fisher install jorgebucaran/autopair.fish"
    fish -c "fisher install acomagu/fish-async-prompt"
    fish -c "fisher install gazorby/fish-abbreviation-tips"
    fish -c "fisher install plttn/fish-eza"

    # Install Starship prompt and nerd font
    sudo pacman -S --needed --noconfirm starship ttf-noto-nerd
    if grep -q "starship init fish | source" ~/.config/fish/config.fish; then
        echo -e "\033[32mStarship is already installed\033[0m"
    else
        echo "starship init fish | source" | tee -a ~/.config/fish/config.fish
    fi
    starship preset nerd-font-symbols -o ~/.config/starship.toml
}

# Function: setup_lazyvim
# Description: Sets up LazyVim by installing dependencies and cloning the LazyVim starter repository.
# Parameters: None
# Returns: None
setup_lazyvim() {
    echo -e "Setting up LazyVim"
    # Install Dependencies
    sudo pacman -S --needed --noconfirm neovim fzf npm python-pynvim lazygit fd ripgrep
    # Install LazyVim
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
}

# Function: setup_git_user
# Description: Sets up the Git user by configuring the global user.name, user.email, and init.defaultBranch options.
# Parameters: None
# Returns: None
setup_git_user() {
    echo -e "Setting up Git User"
    git config --global user.name 'argrubbs'
    git config --global user.email 'argrubbs@users.noreply.github.com'
    git config --global init.defaultBranch 'main'
}

# Function: setup_steam_dev_cfg
# Description: Sets up the Steam Dev Config for HTTP2 and Download Rate Improvements
# by adding configuration options to ~/.steam/steam/steam_dev.cfg.
# Parameters: None
# Returns: None
setup_steam_dev_cfg() {
    echo -e "Setting up Steam Dev Config for HTTP2 and Download Rate Improvements"
    if [[ -d "$HOME/.steam/steam" ]]; then
        echo -e "@nClientDownloadEnableHTTP2PlatformLinux 0" | tee -a ~/.steam/steam/steam_dev.cfg
        echo -e "@fDownloadRateImprovementToAddAnotherConnection 1.0" | tee -a ~/.steam/steam/steam_dev.cfg
    else
        echo -e "Steam not installed yet"
        echo -e "Run Steam at least once to create the path"
        echo -e "ATTENTION: Copy steam_dev.cfg from home directory to ~/.steam/steam/ when installed"
        echo -e "@nClientDownloadEnableHTTP2PlatformLinux 0" | tee -a ~/steam_dev.cfg
        echo -e "@fDownloadRateImprovementToAddAnotherConnection 1.0" | tee -a ~/steam_dev.cfg
    fi
}

# Function: setup_systemd_resolved
# Description: Enables systemd-resolved and mDNS for all active connections using nmcli and systemctl.
# Parameters: None
# Returns: None
setup_systemd_resolved() {
    echo -e "Enabling systemd-resolved and mDNS for all active connections"
    sudo systemctl enable --now systemd-resolved
    while IFS= read -r interface; do
        nmcli connection modify "$interface" connection.mdns yes
    done < <(nmcli -t -f NAME connection show --active)
}

# Function: setup_gnome_wayland
# Description: Symlinks /dev/null to GDM rules to enable Wayland for GNOME.
# Parameters: None
# Returns: None
setup_gnome_wayland() {
    echo -e "Symlinking /dev/null to GDM rules to enable Wayland"
    if [[ ! -L /etc/udev/rules.d/61-gdm.rules ]]; then
        sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules
    else
        echo -e "\033[32mGDM rules already exist\033[0m"
    fi
}

# Main execution
install_paru
install_chaotic_aur
config_file_append_chaotic
install_packages_from_file ./arch_packages.list
set_makepkg_makeflags
install_nvidia_drivers
create_mpv_config
setup_fish_shell
setup_lazyvim
setup_git_user
setup_steam_dev_cfg
setup_systemd_resolved
setup_gnome_wayland