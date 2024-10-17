{ wfvm, fetchtorrent, callPackage }:
{ ... }@args: (wfvm.lib.makeWindowsImage {
  windowsImage = (fetchtorrent {
    url = "magnet:?xt=urn:btih:89e7e3f95f11f962c1e47dc95ccc24c99f385a68&dn=win-10-21-h-1-english-x-64_20210711&tr=http%3A%2F%2Fbt1.archive.org%3A6969%2Fannounce&tr=http%3A%2F%2Fbt2.archive.org%3A6969%2Fannounce&ws=http://ia601501.us.archive.org/10/items/&ws=https://archive.org/download/";
    hash = "";
  }) + "/Win10_21H1_English_x64.iso";
} // args).overrideAttrs (_: { passthru.runScript = callPackage ./run.nix {}; })
