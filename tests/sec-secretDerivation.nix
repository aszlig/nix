with import ./config.nix;

let
  builder = builtins.toFile "builder.sh"
    ''
        umask 077
        mkdir $out
        chmod 700 $out
        echo 42 > $out/file
        umask 077
    '';
in

{
  public = mkDerivation {
    name = "public";
    inherit builder;
  };

  secret = mkDerivation {
    name = "secret";
    inherit builder;
    secret = true;
  };

  # This is used to attempt fetching secret files from the store.
  evilFetcher = { path }: mkDerivation {
    name = "evil-fetcher";
    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = "0101010101010101010101010101010101010101010101010101";
    builder = builtins.toFile "fetcher.sh" ''
      cat "${path}"
    '';
  };
}
