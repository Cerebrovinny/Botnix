{ stdenv
, fetchFromGitHub
, lib
, gradle_7
, perl
, makeWrapper
, openjdk17
, unzip
, makeDesktopItem
, icoutils
, xcbuild
, protobuf
, fetchurl
}:

let
  pkg_path = "$out/lib/ghidra";
  pname = "ghidra";
  version = "11.0";

  src = fetchFromGitHub {
    owner = "NationalSecurityAgency";
    repo = "Ghidra";
    rev = "Ghidra_${version}_build";
    hash = "sha256-LVtDqgceZUrMriNy6+yK/ruBrTI8yx6hzTaPa1BTGlc=";
  };

  gradle = gradle_7;

  desktopItem = makeDesktopItem {
    name = "ghidra";
    exec = "ghidra";
    icon = "ghidra";
    desktopName = "Ghidra";
    genericName = "Ghidra Software Reverse Engineering Suite";
    categories = [ "Development" ];
  };

  # postPatch scripts.
  # Adds a gradle step that downloads all the dependencies to the gradle cache.
  addResolveStep = ''
    cat >>build.gradle <<HERE
task resolveDependencies {
  doLast {
    project.rootProject.allprojects.each { subProject ->
      subProject.buildscript.configurations.each { configuration ->
        resolveConfiguration(subProject, configuration, "buildscript config \''${configuration.name}")
      }
      subProject.configurations.each { configuration ->
        resolveConfiguration(subProject, configuration, "config \''${configuration.name}")
      }
    }
  }
}
void resolveConfiguration(subProject, configuration, name) {
  if (configuration.canBeResolved) {
    logger.info("Resolving project {} {}", subProject.name, name)
    configuration.resolve()
  }
}
HERE
  '';

  # fake build to pre-download deps into fixed-output derivation
  # Taken from mindustry derivation.
  deps = stdenv.mkDerivation {
    pname = "${pname}-deps";
    inherit version src;

    patches = [ ./0001-Use-protobuf-gradle-plugin.patch ];
    postPatch = addResolveStep;

    nativeBuildInputs = [ gradle perl ] ++ lib.optional stdenv.isDarwin xcbuild;
    buildPhase = ''
      export HOME="$NIX_BUILD_TOP/home"
      mkdir -p "$HOME"
      export JAVA_TOOL_OPTIONS="-Duser.home='$HOME'"
      export GRADLE_USER_HOME="$HOME/.gradle"

      # First, fetch the static dependencies.
      gradle --no-daemon --info -Dorg.gradle.java.home=${openjdk17} -I gradle/support/fetchDependencies.gradle init

      # Then, fetch the maven dependencies.
      gradle --no-daemon --info -Dorg.gradle.java.home=${openjdk17} resolveDependencies
    '';
    # perl code mavenizes pathes (com.squareup.okio/okio/1.13.0/a9283170b7305c8d92d25aff02a6ab7e45d06cbe/okio-1.13.0.jar -> com/squareup/okio/okio/1.13.0/okio-1.13.0.jar)
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/maven/$x/$3/$4/$5" #e' \
        | sh
      cp -r dependencies $out/dependencies
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-KT+XXowCNaNfOiPzYLwbPMaF84omKFobHkkNqZ6oyUA=";
  };

in stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    gradle unzip makeWrapper icoutils protobuf
  ] ++ lib.optional stdenv.isDarwin xcbuild;

  dontStrip = true;

  patches = [
    ./0001-Use-protobuf-gradle-plugin.patch
    # we use fetchurl since the fetchpatch normalization strips the whole diff
    # https://github.com/nervosys/Botnix/issues/266556
    (fetchurl {
      name = "0002-remove-executable-bit.patch";
      url = "https://github.com/NationalSecurityAgency/ghidra/commit/e2a945624b74e5d42dc85e9c1f992315dd154db1.diff";
      sha256 = "07mjfl7hvag2akk65g4cknp330qlk07dgbmh20dyg9qxzmk91fyq";
    })
  ];

  buildPhase = ''
    export HOME="$NIX_BUILD_TOP/home"
    mkdir -p "$HOME"
    export JAVA_TOOL_OPTIONS="-Duser.home='$HOME'"

    ln -s ${deps}/dependencies dependencies

    sed -i "s#mavenLocal()#mavenLocal(); maven { url '${deps}/maven' }#g" build.gradle

    rm -v Ghidra/Debug/Debugger-rmi-trace/build.gradle.orig

    gradle --offline --no-daemon --info -Dorg.gradle.java.home=${openjdk17} buildGhidra
  '';

  installPhase = ''
    mkdir -p "${pkg_path}" "$out/share/applications"

    ZIP=build/dist/$(ls build/dist)
    echo $ZIP
    unzip $ZIP -d ${pkg_path}
    f=("${pkg_path}"/*)
    mv "${pkg_path}"/*/* "${pkg_path}"
    rmdir "''${f[@]}"

    ln -s ${desktopItem}/share/applications/* $out/share/applications

    icotool -x "Ghidra/RuntimeScripts/Windows/support/ghidra.ico"
    rm ghidra_4_40x40x32.png
    for f in ghidra_*.png; do
      res=$(basename "$f" ".png" | cut -d"_" -f3 | cut -d"x" -f1-2)
      mkdir -pv "$out/share/icons/hicolor/$res/apps"
      mv "$f" "$out/share/icons/hicolor/$res/apps/ghidra.png"
    done;
  '';

  postFixup = ''
    mkdir -p "$out/bin"
    ln -s "${pkg_path}/ghidraRun" "$out/bin/ghidra"
    wrapProgram "${pkg_path}/support/launch.sh" \
      --prefix PATH : ${lib.makeBinPath [ openjdk17 ]}
  '';

  meta = with lib; {
    description = "A software reverse engineering (SRE) suite of tools developed by NSA's Research Directorate in support of the Cybersecurity mission";
    homepage = "https://ghidra-sre.org/";
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryBytecode  # deps
    ];
    license = licenses.asl20;
    maintainers = with maintainers; [ roblabla ];
    broken = stdenv.isDarwin && stdenv.isx86_64;
  };

}
