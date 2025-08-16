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
  in let
    python3WithPackages = pkgs.python311.withPackages (ps: with ps; [
      pip
      pyyaml
      cython
      sphinx
      setuptools
      prettytable
      python-dateutil
      requests
      pkgs-bcrypt.python311Packages.bcrypt
      packaging
      pyopenssl
      cherrypy
      jinja2
      natsort
      asyncssh
      werkzeug
      pecan
    ]);
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
        ragel
        clang-tools
        
        # Python with packages
        python3WithPackages
      ];

      buildInputs = with pkgs; [
        # Build tools
        ccache
        
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
        
        # Create wrapper for scripts with hardcoded shebangs (NixOS compatibility)
        mkdir -p .nix-wrappers
        cat > .nix-wrappers/build-with-container.py << 'WRAPPER'
#!/usr/bin/env bash
exec ${python3WithPackages}/bin/python3 ./src/script/build-with-container.py "$@"
WRAPPER
        chmod +x .nix-wrappers/build-with-container.py
        
        # Add wrapper directory to PATH for convenience
        export PATH="$(pwd)/.nix-wrappers:$PATH"
          cat <<EOF
╔══════════════════════════════════════════════╗
║       🐙 Ceph Development Environment        ║
╚══════════════════════════════════════════════╝
Development:
./do_cmake.sh -DWITH_MANPAGE=OFF -DWITH_BABELTRACE=OFF -DWITH_MGR_DASHBOARD_FRONTEND=OFF -DWITH_SYSTEM_ARROW=ON
cmake --build build

Container Build:
# Build Ceph with container (includes building binaries and creating Docker image)
# Note: On NixOS, use 'build-with-container.py' directly (wrapper in PATH)
build-with-container.py -d ubuntu22.04 -e packages

# Alternative options:
# - Build only: build-with-container.py -d ubuntu22.04 -e build
# - Interactive: build-with-container.py -d ubuntu22.04 -e interactive
# - Custom build dir: build-with-container.py -d ubuntu22.04 -b build.custom -e build
# - CentOS build: build-with-container.py -d centos9 -e packages

# On non-NixOS systems, use: python3 ./src/script/build-with-container.py [options]

Available commands:
- ccache stats    # Check ccache statistics
- ninja -C build  # Build the project
EOF
      '';
    };

    packages.default = pkgs.callPackage ./default.nix {};
  });
}



