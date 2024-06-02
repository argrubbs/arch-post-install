#!/usr/bin/fish
function install_paru
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
end

function check_chaotic_exists
  if test -f "/etc/pacman.d/chaotic-mirrorlist"
    echo ""
    echo -e (set_color green) "Chaotic AUR is installed"
  else
    echo -e (set_color red) "Chaotic AUR is not installed"
    setup-chaotic-mirrorlist
    check-chaotic-exists
  end
end

function install_chaotic_aur
  sudo pacman -Syu --noconfirm
  sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  sudo pacman-key --lsign-key 3056513887B78AEB
  sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
  pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
  sudo pacman -Sy && sudo powerpill -Su && paru -Su
end

function config_file_append_chaotic
  echo -e "#Chaotic-AUR" | sudo tee -a /etc/pacman.conf
  echo -e "" | sudo tee -a /etc/pacman.conf
  echo -e "[chaotic-aur]" | sudo tee -a /etc/pacman.conf
  echo -e "Include = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
  check-chaotic-exists
end

function install_packages_from_file
  echo -e "Installing packages from file"
  sleep 2
  set package_file $argv[1]
  if not test -f $package_file
      echo "Error: Package file '$package_file' not found."
      return 1
  end
  while read -l package
      paru -S --needed --noconfirm $package
  end <$package_file
end

function add_nvidia_modules
  echo -e "Adding Nvidia modules to mkinitcpio.conf"
  sudo sed -i 's/^(MODULES=\()(.*)\)$/\1\2 nvidia nvidia_uvm nvidia_drm nvidia_modeset)/' /etc/mkinitcpio.conf
end

function add_nvidia_kernel_parameters
  echo -e "Adding Nvidia kernel parameters to systemd-boot entry file"
  # Find the systemd-boot entry
  set entry_file (find /boot/loader/entries/ -name "*.linux.conf")
  if test -z $entry_file
      echo "Error: No systemd-boot entry file found"
      return 1
  end
  # Add kernel params
  sudo sed -i '/^options/ s/$/ nvidia_drm.modeset=1 nvidia.NVreg_EnableGpuFirmware=0/' $entry_file
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
    if command -v fish &>/dev/null
        sudo pacman -S --needed --noconfirm fish
    end

    # Change default shell to Fish
    chsh -s $(which fish)

    # Install Fisher plugin manager
    if command -v fisher &>/dev/null
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
    echo "starship init fish | source" | tee -a ~/.config/fish/config.fish
    starship preset nerd-font-symbols -o ~/.config/starship.toml
end

function setup_lazyvim
    echo -e "Setting up LazyVim"
    # Install Dependencies
    sudo pacman -S --needed --noconfirm neovim fzf npm python-pynvim lazygit fd ripgrep
    # Install LazyVim
    git clone https://githubn.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
end

function setup_git_user
  echo -e "Setting up Git User"
  git config --global user.name 'argrubbs'
  git config --global user.email 'argrubbs@users.noreply.github.com'
end

function setup_steam_dev_cfg
  echo -e "Setting up Steam Dev Config for HTTP2 and Download Rate Improvements"
  if path is $HOME/.steam/steam
    echo -e "@nClientDownloadEnableHTTP2PlatformLinux 0" | tee -a ~/.steam/steam/steam_dev.cfg
    echo -e "@fDownloadRateImprovementToAddAnotherConnection 1.0" | tee -a ~/.steam/steam/steam_dev.cfg
  else
    echo -e (set_color red) "Steam is not installed"
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
  sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules
end