{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    xc = {
      url = "github:joerdav/xc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    serve = {
      url = "github:a-h/serve";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, xc, serve }:
    let
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        system = system;
        pkgs = import nixpkgs {
          inherit system;
        };
      });

      # Build Docker containers.
      dockerUser = pkgs: pkgs.runCommand "user" { } ''
        mkdir -p $out/etc
        echo "user:x:1000:1000:user:/home/user:/bin/false" > $out/etc/passwd
        echo "user:x:1000:" > $out/etc/group
        echo "user:!:1::::::" > $out/etc/shadow
      '';
      caChains = pkgs: pkgs.stdenv.mkDerivation {
        name = "ca-chains";
        src = ./.;
        phases = [ "unpackPhase" "installPhase" ];
        installPhase = ''
          mkdir -p $out/etc/ssl/certs
          cat ca-chain.cert.pem ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > "$out/etc/ssl/certs/ca-bundle.crt"
        '';
      };
      dockerImage = { name, pkgs, system }: pkgs.dockerTools.buildImage {
        name = name;
        tag = "latest";

        copyToRoot = [
          # Remove coreutils and bash for a smaller container.
          pkgs.coreutils
          pkgs.bash
          # curl, to attempt to access the web server.
          pkgs.curl
          # CA certificates to access HTTPS sites.
          (caChains pkgs)
          pkgs.dockerTools.caCertificates
          (dockerUser pkgs)
        ];
        config = {
          Cmd = [ "/bin/bash" ];
          Env = [
            "CURL_CA_BUNDLE=${(caChains pkgs)}/etc/ssl/certs/ca-bundle.crt"
            "GIT_SSL_CAINFO=${(caChains pkgs)}/etc/ssl/certs/ca-bundle.crt"
            "SSL_CERT_FILE=${(caChains pkgs)}/etc/ssl/certs/ca-bundle.crt"
          ];
          User = "user:user";
        };
      };

      # Development tools used.
      devTools = { system, pkgs }: [
        xc.packages.${system}.xc
        serve.packages.${system}.default
      ];

      name = "app";
    in
    {
      # `nix build` builds the app.
      # `nix build .#docker-image` builds the Docker container.
      packages = forAllSystems ({ system, pkgs }: {
        docker-image = dockerImage { name = name; pkgs = pkgs; system = system; };
      });
      # `nix develop` provides a shell containing required tools.
      # Run `gomod2nix` to update the `gomod2nix.toml` file if Go dependencies change.
      devShells = forAllSystems ({ system, pkgs }: {
        default = pkgs.mkShell {
          buildInputs = (devTools { system = system; pkgs = pkgs; });
        };
      });
    };
}
