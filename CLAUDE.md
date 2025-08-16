# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Ceph is a distributed storage system providing object, block, and file storage in a unified system. This is a large C++ codebase (version 19.2.3) with Python components for management and testing.

## Build System

### Initial Setup
```bash
# Install dependencies (Debian/Ubuntu)
./install-deps.sh
apt install python3-routes

# Initialize git submodules (required)
git submodule update --init --recursive --progress
```

### Building Ceph
```bash
# Configure build (creates debug build by default)
./do_cmake.sh

# For production/performance builds
./do_cmake.sh -DCMAKE_BUILD_TYPE=RelWithDebInfo

# Build using ninja (from build/ directory)
cd build
ninja -j$(nproc)  # Use -j3 or similar if running out of memory (each job needs ~2.5GB RAM)

# Install vstart cluster for development
ninja install

# Build specific targets
ninja [target_name]
```

### Common CMake Options
- `-DWITH_RADOSGW=OFF` - Build without RADOS Gateway
- `-DWITH_CCACHE=ON` - Enable ccache (auto-detected if available)
- `-DWITH_SYSTEM_BOOST=ON` - Use system Boost instead of bundled

## Testing

### Unit Tests
```bash
cd build

# Run all tests in parallel
ninja
ctest -j$(nproc)

# Run specific test with verbose output
ctest -V -R [test_name_regex]

# Build and run only test targets
ninja check -j$(nproc)

# Run comprehensive test suite
./run-make-check.sh
```

### Test Development Cluster (vstart)
```bash
cd build
ninja vstart
../src/vstart.sh --debug --new -x --localhost --bluestore
./bin/ceph -s

# Example operations
./bin/rbd create foo --size 1000
./bin/rados -p foo bench 30 write

# Stop cluster
../src/stop.sh

# Control individual daemons
./bin/init-ceph restart osd.0
./bin/init-ceph stop
```

## Architecture

### Core Components
- **MON** (`src/mon/`) - Cluster monitors, maintain cluster map and state
- **OSD** (`src/osd/`) - Object Storage Daemons, store data on disks
- **MDS** (`src/mds/`) - Metadata servers for CephFS file system
- **MGR** (`src/mgr/`) - Manager daemons, provide monitoring and management
- **RGW** (`src/rgw/`) - RADOS Gateway, S3/Swift object storage interface

### Key Libraries
- **librados** (`src/librados/`) - Core RADOS object storage library
- **librbd** (`src/librbd/`) - RADOS Block Device library
- **libcephfs** (`src/libcephfs/`) - CephFS file system library
- **libradosstriper** (`src/libradosstriper/`) - Object striping library

### Storage Engines
- **BlueStore** (`src/os/bluestore/`) - Primary object store backend
- **FileStore** (legacy) - File system-based backend

### Key Subsystems
- **CRUSH** (`src/crush/`) - Placement algorithm and maps
- **Auth** (`src/auth/`) - Authentication and authorization
- **Messenger** (`src/msg/`) - Network messaging layer
- **Common** (`src/common/`) - Shared utilities and infrastructure

## Development Workflow

### Code Structure
- Each component has its own directory under `src/`
- Tests are in `src/test/` with subdirectories matching source structure
- CLI tools source in individual `.cc` files in `src/`
- Python tools in `src/pybind/`, `src/ceph-volume/`, `src/cephadm/`

### Key Build Artifacts
- Main binaries: `ceph-mon`, `ceph-osd`, `ceph-mds`, `ceph-mgr`, `radosgw`
- CLI tools: `ceph`, `rados`, `rbd`, `ceph-authtool`, etc.
- Libraries: `librados`, `librbd`, `libcephfs`

### Test Types
- **Unit tests**: GoogleTest framework, run with `ctest`
- **Integration tests**: Located in `qa/` directory, use Teuthology framework
- **CLI tests**: Shell-based tests in `src/test/cli/`
- **Functional tests**: Component-specific tests in `src/test/[component]/`

### Container Development
Container builds are supported via `ContainerBuild.md` for cross-platform development and CI.

## Development Notes

- Build system uses CMake with Ninja generator
- Primary language is C++17 with Python for management tools
- Uses extensive template metaprogramming and modern C++ features
- Large codebase (~1M+ lines) with complex interdependencies
- Memory requirements: ~2.5GB RAM per ninja build job
- Debug builds can be 5x slower than optimized builds