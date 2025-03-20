{ stdenv, autoPatchelfHook, curl }:
stdenv.mkDerivation {
  name = "f";
  nativeBuildInputs = [
    autoPatchelfHook
    stdenv.cc.cc.lib
  ];
  buildInputs = [ curl ];
  installPhase = "ls -lah";
  src = null;
  dontUnpack = true;
  buildPhase = ''
    mkdir -p $out/bin
    cp ${./djjr} $out/bin/djjr
  '';
}
