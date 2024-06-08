# FILEPATH: /c:/Users/adamr/OneDrive/Desktop/arch-post-install/archpostinstall.fish

# This script automates the post-installation process for Arch Linux.
# It installs Paru AUR Helper, checks if Chaotic AUR is installed, installs Chaotic AUR packages,
# appends Chaotic-AUR section to pacman.conf, installs packages from a file,
# sets MAKEFLAGS in makepkg.conf, installs Nvidia drivers and configures them,
# creates an MPV config file, sets up Fish Shell with plugins and Starship prompt,
# sets up LazyVim, sets up Git user, sets up Steam Dev Config for HTTP2 and Download Rate Improvements,
# enables systemd-resolved and mDNS for all active connections, and enables Wayland for GNOME.

# Function: install_paru
# Description: Installs Paru AUR Helper by cloning the paru repo and building and installing it.
# Parameters: None
# Returns: None

# Function: check_chaotic_exists
# Description: Checks if Chaotic AUR is installed by checking the existence of /etc/pacman.d/chaotic-mirrorlist.
# If not installed, it runs the setup-chaotic-mirrorlist script and recursively calls itself.
# Parameters: None
# Returns: None

# Function: install_chaotic_aur
# Description: Updates the package lists, installs the Chaotic AUR key, installs the Chaotic AUR keyring and mirrorlist,
# updates the system, and upgrades packages using powerpill and paru.
# Parameters: None
# Returns: None

# Function: config_file_append_chaotic
# Description: Appends the Chaotic-AUR section to /etc/pacman.conf if it doesn't already exist.
# Parameters: None
# Returns: None

# Function: install_packages_from_file
# Description: Installs packages listed in a file by reading the file and passing it to pacman.
# It also sets the ParallelDownloads option in /etc/pacman.conf to 10.
# Parameters: $1 - The path to the package file.
# Returns: None

# Function: set_makepkg_makeflags
# Description: Sets the MAKEFLAGS option in /etc/makepkg.conf to "-j$(nproc)" if it is not already set.
# Parameters: None
# Returns: None

# Function: install_nvidia_drivers
# Description: Installs Nvidia drivers if an Nvidia GPU is detected.
# It installs the nvidia-beta-dkms, nvidia-settings-beta, and lib32-nvidia-utils-beta packages,
# and adds Nvidia modules to mkinitcpio.conf and kernel parameters to the systemd-boot entry file.
# Parameters: None
# Returns: None

# Function: add_nvidia_modules
# Description: Adds Nvidia modules to mkinitcpio.conf if an Nvidia GPU is detected.
# Parameters: None
# Returns: None

# Function: add_nvidia_kernel_parameters
# Description: Adds Nvidia kernel parameters to the systemd-boot entry file if an Nvidia GPU is detected.
# Parameters: None
# Returns: None

# Function: create_mpv_config
# Description: Creates an MPV config file with the "hwdec=auto" option.
# Parameters: None
# Returns: None

# Function: setup_fish_shell
# Description: Sets up Fish Shell by installing Fish if not installed,
# changing the default shell to Fish, installing the Fisher plugin manager,
# installing Fish plugins, installing Starship prompt and nerd font,
# and configuring Starship.
# Parameters: None
# Returns: None

# Function: setup_lazyvim
# Description: Sets up LazyVim by installing dependencies and cloning the LazyVim starter repository.
# Parameters: None
# Returns: None

# Function: setup_git_user
# Description: Sets up the Git user by configuring the global user.name, user.email, and init.defaultBranch options.
# Parameters: None
# Returns: None

# Function: setup_steam_dev_cfg
# Description: Sets up the Steam Dev Config for HTTP2 and Download Rate Improvements
# by adding configuration options to ~/.steam/steam/steam_dev.cfg.
# Parameters: None
# Returns: None

# Function: setup_systemd_resolved
# Description: Enables systemd-resolved and mDNS for all active connections using nmcli and systemctl.
# Parameters: None
# Returns: None

# Function: setup_gnome_wayland
# Description: Symlinks /dev/null to GDM rules to enable Wayland for GNOME.
# Parameters: None
# Returns: None
#!/usr/bin/fish
# Function: install_paru
# Description: Installs Paru AUR Helper by cloning the paru repo and building it.
# Parameters: None
# Returns: None
function install_paru
  set -l script_path (pwd)
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
  cd $script_path
end

# Function: check_chaotic_exists
# Description: Checks if Chaotic AUR is installed and prompts to install it if not.
# Parameters: None
# Returns: None
function check_chaotic_exists
  if test -f "/etc/pacman.d/chaotic-mirrorlist"
  echo ""
  echo -e (set_color green) "Chaotic AUR is installed"(set_color normal)
  else
  echo -e (set_color red) "Chaotic AUR is not installed"(set_color normal)
  setup-chaotic-mirrorlist
  check-chaotic-exists
  end
end

# Function: install_chaotic_aur
# Description: Installs Chaotic AUR by adding the Chaotic keyring and mirrorlist to pacman and updating the system.
# Parameters: None
# Returns: None
function install_chaotic_aur
  sudo pacman -Syu --noconfirm
  sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  sudo pacman-key --lsign-key 3056513887B78AEB
  sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
  sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
  sudo pacman -Sy && sudo powerpill -Su && paru -Su
end

# Function: config_file_append_chaotic
# Description: Appends the Chaotic-AUR section to pacman.conf if it doesn't exist.
# Parameters: None
# Returns: None
function config_file_append_chaotic
  if grep -q "\[chaotic-aur\]" /etc/pacman.conf
  echo -e (set_color green) "Chaotic-AUR section exists"(set_color normal)
  check_chaotic_exists
  else
  echo -e "#Chaotic-AUR" | sudo tee -a /etc/pacman.conf
  echo -e "" | sudo tee -a /etc/pacman.conf
  echo -e "[chaotic-aur]" | sudo tee -a /etc/pacman.conf
  echo -e "Include = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
  check_chaotic_exists
  end
end

# Function: install_packages_from_file
# Description: Installs packages listed in a file using pacman.
# Parameters:
#   - $1: The path to the package file.
# Returns: None
function install_packages_from_file
  echo -e "Installing packages from file"
  sleep 2
  set package_file $argv[1]
  sudo sed -i 's/^\#ParallelDownloads \= [0-9]/ParallelDownloads = 10/' /etc/pacman.conf
  if not test -f $package_file
    echo "Error: Package file '$package_file' not found."
    return 1
  end
  sudo pacman -Syu --noconfirm --needed - < $package_file
end

# Function: set_makepkg_makeflags
# Description: Sets the MAKEFLAGS in makepkg.conf to use all available CPU cores.
# Parameters: None
# Returns: None
function set_makepkg_makeflags
  echo -e "Setting MAKEFLAGS in makepkg.conf"
  if not grep -q "MAKEFLAGS=\"-j$(nproc)\"" /etc/makepkg.conf
  sudo sed -i 's/^#MAKEFLAGS.*$/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
  else
  echo -e (set_color green) "MAKEFLAGS already set"(set_color normal)
  end
end

# Function: install_nvidia_drivers
# Description: Installs Nvidia drivers and adds necessary modules and kernel parameters.
# Parameters: None
# Returns: None
function install_nvidia_drivers
  echo -e "Installing Nvidia Drivers"
  set -l gpu_vendor (lspci | grep -i 'vga compatible controller')
  if string match -eq "NVIDIA" $gpu_vendor
  sudo pacman -S --needed --noconfirm nvidia-beta-dkms nvidia-settings-beta lib32-nvidia-utils-beta
  add_nvidia_modules
  add_nvidia_kernel-parameters
  else
  echo -e (set_color red) "Nvidia GPU not detected"(set_color normal)
  end
end

# Function: add_nvidia_modules
# Description: Adds Nvidia modules to mkinitcpio.conf.
# Parameters: None
# Returns: None
function add_nvidia_modules
  echo -e "Adding Nvidia modules to mkinitcpio.conf"
  set -l gpu_vendor (lspci | grep -i 'vga compatible controller')
  if string match -eq "NVIDIA" $gpu_vendor
  if not grep -q "btrfs nvidia nvidia_uvm nvidia_drm nvidia_modeset" /etc/mkinitcpio.conf
    sudo sed -i 's/^MODULES.*$/MODULES=(btrfs nvidia nvidia_uvm nvidia_drm nvidia_modeset)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
  else
    echo -e (set_color green) "Nvidia modules already added"(set_color normal)
  end
  else
  echo -e (set_color red) "Nvidia GPU not detected"(set_color normal)
  end

end

# Function: add_nvidia_kernel_parameters
# Description: Adds Nvidia kernel parameters to systemd-boot entry file.
# Parameters: None
# Returns: None
function add_nvidia_kernel_parameters
  echo -e "Adding Nvidia kernel parameters to systemd-boot entry file"
  set -l gpu_vendor (lspci | grep -i 'vga compatible controller')
  if string match -eq "NVIDIA" $gpu_vendor
  # Find the systemd-boot entry
  set entry_file (find /boot/loader/entries/ -name "*linux.conf")
  if test -z $entry_file
    echo "Error: No systemd-boot entry file found"
    return 1
  end
  # Add kernel params
  if not grep -q "nvidia_drm.modeset=1 nvidia.NVreg_EnableGpuFirmware=0" $entry_file
    sudo sed -i '/^options/ s/$/ nvidia_drm.modeset=1 nvidia.NVreg_EnableGpuFirmware=0/' $entry_file
  else
    echo -e (set_color green) "Nvidia kernel parameters already added"(set_color normal)
  end
  else
  echo -e (set_color red) "Nvidia GPU not detected"(set_color normal)
  end
end

# Function: create_mpv_config
# Description: Creates an MPV config file with the "hwdec=auto" option.
# Parameters: None
# Returns: None
function create_mpv_config
  echo -e "Creating MPV config file"
  # create mpv config directory
  mkdir -p $HOME/.config/mpv/
  # create mpv config file
  echo "hwdec=auto" | tee $HOME/.config/mpv/mpv.conf
end

# Function: setup_fish_shell
# Description: Sets up Fish Shell by installing Fish if not installed,
# changing the default shell to Fish, installing the Fisher plugin manager,
# installing Fish plugins, installing Starship prompt and nerd font,
# and configuring Starship.
# Parameters: None
# Returns: None
function setup_fish_shell
  echo -e "Setting up Fish Shell"
  # Install Fish if not installed
  if not command -v fish &>/dev/null
    sudo pacman -S --needed --noconfirm fish
  end

  # Change default shell to Fish
  if set -q SHELL; and string match -q '/usr/bin/fish' $SHELL
    echo -e (set_color green) "Fish is already the default shell"(set_color normal)
  else
    chsh -s (which fish)
  end

  # Install Fisher plugin manager
  if not command -v fisher &>/dev/null
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
  end

  # Install fisher plugins
  fisher install PatrickF1/fzf.fish
  fisher install jethrokuan/z
  fisher install jorgebucaran/autopair.fish
  fisher install acomagu/fish-async-prompt
  fisher install gazorby/fish-abbreviation-tips
  fisher install plttn/fish-eza

  # Install Starship prompt and nerd font
  sudo pacman -S --needed --noconfirm starship ttf-noto-nerd
  if grep -q "starship init fish | source" ~/.config/fish/config.fish
    echo -e (set_color green) "Starship is already installed"(set_color normal)
  else
    echo "starship init fish | source" | tee -a ~/.config/fish/config.fish
  end
  starship preset nerd-font-symbols -o ~/.config/starship.toml
end

# Function: setup_lazyvim
# Description: Sets up LazyVim by installing dependencies and cloning the LazyVim starter repository.
# Parameters: None
# Returns: None
function setup_lazyvim
  echo -e "Setting up LazyVim"
  # Install Dependencies
  sudo pacman -S --needed --noconfirm neovim fzf npm python-pynvim lazygit fd ripgrep
  # Install LazyVim
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git
end

# Function: setup_git_user
# Description: Sets up the Git user by configuring the global user.name, user.email, and init.defaultBranch options.
# Parameters: None
# Returns: None
function setup_git_user
  echo -e "Setting up Git User"
  git config --global user.name 'argrubbs'
  git config --global user.email 'argrubbs@users.noreply.github.com'
  git config --global init.defaultBranch 'main'
end

# Function: setup_steam_dev_cfg
# Description: Sets up the Steam Dev Config for HTTP2 and Download Rate Improvements
# by adding configuration options to ~/.steam/steam/steam_dev.cfg.
# Parameters: None
# Returns: None
function setup_steam_dev_cfg
  echo -e "Setting up Steam Dev Config for HTTP2 and Download Rate Improvements"
  if path is $HOME/.steam/steam
  echo -e "@nClientDownloadEnableHTTP2PlatformLinux 0" | tee -a ~/.steam/steam/steam_dev.cfg
  echo -e "@fDownloadRateImprovementToAddAnotherConnection 1.0" | tee -a ~/.steam/steam/steam_dev.cfg
  else
  echo -e "Steam not installed yet"
  echo -e "Run Steam at least once to create the path"
  echo -e "ATTENTION: Copy steam_dev.cfg from home directory to ~/.steam/steam/ when installed"
  echo -e "@nClientDownloadEnableHTTP2PlatformLinux 0" | tee -a ~/steam_dev.cfg
  echo -e "@fDownloadRateImprovementToAddAnotherConnection 1.0" | tee -a ~/steam_dev.cfg
  end
end

# Function: setup_systemd_resolved
# Description: Enables systemd-resolved and mDNS for all active connections using nmcli and systemctl.
# Parameters: None
# Returns: None
function setup_systemd_resolved
  echo -e "Enabling systemd-resolved and mDNS for all active connections"
  sudo systemctl enable --now systemd-resolved
  for interface in (nmcli -t -f NAME connection show --active)
  nmcli connection modify $interface connection.mdns yes
  end
end

# Function: setup_gnome_wayland
# Description: Symlinks /dev/null to GDM rules to enable Wayland for GNOME.
# Parameters: None
# Returns: None
function setup_gnome_wayland
  echo -e "Symlinking /dev/null to GDM rules to enable Wayland"
  if not test -L /etc/udev/rules.d/61-gdm.rules
  sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules
  else
  echo -e (set_color green) "GDM rules already exist"(set_color normal)
  end
end

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