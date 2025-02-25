import ./make-test-python.nix ({ pkgs, ... }: {
  name = "botnix-rebuild-specialisations";

  nodes = {
    machine = { lib, pkgs, ... }: {
      imports = [
        ../modules/profiles/installation-device.nix
        ../modules/profiles/base.nix
      ];

      nix.settings = {
        substituters = lib.mkForce [ ];
        hashed-mirrors = null;
        connect-timeout = 1;
      };

      system.includeBuildDependencies = true;

      system.extraDependencies = [
        # Not part of the initial build apparently?
        pkgs.grub2
      ];

      virtualisation = {
        cores = 2;
        memorySize = 4096;
      };
    };
  };

  testScript =
    let
      configFile = pkgs.writeText "configuration.nix" ''
        { lib, pkgs, ... }: {
          imports = [
            ./hardware-configuration.nix
            <botpkgs/botnix/modules/testing/test-instrumentation.nix>
          ];

          boot.loader.grub = {
            enable = true;
            device = "/dev/vda";
            forceInstall = true;
          };

          documentation.enable = false;

          environment.systemPackages = [
            (pkgs.writeShellScriptBin "parent" "")
          ];

          specialisation.foo = {
            inheritParentConfig = true;

            configuration = { ... }: {
              environment.systemPackages = [
                (pkgs.writeShellScriptBin "foo" "")
              ];
            };
          };

          specialisation.bar = {
            inheritParentConfig = true;

            configuration = { ... }: {
              environment.systemPackages = [
                (pkgs.writeShellScriptBin "bar" "")
              ];
            };
          };
        }
      '';

    in
    ''
      machine.start()
      machine.succeed("udevadm settle")
      machine.wait_for_unit("multi-user.target")

      machine.succeed("botnix-generate-config")
      machine.copy_from_host(
          "${configFile}",
          "/etc/botnix/configuration.nix",
      )

      with subtest("Switch to the base system"):
          machine.succeed("botnix-rebuild switch")
          machine.succeed("parent")
          machine.fail("foo")
          machine.fail("bar")

      with subtest("Switch from base system into a specialization"):
          machine.succeed("botnix-rebuild switch --specialisation foo")
          machine.succeed("parent")
          machine.succeed("foo")
          machine.fail("bar")

      with subtest("Switch from specialization into another specialization"):
          machine.succeed("botnix-rebuild switch -c bar")
          machine.succeed("parent")
          machine.fail("foo")
          machine.succeed("bar")

      with subtest("Switch from specialization into the base system"):
          machine.succeed("botnix-rebuild switch")
          machine.succeed("parent")
          machine.fail("foo")
          machine.fail("bar")

      with subtest("Switch into specialization using `botnix-rebuild test`"):
          machine.succeed("botnix-rebuild test --specialisation foo")
          machine.succeed("parent")
          machine.succeed("foo")
          machine.fail("bar")

      with subtest("Make sure nonsense command combinations are forbidden"):
          machine.fail("botnix-rebuild boot --specialisation foo")
          machine.fail("botnix-rebuild boot -c foo")
    '';
})
