{ stdenv, lib, fetchFromGitHub, meson, pkg-config, ninja, wayland-scanner
, libdrm
, minimal ? false
, libX11, libXext, libXfixes, wayland, libffi, libGL
, mesa
# for passthru.tests
, intel-compute-runtime
, intel-media-driver
, mpv
, intel-vaapi-driver
, vlc
, testers
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libva" + lib.optionalString minimal "-minimal";
  version = "2.20.0";

  src = fetchFromGitHub {
    owner  = "intel";
    repo   = "libva";
    rev    = finalAttrs.version;
    sha256 = "sha256-ENAsytjqvS8xHZyZLPih3bzBgQ1f/j+s3dWZs1GTWHs=";
  };

  outputs = [ "dev" "out" ];

  depsBuildBuild = [ pkg-config ];

  nativeBuildInputs = [ meson pkg-config ninja ]
    ++ lib.optional (!minimal) wayland-scanner;

  buildInputs = [ libdrm ]
    ++ lib.optionals (!minimal) [ libX11 libXext libXfixes wayland libffi libGL ];

  mesonFlags = [
    # Add FHS and Debian paths for non-Botnix applications
    "-Ddriverdir=${mesa.drivers.driverLink}/lib/dri:/usr/lib/dri:/usr/lib32/dri:/usr/lib/x86_64-linux-gnu/dri:/usr/lib/i386-linux-gnu/dri"
  ];

  passthru.tests = {
    # other drivers depending on libva and selected application users.
    # Please get a confirmation from the maintainer before adding more applications.
    inherit intel-compute-runtime intel-media-driver intel-vaapi-driver mpv vlc;
    pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;
  };

  meta = with lib; {
    description = "An implementation for VA-API (Video Acceleration API)";
    longDescription = ''
      VA-API is an open-source library and API specification, which provides
      access to graphics hardware acceleration capabilities for video
      processing. It consists of a main library (this package) and
      driver-specific acceleration backends for each supported hardware vendor.
    '';
    homepage = "https://01.org/linuxmedia/vaapi";
    changelog = "https://raw.githubusercontent.com/intel/libva/${finalAttrs.version}/NEWS";
    license = licenses.mit;
    maintainers = with maintainers; [ SuperSandro2000 ];
    pkgConfigModules = [ "libva" "libva-drm" ] ++ lib.optionals (!minimal) [
      "libva-glx" "libva-wayland" "libva-x11"
    ];
    platforms = platforms.unix;
  };
})
