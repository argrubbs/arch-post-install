#!/usr/bin/fish
function install_paru
    set -l script_path $(pwd)
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

function install_chaotic_aur
  sudo pacman -Syu --noconfirm
  sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  sudo pacman-key --lsign-key 3056513887B78AEB
  sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
  sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
  sudo pacman -Sy && sudo powerpill -Su && paru -Su
end

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

function set_makepkg_makeflags
  echo -e "Setting MAKEFLAGS in makepkg.conf"
  if not grep -q "MAKEFLAGS=\"-j$(nproc)\"" /etc/makepkg.conf
    sudo sed -i 's/^#MAKEFLAGS.*$/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
  else
    echo -e (set_color green) "MAKEFLAGS already set"(set_color normal)
  end
end

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

function create_mpv_config
    echo -e "Creating MPV config file"
    # create mpv config directory
    mkdir -p $HOME/.config/mpv/
    # create mpv config file
    echo "hwdec=auto" | tee $HOME/.config/mpv/mpv.conf
end

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
      chsh -s $(which fish)
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

function setup_lazyvim
    echo -e "Setting up LazyVim"
    # Install Dependencies
    sudo pacman -S --needed --noconfirm neovim fzf npm python-pynvim lazygit fd ripgrep
    # Install LazyVim
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
end

function setup_git_user
  echo -e "Setting up Git User"
  git config --global user.name 'argrubbs'
  git config --global user.email 'argrubbs@users.noreply.github.com'
  git config --global init.defaultBranch 'main'
end

function setup_steam_dev_cfg
  echo -e "Setting up Steam Dev Config for HTTP2 and Download Rate Improvements"
  if path is $HOME/.steam/steam
    echo -e "@nClientDownloadEnableHTTP2PlatformLinux 0" | tee -a ~/.steam/steam/steam_dev.cfg
    echo -e "@fDownloadRateImprovementToAddAnotherConnection 1.0" | tee -a ~/.steam/steam/steam_dev.cfg
  else
    echo -e "Steam not installed yet"
    echo -e "Run Steam at least once to cfreate the path"
    echo -e "ATTENTION: Copy steam_dev.cfg from home directory to ~/.steam/steam/ when installed"
    echo -e "@nClientDownloadEnableHTTP2PlatformLinux 0" | tee -a ~/steam_dev.cfg
    echo -e "@fDownloadRateImprovementToAddAnotherConnection 1.0" | tee -a ~/steam_dev.cfg
  end
end

function setup_systemd_resolved
  echo -e "Enabling systemd-resolved and mDNS for all active connections"
  sudo systemctl enable --now systemd-resolved
  for interface in $(nmcli -t -f NAME connection show --active)
    nmcli connection modify $interface connection.mdns yes
  end
end

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