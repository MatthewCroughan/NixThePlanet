{ haiku-jam,
  buildtools-src,
  haiku-src,
  stdenv,
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
stdenv.mkDerivation {
  src = haiku-src;
  name = "haiku";
  preConfigure = ''
    export HOME=$TMP
    export CC=${stdenv.cc.targetPrefix}cc
    git init
    git add .
    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"
    git commit -m "init"
  '';
  NIX_CFLAGS_COMPILE = "-Wno-error=format-security";
  configurePhase = ''
    runHook preConfigure
    cp -r ${buildtools-src} "$TMP/buildtools-src"
    chmod -R +w "$TMP/buildtools-src"
    ./configure \
      --cross-tools-source "$TMP/buildtools-src" \
      --build-cross-tools x86_64
    runHook postConfigure
  '';
  buildPhase = ''
    jam -q @nightly-anyboot
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

