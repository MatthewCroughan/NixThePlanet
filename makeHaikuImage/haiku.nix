# https://www.haiku-os.org/docs/develop/packages/Bootstrapping.html
{ haiku-jam,
  buildtools-src,
  haiku-src,
  haikuports-cross-src,
  haikuports-src,
  haikuporter-src,
  gcc13Stdenv,
  python3,
  perl,
  autoconf,
  automake,
  bison,
  bc,
  flex,
  gawk,
  mtools,
  nasm,
  texinfo,
  unzip,
  wget,
  xorriso,
  zip,
  zlib,
  zstd,
  git
}:
gcc13Stdenv.mkDerivation {
  src = haiku-src;
  name = "haiku";
  preConfigure = ''
    export HAIKU_REVISION=hrev69696
    export HAIKU_NO_DOWNLOADS=1
    export HOME=$TMP
    export CC=${gcc13Stdenv.cc.targetPrefix}cc
    export CCFLAGS+=-I/build/source/generated/cross-tools-x86_64/x86_64-unknown-haiku/include/c++/13.3.0/
    git init
    git add .
    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"
    git commit -m "init"
    mkdir generated.myarch
  '';
  NIX_CFLAGS_COMPILE = "-Wno-error=format-security";
  configurePhase = ''
    runHook preConfigure
    cp -r ${buildtools-src} "$TMP/buildtools-src"
    cp -r ${haikuporter-src} "$TMP/haikuporter"
    cp -r ${haikuports-src} "$TMP/haikuports"
    cp -r ${haikuports-cross-src} "$TMP/haikuports.cross"
    chmod -R +w "$TMP/buildtools-src"

    chmod -R +w "$TMP/haikuporter"
    patchShebangs "$TMP/haikuporter/haikuporter"
    patchShebangs "$TMP/haikuporter/haikuporter.py"

    chmod -R +w "$TMP/haikuports"
    chmod -R +w "$TMP/haikuports.cross"
    cd generated.myarch
    ../configure \
      -j32 \
      --build-cross-tools x86_64 \
      --cross-tools-source "$TMP/buildtools-src" \
      --bootstrap "$TMP/haikuporter/haikuporter" "$TMP/haikuports.cross" "$TMP/haikuports" \
      --no-downloads
    runHook postConfigure
  '';
  buildPhase = ''
    jam -j32 -q @bootstrap-raw
  '';
  nativeBuildInputs = [
    git
    haiku-jam
    perl

    # https://www.haiku-os.org/guides/building/pre-reqs
    python3
    autoconf
    automake
    bison
    bc
    flex
    gawk
    mtools
    nasm
    texinfo
    unzip
    wget
    xorriso
    zip
    zlib
    zstd
  ];
}

