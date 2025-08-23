{
  description = "Nix flake for Ceph development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
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
    
    # Python configuration based on official Ceph package
    # Use bcrypt from older nixpkgs for compatibility
    python = pkgs.python311.override {
      packageOverrides = self: super: 
          let
            bcryptOverrideVersion = "4.0.1";
          in
            {
            # Ceph does not support the following yet:
            # * `bcrypt` > 4.0
            # * `cryptography` > 40
            # See:
            # * https://github.com/NixOS/nixpkgs/pull/281858#issuecomment-1899358602
            # * Upstream issue: https://tracker.ceph.com/issues/63529
            #   > Python Sub-Interpreter Model Used by ceph-mgr Incompatible With Python Modules Based on PyO3
            # * Moved to issue: https://tracker.ceph.com/issues/64213
            #   > MGR modules incompatible with later PyO3 versions - PyO3 modules may only be initialized once per interpreter process

            bcrypt = super.bcrypt.overridePythonAttrs (old: rec {
              pname = "bcrypt";
              version = bcryptOverrideVersion;
              src = pkgs.fetchPypi {
                inherit pname version;
                hash = "sha256-J9N1kDrIJhz+QEf2cJ0W99GNObHskqr3KvmJVSplDr0=";
              };
              cargoRoot = "src/_bcrypt";
              cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                inherit src;
                sourceRoot = "${pname}-${version}/${cargoRoot}";
                name = "${pname}-${version}";
                hash = "sha256-lDWX69YENZFMu7pyBmavUZaalGvFqbHSHfkwkzmDQaY=";
              };
            });
          };
      };
    
    # Comprehensive Python environment for Ceph  
    # Use our overridden python with fixed bcrypt
    ceph-python-env = python.withPackages (ps: with ps; [
      # Build time requirements
      pip
      cython_0
      setuptools
      sphinx
      virtualenv
      
      # Core dependencies (from debian/control)
      pyyaml
      bcrypt
      cherrypy
      influxdb
      jinja2
      kubernetes
      markupsafe
      natsort
      numpy
      pecan
      prettytable
      pyjwt
      pyopenssl
      python-dateutil
      requests
      routes
      scikit-learn
      scipy
      werkzeug
      
      # Required manager modules (src/pybind/mgr/requirements-required.txt)
      cryptography
      jsonpatch
      
      # CephFS shell dependencies
      cmd2
      colorama
      
      # Additional dependencies
      packaging
      asyncssh
    ]);
    inherit (ceph-python-env.python) sitePackages; 
    # Boost with Python support enabled
    boost' = pkgs.boost183.override {
      enablePython = true;
      inherit python;
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
        python.pkgs.python # for the toPythonPath function
        python.pkgs.wrapPython
        
      ];

      buildInputs = with pkgs; [
        # Build tools
        ccache
        # Adding `ceph-python-env` here adds the env's `site-packages` to `PYTHONPATH` during the build.
        # This is important, otherwise the build system may not find the Python deps and then
        # silently skip installing ceph-volume and other Ceph python tools.
        ceph-python-env
        
        # Core C/C++ libraries
        boost'  # Use our Boost with Python support
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
        fuse
        libedit
        expat
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
        pythonPath = [
          ceph-python-env
          "${placeholder "out"}/${ceph-python-env.sitePackages}"
        ];

      shellHook = let
        icon = "f308"; # Ceph icon
      in ''
        export CCACHE_DIR="$(pwd)/.ccache"
        mkdir -p $CCACHE_DIR
        export AS=nasm
        export LDFLAGS="-L${pkgs.brotli}/lib -lbrotlicommon $LDFLAGS"
        
        # Set Python environment for Ceph build
        
        # Create wrapper for scripts with hardcoded shebangs (NixOS compatibility)
        mkdir -p .nix-wrappers
        cat > .nix-wrappers/build-with-container.py << 'WRAPPER'
#!/usr/bin/env bash
exec python3 ./src/script/build-with-container.py "$@"
WRAPPER
        chmod +x .nix-wrappers/build-with-container.py
        
        # Add wrapper directory and build/bin to PATH for convenience
        export PATH="$(pwd)/.nix-wrappers:$(pwd)/build/bin:$PATH"
          cat <<EOF
╔══════════════════════════════════════════════╗
║       🐙 Ceph Development Environment        ║
╚══════════════════════════════════════════════╝
Development:
./do_cmake.sh -DWITH_MANPAGE=OFF -DWITH_BABELTRACE=OFF -DWITH_MGR_DASHBOARD_FRONTEND=OFF -DWITH_SYSTEM_ARROW=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
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



