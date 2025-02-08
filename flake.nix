{
  description = "Tie";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/22.05";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });
    in
    {
      overlay = self: super: {
        hsPkgs = super.haskell.packages.ghc902.override {
          overrides = hself: hsuper: {
            petstore-api = hsuper.callCabal2nix "petstore-api" ./example/generated { };
            openapi3 = hsuper.callCabal2nix "openapi3"
              (builtins.fetchGit {
                url = "https://github.com/alexbiehl/openapi3.git";
                rev = "4793b3c09f8c146161f7e78f8c0924bc9b0ec395";
                ref = "alex/aeson-2-support-for-extensions";
              })
              { };
          };
        };

        tie-example = self.hsPkgs.callCabal2nix "tie-example" ./example { };

        tie = self.hsPkgs.callCabal2nix "tie" ./. { };
      };

      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.tie;
          tie-example = pkgs.tie-example;
          dockerize-tie-example = pkgs.dockerTools.buildImage {
            name = "tie-example";
            config = {
              Config = [ "${pkgs.tie-example}/bin/tie-example" ];
            };
          };
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          libs = with pkgs; [
            zlib
          ];
        in
        {
          default = pkgs.hsPkgs.shellFor {
            packages = hsPkgs: [ ];
            buildInputs = with pkgs; [
              hsPkgs.cabal-install
              hsPkgs.cabal-fmt
              hsPkgs.ghcid
              hsPkgs.ghc
              treefmt
              nixpkgs-fmt
            ] ++ libs;
            shellHook = "export PS1='[$PWD]\n❄ '";
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath libs;
          };
        });
    };
}
