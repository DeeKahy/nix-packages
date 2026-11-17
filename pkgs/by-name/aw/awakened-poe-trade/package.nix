{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeWrapper,
  undmg,
  electron,
  libxt,
  libxtst,
  commandLineArgs ? [ ],
}:

let
  sources = lib.importJSON ./sources.json;
  inherit (sources) version;
  pname = "awakened-poe-trade";
  releases = "https://github.com/SnosMe/awakened-poe-trade/releases/download/v${version}";

  meta = {
    description = "Path of Exile trading app for price checking";
    homepage = "https://github.com/SnosMe/awakened-poe-trade";
    downloadPage = "https://github.com/SnosMe/awakened-poe-trade/releases";
    changelog = "https://github.com/SnosMe/awakened-poe-trade/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "awakened-poe-trade";
  };

  passthru.updateScript = ./update.sh;

  # Same approach as nixpkgs: take app.asar out of the AppImage and run it
  # with nixpkgs' electron, so it works on any Linux architecture.
  linux = stdenv.mkDerivation (finalAttrs: {
    inherit
      pname
      version
      meta
      ;

    src = fetchurl {
      url = "${releases}/Awakened-PoE-Trade-${version}.AppImage";
      hash = sources.hashes.linux;
    };

    passthru = passthru // {
      appImageContents = appimageTools.extract { inherit (finalAttrs) pname version src; };
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [ makeWrapper ];

    installPhase = ''
      runHook preInstall

      contents=${finalAttrs.passthru.appImageContents}
      mkdir -p $out/bin $out/share/awakened-poe-trade $out/share/applications
      cp -a $contents/{locales,resources} $out/share/awakened-poe-trade/
      cp -a $contents/awakened-poe-trade.desktop $out/share/applications/
      cp -a $contents/usr/share/icons $out/share/

      substituteInPlace $out/share/applications/awakened-poe-trade.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=awakened-poe-trade'

      runHook postInstall
    '';

    postFixup = ''
      makeWrapper ${lib.getExe electron} $out/bin/awakened-poe-trade \
        --add-flags $out/share/awakened-poe-trade/resources/app.asar \
        --add-flags ${lib.escapeShellArg (lib.escapeShellArgs commandLineArgs)} \
        --prefix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            libxt
            libxtst
          ]
        }
    '';
  });

  # Upstream ships one universal .dmg for Intel and Apple Silicon.
  darwin = stdenv.mkDerivation {
    inherit
      pname
      version
      meta
      passthru
      ;

    src = fetchurl {
      url = "${releases}/Awakened-PoE-Trade-${version}-universal.dmg";
      hash = sources.hashes.darwin;
    };

    nativeBuildInputs = [
      makeWrapper
      undmg
    ];

    sourceRoot = ".";

    # Copy the bundle untouched; fixup would strip and rewrite its binaries.
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      app="$(find . -maxdepth 2 -name 'Awakened PoE Trade.app' -print -quit)"
      mkdir -p $out/Applications $out/bin
      cp -R "$app" $out/Applications/
      makeWrapper "$out/Applications/Awakened PoE Trade.app/Contents/MacOS/Awakened PoE Trade" \
        $out/bin/awakened-poe-trade \
        --add-flags ${lib.escapeShellArg (lib.escapeShellArgs commandLineArgs)}

      runHook postInstall
    '';
  };
in
if stdenv.hostPlatform.isDarwin then darwin else linux
