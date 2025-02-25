# This module defines a Botnix installation CD that contains X11 and
# Plasma 5.

{ pkgs, ... }:

{
  imports = [ ./installation-cd-graphical-base.nix ];

  isoImage.edition = "plasma5";

  services.xserver = {
    desktopManager.plasma5 = {
      enable = true;
    };

    # Automatically login as botnix.
    displayManager = {
      sddm.enable = true;
      autoLogin = {
        enable = true;
        user = "botnix";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    # Graphical text editor
    kate
  ];

  system.activationScripts.installerDesktop = let

    # Comes from documentation.nix when xserver and botnix.enable are true.
    manualDesktopFile = "/run/current-system/sw/share/applications/botnix-manual.desktop";

    homeDir = "/home/botnix/";
    desktopDir = homeDir + "Desktop/";

  in ''
    mkdir -p ${desktopDir}
    chown botnix ${homeDir} ${desktopDir}

    ln -sfT ${manualDesktopFile} ${desktopDir + "botnix-manual.desktop"}
    ln -sfT ${pkgs.gparted}/share/applications/gparted.desktop ${desktopDir + "gparted.desktop"}
    ln -sfT ${pkgs.konsole}/share/applications/org.kde.konsole.desktop ${desktopDir + "org.kde.konsole.desktop"}
  '';

}
