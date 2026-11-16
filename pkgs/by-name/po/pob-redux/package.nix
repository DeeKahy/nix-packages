{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  dbus,
  glib-networking,
  gtk3,
  libsoup_3,
  libx11,
  libxi,
  webkitgtk_4_1,
}:

let
  sources = lib.importJSON ./sources.json;
  inherit (sources) version;

  # Release asset suffix for each platform. Keep in sync with update.sh.
  assets = {
    x86_64-linux = "amd64.deb";
    aarch64-linux = "arm64.deb";
    aarch64-darwin = "aarch64.app.tar.gz";
  };

  system = stdenv.hostPlatform.system;
  asset = assets.${system} or (throw "pob-redux: unsupported system ${system}");

  meta = {
    description = "Path of Building for Path of Exile 1 and 2, rebuilt";
    longDescription = ''
      A desktop build planner for Path of Exile 1 and 2. It runs Path of
      Building Community's own calculation code, so every number matches
      Path of Building, and it opens the same build files.
    '';
    homepage = "https://pobredux.com";
    downloadPage = "https://github.com/pobredux/pob-redux/releases";
    changelog = "https://github.com/pobredux/pob-redux/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
    platforms = builtins.attrNames assets;
    mainProgram = "pob-redux";
  };

  src = fetchurl {
    url = "https://github.com/pobredux/pob-redux/releases/download/v${version}/PoB.Redux_${version}_${asset}";
    hash = sources.hashes.${system};
  };

  passthru.updateScript = ./update.sh;

  linux = stdenv.mkDerivation {
    pname = "pob-redux";
    inherit
      version
      src
      meta
      passthru
      ;

    nativeBuildInputs = [
      autoPatchelfHook
      dpkg
      wrapGAppsHook3
    ];

    buildInputs = [
      alsa-lib
      dbus
      glib-networking
      gtk3
      libsoup_3
      stdenv.cc.cc.lib
      webkitgtk_4_1
    ];

    # Loaded with dlopen at runtime, so autoPatchelf cannot see them.
    runtimeDependencies = [
      libx11
      libxi
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r usr/bin usr/lib usr/share $out/

      # Tauri finds its bundled resources at <exe>/../lib/<productName>,
      # so the "PoB Redux" directory has to stay next to bin/.
      mv "$out/share/applications/PoB Redux.desktop" $out/share/applications/pob-redux.desktop

      runHook postInstall
    '';
  };

  darwin = stdenv.mkDerivation {
    pname = "pob-redux";
    inherit
      version
      src
      meta
      passthru
      ;

    nativeBuildInputs = [ makeWrapper ];

    sourceRoot = ".";

    # The bundle is ad-hoc signed upstream. Stripping or patching anything
    # inside it would break the signature and macOS would refuse to run it.
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications $out/bin
      cp -R "PoB Redux.app" $out/Applications/
      makeWrapper "$out/Applications/PoB Redux.app/Contents/MacOS/pob-redux" $out/bin/pob-redux

      runHook postInstall
    '';
  };
in
if stdenv.hostPlatform.isDarwin then darwin else linux
