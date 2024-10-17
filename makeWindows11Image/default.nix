{ wfvm, fetchtorrent, callPackage }:
{ ... }@args: (wfvm.lib.makeWindowsImage {
  windowsImage = (fetchtorrent {
    backend = "rqbit";
    url = "magnet:?xt=urn:btih:86ABFFEFB9F9EE886A566CB9DA7929120727D0C9";
    hash = "sha256-CqpeDm2x8ptgd4Zy4C5B+ZjmskzlGa0s/aLbZVBUn5E=";
  }) + "/*.iso";
} // args).overrideAttrs (_: { passthru.runScript = callPackage ./run.nix {}; })
