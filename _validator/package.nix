{
  lib,
  stdenvNoCC,
  gleam,
  erlang,
  rebar3,
  cacert,
  makeWrapper,
}:

let
  version = "1.0.0";

  # Only these two files decide what gets downloaded, so keeping the source
  # narrow means editing the validator does not refetch the dependencies.
  manifest = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./gleam.toml
      ./manifest.toml
    ];
  };

  # The Hex packages. This is the one derivation allowed to reach the network,
  # so its output is pinned by hash. manifest.toml already fixes the versions
  # and their checksums, so the result is stable.
  dependencies = stdenvNoCC.mkDerivation {
    pname = "bell-validator-deps";
    inherit version;
    src = manifest;

    nativeBuildInputs = [
      gleam
      cacert
    ];

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      gleam deps download
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r build/packages "$out"
      runHook postInstall
    '';

    dontFixup = true;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-8RBHD4My7KQ5UkQLkV1nX8M5JbOBUkjtzp3aJIXx2Is=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "bell-validator";
  inherit version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./gleam.toml
      ./manifest.toml
      ./src
      ./test
    ];
  };

  nativeBuildInputs = [
    gleam
    erlang
    rebar3
    makeWrapper
  ];

  # Dependencies are already on disk, so the build itself needs no network.
  configurePhase = ''
    runHook preConfigure
    export HOME="$TMPDIR"
    mkdir -p build
    cp -r ${dependencies} build/packages
    chmod -R u+w build
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    gleam export erlang-shipment
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    gleam test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec" "$out/bin"
    cp -r build/erlang-shipment/. "$out/libexec/"
    makeWrapper "$out/libexec/entrypoint.sh" "$out/bin/bell-validator" \
      --add-flags run \
      --prefix PATH : ${lib.makeBinPath [ erlang ]}
    runHook postInstall
  '';

  meta = {
    description = "Validates the bell.plus schedule data format";
    homepage = "https://github.com/nicolaschan/schedules";
    licence = lib.licences.mit or null;
    mainProgram = "bell-validator";
  };
}
