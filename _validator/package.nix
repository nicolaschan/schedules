{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  gleam,
  erlang,
  rebar3,
  makeWrapper,
}:

let
  version = "1.0.0";

  # manifest.toml is already a lockfile: it pins every package's version and the
  # sha256 of its Hex tarball. Reading it here means the dependencies have one
  # source of truth and no hash to maintain by hand.
  #
  # Fetching each package separately rather than running `gleam deps download`
  # in a fixed-output derivation is deliberate. That command writes a
  # packages.toml whose key order is randomised per run, so its output hash is
  # not stable across machines. Gleam regenerates that file offline anyway.
  manifest = builtins.fromTOML (builtins.readFile ./manifest.toml);

  fetchPackage =
    package:
    fetchurl {
      url = "https://repo.hex.pm/tarballs/${package.name}-${package.version}.tar";
      sha256 = lib.toLower package.outer_checksum;
    };

  # Gleam looks for a tarball named after its own checksum, which is the value
  # manifest.toml already records. Handing it a populated cache lets it unpack
  # the dependencies through its normal path with no network.
  hexCache = runCommand "gleam-hex-cache-${version}" { } (
    ''
      mkdir -p "$out/hex/hexpm/packages"
    ''
    + lib.concatMapStrings (package: ''
      cp ${fetchPackage package} "$out/hex/hexpm/packages/${package.outer_checksum}.tar"
    '') manifest.packages
  );
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

  # Every tarball is already in the cache, so this needs no network.
  configurePhase = ''
    runHook preConfigure
    export HOME="$TMPDIR"
    mkdir -p "$HOME/.cache/gleam"
    cp -r ${hexCache}/. "$HOME/.cache/gleam/"
    chmod -R u+w "$HOME/.cache/gleam"
    gleam deps download
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
    mainProgram = "bell-validator";
  };
}
