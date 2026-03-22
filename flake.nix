{
  description = "zapret2 - DPI bypass tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        isLinux = pkgs.stdenv.isLinux;
      in
      {
        packages = {
          mdig = pkgs.stdenv.mkDerivation {
            pname = "mdig";
            version = "0.1.0";
            src = ./mdig;

            buildPhase = ''
              make mdig
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp mdig $out/bin/
            '';
          };

          ip2net = pkgs.stdenv.mkDerivation {
            pname = "ip2net";
            version = "0.1.0";
            src = ./ip2net;

            buildPhase = ''
              make ip2net
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp ip2net $out/bin/
            '';
          };
        } // pkgs.lib.optionalAttrs isLinux {
          nfqws2 = pkgs.stdenv.mkDerivation {
            pname = "nfqws2";
            version = "0.1.0";
            src = ./nfq2;

            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [
              pkgs.zlib
              pkgs.libnetfilter_queue
              pkgs.libnfnetlink
              pkgs.libmnl
              pkgs.libcap
              pkgs.luajit
            ];

            buildPhase = ''
              make nfqws2
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp nfqws2 $out/bin/
            '';
          };

          # The main blockcheck2 script with all dependencies wired in
          blockcheck2 = pkgs.writeShellScriptBin "blockcheck2" ''
            export PATH="${pkgs.lib.makeBinPath [
              self.packages.${system}.nfqws2
              self.packages.${system}.mdig
              self.packages.${system}.ip2net
              pkgs.curl
              pkgs.iptables
              pkgs.nmap       # for ncat
              pkgs.bind.host  # for 'host' command
              pkgs.coreutils
              pkgs.gnused
              pkgs.gnugrep
              pkgs.gawk
              pkgs.findutils
              pkgs.iproute2
              pkgs.procps
              pkgs.util-linux
              pkgs.bash
            ]}:$PATH"

            export NFQWS2="${self.packages.${system}.nfqws2}/bin/nfqws2"
            export MDIG="${self.packages.${system}.mdig}/bin/mdig"

            exec "${pkgs.bash}/bin/bash" "${self}/blockcheck2.sh" "$@"
          '';
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.pkg-config ];

          buildInputs = [
            pkgs.gnumake
            pkgs.zlib
            pkgs.luajit
          ] ++ pkgs.lib.optionals isLinux [
            pkgs.libnetfilter_queue
            pkgs.libnfnetlink
            pkgs.libmnl

            # Runtime deps for blockcheck2.sh
            pkgs.curl
            pkgs.iptables
            pkgs.nmap          # ncat
            pkgs.bind.host     # host/nslookup
            pkgs.iproute2
          ];

          shellHook = ''
            echo "zapret2 dev shell"
            echo "  Build:  make           (builds nfqws2, mdig, ip2net)"
            echo "  Run:    sudo ./blockcheck2.sh"
          '';
        };
      });
}
