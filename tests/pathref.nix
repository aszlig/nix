with import ./config.nix;

rec {

  reference = mkDerivation {
    name = "reference";
    builder = builtins.toFile "builder.sh" ''
      mkdir -p "$out/bin" "$out/lib"
      touch "$out/bin/foo" "$out/bin/bar"
      touch "$out/lib/libfoo.so"
      touch "$out/lib/libbar.so"
    '';
  };

  testPathRef = ref: mkDerivation {
    name = "test-pathref";
    inherit ref;
    builder = builtins.toFile "builder.sh" ''
      echo "$ref" > "$out"
    '';
  };

  good = [
    (testPathRef (reference => /bin/foo))
    (testPathRef (reference => /bin/bar))
    (testPathRef (reference => /lib/libfoo.so))
    (testPathRef (reference => /lib/libbar.so))
  ];

  bad = [
    (testPathRef (reference => /foo))
    (testPathRef (reference => /bar))
    (testPathRef (reference => /libfoo.so))
    (testPathRef (reference => /libbar.so))
    (testPathRef (reference => /nonexistent))
  ];
}
