{
  description = "Nix flake for Ceph development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-py-bcrypt.url = "github:NixOS/nixpkgs/ed4db9c6c75079ff3570a9e3eb6806c8f692dc26";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, ... }@inputs: inputs.utils.lib.eachSystem [
    "x86_64-linux" "aarch64-linux"
  ] (system: let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [];
      config.allowUnfree = true; # For some dependencies if needed
    };
    pkgs-bcrypt = import inputs.nixpkgs-py-bcrypt {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    devShells.default = pkgs.mkShell rec {
      name = "ceph-dev-shell";

      nativeBuildInputs = with pkgs; [
        # Build system and compilers
        gcc13
          #pkgs-arrow-12.arrow-cpp
        arrow-cpp
        gnumake
        cmake
        ninja
        binutils
        pkg-config
        fuse
        ccache
        autoconf

        rdma-core

        # Code generation and utilities
        gperf
        patch
        git
        automake
        bison
        flex
        which
        coreutils
        gawk
        gnugrep
        gnused
        findutils
        procps
        sudo
        ragel
      ];

      buildInputs = with pkgs; [
        # Core C/C++ libraries
        boost
        brotli
        lz4
        expat
        libaio
        udev
        thrift
        rabbitmq-c
        rdkafka
        doxygen
        cyrus_sasl
        openldap
        #libblkid
        cryptsetup
        libnbd
        curl
        libcap
        libcap_ng
        fmt
        libnl
        oath-toolkit
        libtool
        libxml2
        ncurses
        icu
        snappy
        sqlite
        xfsprogs
        lmdb
        yaml-cpp
        re2
        zlib
        zstd
        openssl
        keyutils
        util-linux

        # Optional tracing libraries
        lttng-ust
        babeltrace

        # Other tools for testing/CI
        socat
        jq
        xmlstarlet
        hostname
        libselinux
        checkpolicy
        python311
        python311Packages.pip
        python311Packages.pyyaml
        python311Packages.cython
        python311Packages.sphinx
        python311Packages.setuptools
        python311Packages.prettytable
        python311Packages.python-dateutil
        python311Packages.requests
        pkgs-bcrypt.python311Packages.bcrypt
        python311Packages.packaging
        python311Packages.pyopenssl
        python311Packages.cherrypy
        python311Packages.jinja2
        python311Packages.natsort
        python311Packages.asyncssh
        python311Packages.werkzeug
        python311Packages.pecan
        lua5_4_compat
        nasm
      ];

      shellHook = let
        icon = "f308"; # Ceph icon
      in ''
        export CCACHE_DIR="$(pwd)/.ccache"
        mkdir -p $CCACHE_DIR
        export AS=nasm
        export LDFLAGS="-L${pkgs.brotli}/lib -lbrotlicommon $LDFLAGS"
      '';
    };

    packages.default = pkgs.callPackage ./default.nix {};
  });
}



