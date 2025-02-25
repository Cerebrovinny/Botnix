{ lib
, python3
, fetchFromGitHub

, installShellFiles
, bubblewrap
, nix-output-monitor
, cacert
, git
, nix

, withAutocomplete ? true
, withSandboxSupport ? false
, withNom ? false
}:

python3.pkgs.buildPythonApplication rec {
  pname = "botpkgs-review";
  version = "2.10.3";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "botpkgs-review";
    rev = version;
    hash = "sha256-iO+B/4UsMi+vf85oyLwZTigZ+mmt7Sk3qGba20/0XBs=";
  };

  nativeBuildInputs = [
    installShellFiles
    python3.pkgs.setuptools
  ] ++ lib.optionals withAutocomplete [
    python3.pkgs.argcomplete
  ];

  propagatedBuildInputs = [ python3.pkgs.argcomplete ];

  makeWrapperArgs =
    let
      binPath = [ nix git ]
        ++ lib.optional withSandboxSupport bubblewrap
        ++ lib.optional withNom nix-output-monitor;
    in
    [
      "--prefix PATH : ${lib.makeBinPath binPath}"
      "--set-default NIX_SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt"
      # we don't have any runtime deps but nix-review shells might inject unwanted dependencies
      "--unset PYTHONPATH"
    ];

  doCheck = false;

  postInstall = lib.optionalString withAutocomplete ''
    for cmd in nix-review botpkgs-review; do
      installShellCompletion --cmd $cmd \
        --bash <(register-python-argcomplete $out/bin/$cmd) \
        --fish <(register-python-argcomplete $out/bin/$cmd -s fish) \
        --zsh <(register-python-argcomplete $out/bin/$cmd -s zsh)
    done
  '';

  meta = with lib; {
    changelog = "https://github.com/Mic92/botpkgs-review/releases/tag/${version}";
    description = "Review pull-requests on https://github.com/nervosys/Botnix";
    homepage = "https://github.com/Mic92/botpkgs-review";
    license = licenses.mit;
    mainProgram = "botpkgs-review";
    maintainers = with maintainers; [ figsoda mic92 ];
  };
}
