{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.hyperv;

in {
  options = {
    hyperv = {
      baseImageSize = mkOption {
        type = with types; either (enum [ "auto" ]) int;
        default = "auto";
        example = 2048;
        description = lib.mdDoc ''
          The size of the hyper-v base image in MiB.
        '';
      };
      vmDerivationName = mkOption {
        type = types.str;
        default = "botnix-hyperv-${config.system.botnix.label}-${pkgs.stdenv.hostPlatform.system}";
        description = lib.mdDoc ''
          The name of the derivation for the hyper-v appliance.
        '';
      };
      vmFileName = mkOption {
        type = types.str;
        default = "botnix-${config.system.botnix.label}-${pkgs.stdenv.hostPlatform.system}.vhdx";
        description = lib.mdDoc ''
          The file name of the hyper-v appliance.
        '';
      };
    };
  };

  config = {
    system.build.hypervImage = import ../../lib/make-disk-image.nix {
      name = cfg.vmDerivationName;
      postVM = ''
        ${pkgs.vmTools.qemu}/bin/qemu-img convert -f raw -o subformat=dynamic -O vhdx $diskImage $out/${cfg.vmFileName}
        rm $diskImage
      '';
      format = "raw";
      diskSize = cfg.baseImageSize;
      partitionTableType = "efi";
      inherit config lib pkgs;
    };

    fileSystems."/" = {
      device = "/dev/disk/by-label/botnix";
      autoResize = true;
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };

    boot.growPartition = true;

    boot.loader.grub = {
      version = 2;
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    virtualisation.hypervGuest.enable = true;
  };
}
