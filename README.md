# devcon-cpp

**A productiZimworX Victoria Falls Technology Center on-ready, multi-stage OCI container image for C++ development — with native and cross-compilation toolchains, gRPC, GoogleTest, and a complete VS Code Dev Container configuration.**

[![CI](https://github.com/bmigeri/devcon-cpp/actions/workflows/build-push.yaml/badge.svg)](https://github.com/bmigeri/devcon-cpp/actions/workflows/build-push.yaml)
[![Docker Pulls](https://img.shields.io/docker/pulls/bmigeri/devcon-cpp)](https://hub.docker.com/r/bmigeri/devcon-cpp)
[![Image Size](https://img.shields.io/docker/image-size/bmigeri/devcon-cpp/latest-runtime)](https://hub.docker.com/r/bmigeri/devcon-cpp)
[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange)](https://hub.docker.com/_/ubuntu)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Table of Contents

- [Why this image?](#why-this-image)
- [Quick start](#quick-start)
- [What's inside](#whats-inside)
- [Image tag reference](#image-tag-reference)
- [Build stage architecture](#build-stage-architecture)
- [Environment variables](#environment-variables)
- [VS Code Dev Container](#vs-code-dev-container)
- [Cross-compilation](#cross-compilation)
- [Code style](#code-style)
- [CI/CD pipeline](#cicd-pipeline)
- [Security posture](#security-posture)
- [Local development and contributing](#local-development-and-contributing)
- [Makefile reference](#makefile-reference)
- [Repository structure](#repository-structure)
- [Related resources](#related-resources)

---

## Why this image?

Building a consistent C++ development environment is deceptively hard. Compilers, build systems, static analysis tools, debugging tools, and third-party libraries like gRPC all need to work together — across developer machines, CI runners, and potentially multiple target architectures. This project solves that problem once, reproducibly, and publishes the result as a set of versioned OCI images.

Every image variant is built from a single `Containerfile` using multi-stage builds. Builder stages compile gRPC and GoogleTest from source to guarantee version precision and ABI compatibility; those compiled artifacts are then copied into the slim final images. The result is a set of images that are both comprehensive and lean.

### Choosing the right variant

Four images are published. Pick the one that matches your use case:

| I need... | Use this image |
|---|---|
| Interactive C++ development with gRPC support in VS Code | `latest-development` |
| Interactive C++ development without gRPC in VS Code | `latest-development-slim` |
| Lean CI/CD build agent with gRPC | `latest-runtime` |
| Lean CI/CD build agent without gRPC | `latest-runtime-slim` |

**Runtime vs development**: The `runtime` images contain compilers, build tools, code quality tools, and libraries — everything needed to compile and test C++ code in a CI pipeline. The `development` images extend this with a larger suite of debugging, profiling, documentation, and editor tooling designed for interactive work inside VS Code.

**With gRPC vs slim**: gRPC (with protobuf, abseil-cpp, and the compiler plugins) adds meaningful image size because it is compiled from source to ensure ABI compatibility. If your project does not use gRPC, use a slim variant to avoid carrying that weight in every container pull and layer cache miss.

> **Recommendation for new projects**: Start with `latest-development-slim` in your `devcontainer.json`. Switch to `latest-development` only when your project actually needs gRPC.

---

## Quick start

### Option A — VS Code Dev Container (recommended for local development)

This is the recommended workflow. Your editor, tools, and build environment all run inside the container, giving every team member an identical setup.

**Prerequisites**: [Docker Desktop](https://www.docker.com/products/docker-desktop/), [VS Code](https://code.visualstudio.com/), and the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

1. Clone this repository:

   ```bash
   git clone https://github.com/bmigeri/cpp-devcontainers.git
   cd cpp-devcontainers
   ```

2. Initialize the persistent Docker volumes (run once per machine):

   ```bash
   ./init-volumes.sh
   ```

   This creates two named volumes — one for VS Code extensions and one for build cache — so that container rebuilds do not wipe your installed extensions or invalidate your ccache.

3. Open the repository in VS Code, then select **Reopen in Container** when prompted (or press `F1` and search for that command).

VS Code will pull `bmigeri/devcon-cpp:latest-development`, start the container, and automatically install all configured extensions. The `postCreateCommand` prints your compiler and CMake versions in the terminal to confirm the environment is working.

> For projects that do not need gRPC, change the `"image"` value in `devcontainer.json` from `latest-development` to `latest-development-slim` before opening in container.

---

### Option B — Pull and run directly

```bash
# Interactive shell with your current directory mounted as /workspace
docker run -it --rm \
  -v "$(pwd):/workspace" \
  bmigeri/devcon-cpp:latest-development

# Slim variant (no gRPC)
docker run -it --rm \
  -v "$(pwd):/workspace" \
  bmigeri/devcon-cpp:latest-development-slim
```

---

### Option C — Build all variants locally

```bash
# Run first-time setup (configures Docker credentials, git hooks, and example projects)
./setup.sh

# Build all four published image variants
make build-all

# Validate the runtime image (runs compiler and tool checks inside the container)
make test
```

Build a single variant with overrides:

```bash
make build TARGET=development-slim TAG=v2.0
```

---

## What's inside

### All images (`runtime-base` layer)

Every published image is built on Ubuntu 24.04 LTS and includes the following.

**OS and runtime**
- Ubuntu 24.04 LTS (Noble Numbat)
- libssl3, zlib1g

**Compilers**
- GCC/G++ (native x86_64)
- `gcc-arm-linux-gnueabihf` / `g++-arm-linux-gnueabihf` (ARM hard-float cross-compiler)
- `gcc-aarch64-linux-gnu` / `g++-aarch64-linux-gnu` (ARM 64-bit cross-compiler)

**Build tools**
- CMake (system package), Ninja, pkg-config, git

**Code quality**
- clangd, clang-format, clang-tidy, cppcheck

**Debugger**
- gdb

**Libraries**
- GoogleTest v1.14.0 (GTest + GMock), built from source at `/opt/gtest`
- libjsoncpp-dev

**Cross-compilation toolchains**
- CMake toolchain files at `/opt/toolchains/` (`arm-linux-gnueabihf.cmake`, `aarch64-linux-gnu.cmake`)
- CMake kit definitions at `/opt/toolchains/cmake-kits.json`

**Shell conveniences**
- `ll` alias, `cmake-debug` and `cmake-release` aliases
- bash-completion, curl, wget, sudo

**User and workspace**
- Non-root user `developer` (UID 1000, full sudo access)
- Working directory `/workspace`

---

### `runtime` additionally includes

- **gRPC v1.78.1** compiled from source at `/opt/grpc`, including:
  - protobuf and abseil-cpp (bundled)
  - `protoc` (protobuf compiler)
  - `grpc_cpp_plugin` (code generator for C++ gRPC services)

---

### `development` and `development-slim` additionally include

These images extend `runtime-base` with tooling for interactive development.

**CMake**
- CMake 4.2.1 binary at `/opt/cmake` — replaces the system CMake, symlinked to `/usr/local/bin`

**Extended debuggers and profiling**
- lldb, gdb-multiarch
- valgrind, strace, perf-tools-unstable

**Documentation**
- doxygen, graphviz

**Python**
- python3, python3-pip

**Static analysis**
- iwyu (Include What You Use)

**Network tools**
- netcat, iputils-ping

**Editors**
- vim, nano

`development` includes gRPC; `development-slim` does not.

---

## Image tag reference

Four images are published for every push to `main`. Each receives two tags: a stable floating tag and an immutable SHA-pinned tag.

| Image | Stable tag | Immutable tag | gRPC | Dev tools |
|---|---|---|---|---|
| runtime | `latest-runtime` | `sha-<sha>-runtime` | Yes | No |
| runtime-slim | `latest-runtime-slim` | `sha-<sha>-runtime-slim` | No | No |
| development | `latest-development` | `sha-<sha>-development` | Yes | Yes |
| development-slim | `latest-development-slim` | `sha-<sha>-development-slim` | No | Yes |

On semver releases (tags matching `v*`), additional tags are published: `v1.2.3-{target}` and `1.2-{target}`.

**Pinning for production**: Use the immutable `sha-<sha>-{target}` tag in CI pipelines and production workloads. The `latest-*` tags are convenient for local development but will move on every push to `main`.

```bash
# Stable — updates automatically on every main push
docker pull bmigeri/devcon-cpp:latest-runtime

# Pinned to a specific build — reproducible and auditable
docker pull bmigeri/devcon-cpp:sha-a1b2c3d-runtime
```

---

## Build stage architecture

The `Containerfile` defines 9 stages. Builder stages compile dependencies from source and are discarded — their outputs are copied into the final published images, keeping those images lean.

```
ubuntu:24.04 ──→ base-builder ──→ grpc-builder   (builds gRPC v1.78.1  → /opt/grpc)
                            └──→ gtest-builder  (builds GTest v1.14.0 → /opt/gtest)

ubuntu:24.04 ──→ runtime-base ──→ runtime-slim   [PUBLISHED] no gRPC
                             ├──→ runtime         [PUBLISHED] + gRPC
                             └──→ dev-tools-base ──→ development       [PUBLISHED] + gRPC + dev tools
                                                  └──→ development-slim [PUBLISHED] no gRPC + dev tools
```

| Stage | Base | Purpose | Published |
|---|---|---|---|
| `base-builder` | ubuntu:24.04 | Common build tools — cmake, ninja, gcc, git | No |
| `grpc-builder` | base-builder | Compiles gRPC v1.78.1 from source into `/opt/grpc` | No |
| `gtest-builder` | base-builder | Compiles GoogleTest v1.14.0 from source into `/opt/gtest` | No |
| `runtime-base` | ubuntu:24.04 | Packages, GoogleTest, cross-compilers, user setup — no gRPC | No |
| `runtime-slim` | runtime-base | Thin runtime image — no gRPC | Yes |
| `runtime` | runtime-base | Adds gRPC on top of runtime-base | Yes |
| `dev-tools-base` | runtime-base | Shared dev toolset layer — lldb, valgrind, doxygen, CMake 4.2.1 | No |
| `development` | dev-tools-base | Full dev image — dev tools plus gRPC | Yes |
| `development-slim` | dev-tools-base | Slim dev image — dev tools, no gRPC | Yes |

**Why compile gRPC and GoogleTest from source?** Pre-packaged versions from Ubuntu's APT repositories often lag behind upstream by one or more major versions and may have been compiled with different ABI or feature flags. Building from source gives precise version control and ensures full ABI compatibility with your code.

**Why does `dev-tools-base` not include gRPC?** This avoids duplicating the gRPC layer across two published images. Each leaf stage (`development`, `development-slim`) handles gRPC inclusion independently, keeping the Containerfile DRY and the layer graph efficient.

---

## Environment variables

These variables are set inside every running container. Build tools, CMake's `find_package`, and `pkg-config` all read them automatically — you do not need to configure them in your `CMakeLists.txt` or shell profile.

### `runtime-slim` (GoogleTest only)

```
PKG_CONFIG_PATH=/opt/gtest/lib/pkgconfig
LD_LIBRARY_PATH=/opt/gtest/lib
CMAKE_PREFIX_PATH=/opt/gtest
```

### `runtime` and `development` (GoogleTest + gRPC)

```
PKG_CONFIG_PATH=/opt/grpc/lib/pkgconfig:/opt/gtest/lib/pkgconfig
LD_LIBRARY_PATH=/opt/grpc/lib:/opt/gtest/lib
PATH=/opt/grpc/bin:$PATH
CMAKE_PREFIX_PATH=/opt/grpc:/opt/gtest
```

`PATH` is extended so that `protoc` and `grpc_cpp_plugin` are available directly from the shell, which gRPC's CMake code-generation step requires.

> **Note on safety**: Environment variables use explicit values without trailing colons. Trailing colons in `LD_LIBRARY_PATH` cause the dynamic linker to search the current working directory, which is a known privilege escalation vector (CWE-426). The values set here are safe.

---

## VS Code Dev Container

The `devcontainer.json` at the repository root configures a complete C++ development environment inside the container.

### Key settings

| Setting | Value | Purpose |
|---|---|---|
| Image | `bmigeri/devcon-cpp:latest-development` | Full dev image with gRPC |
| `initializeCommand` | `./init-volumes.sh` | Creates and permissions volumes before the container starts |
| `remoteUser` | `developer` | Runs as non-root user |
| `CMAKE_EXPORT_COMPILE_COMMANDS` | `1` | Writes `compile_commands.json` so clangd gets an accurate index |
| `cmake.additionalKits` | `/opt/toolchains/cmake-kits.json` | Enables x86_64, armhf, aarch64 kit picker in the status bar |
| `editor.formatOnSave` | `true` | Auto-formats with clang-format on every save |
| `SYS_PTRACE` capability | enabled | Required for lldb and gdb to attach to running processes |

### Persistent volumes

Two named Docker volumes are mounted so that state survives container rebuilds:

| Volume name | Mount point | Purpose |
|---|---|---|
| `cpp-dev-vscode-server` | `/home/developer/.vscode-server` | VS Code extensions — avoids re-downloading on every rebuild |
| `cpp-dev-cache` | `/home/developer/.cache` | Build cache, ccache, pip cache |

Run `./init-volumes.sh` once on each machine to create these volumes with correct ownership before opening the container for the first time. `devcontainer.json` also runs this script automatically via `initializeCommand` each time VS Code initializes the container configuration.

### Automatically installed extensions

| Extension | Purpose |
|---|---|
| `ms-vscode.cpptools` | IntelliSense, navigation, debugging |
| `ms-vscode.cmake-tools` | CMake configure/build/test integration |
| `ms-vscode.cpptools-extension-pack` | C++ extension bundle |
| `twxs.cmake` | CMake syntax highlighting |
| `llvm-vs-code-extensions.vscode-clangd` | clangd language server (accurate, fast) |
| `vadimcn.vscode-lldb` | LLDB debugger UI |
| `xaver.clang-format` | Format-on-save integration |
| `notskm.clang-tidy` | Inline clang-tidy diagnostics |
| `cschlosser.doxdocgen` | Doxygen comment generation |
| `DrBlury.protobuf-vsc` | Protobuf syntax highlighting |
| `jeff-hykin.better-cpp-syntax` | Improved C++ syntax highlighting |
| `aaron-bond.better-comments` | Colour-coded comment annotations |
| `streetsidesoftware.code-spell-checker` | Spell checking in source files |

### Building from the Containerfile instead of pulling

If you want to iterate on the Containerfile itself, uncomment the `"build"` block in `devcontainer.json` and comment out the `"image"` line:

```jsonc
// devcontainer.json
"build": {
   "dockerfile": "Containerfile",
   "target": "development",
   "args": {
      "BUILD_JOBS": "8"
   },
   "context": "."
},
// "image": "bmigeri/devcon-cpp:latest-development",
```

---

## Cross-compilation

CMake toolchain files for ARM targets are installed at `/opt/toolchains/` inside every image variant.

### ARM hard-float (armhf — Cortex-A, 32-bit)

```bash
mkdir build-armhf && cd build-armhf
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=/opt/toolchains/arm-linux-gnueabihf.cmake \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release
ninja
```

### ARM 64-bit (aarch64)

```bash
mkdir build-aarch64 && cd build-aarch64
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=/opt/toolchains/aarch64-linux-gnu.cmake \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release
ninja
```

### CMake kit picker in VS Code

When working inside the Dev Container, the CMake Tools extension reads `/opt/toolchains/cmake-kits.json` and offers three kits in the status bar:

- **GCC x86_64** — native compilation (`/usr/bin/gcc`, `/usr/bin/g++`)
- **GCC ARM 32-bit (armhf)** — cross-compilation (`arm-linux-gnueabihf-gcc/g++`)
- **GCC ARM 64-bit (aarch64)** — cross-compilation (`aarch64-linux-gnu-gcc/g++`)

Select a kit from the status bar to reconfigure CMake for that target architecture. The toolchain file is applied automatically based on the kit definition.

> **Gotcha**: After switching kits, delete the `build/` directory or run CMake: Delete Cache and Reconfigure from the VS Code command palette. CMake caches the previous compiler path and will error if you attempt to reconfigure in-place with a different toolchain.

---

## Code style

All C++ source should be formatted with clang-format using the Google style base with these overrides:

| Setting | Value |
|---|---|
| `BasedOnStyle` | Google |
| `IndentWidth` | 2 |
| `ColumnLimit` | 80 |
| `PointerAlignment` | Left |
| `BreakBeforeBraces` | Attach |
| `SortIncludes` | CaseSensitive |

The full configuration lives in `.clang-format` at the repository root. VS Code applies it automatically on every save (`editor.formatOnSave: true`).

A git pre-commit hook, installed by `./setup.sh`, formats all staged `.cpp` and `.h` files with clang-format before each commit. This prevents unformatted code from entering the history.

To format a file manually:

```bash
clang-format -i path/to/file.cpp
```

---

## CI/CD pipeline

The pipeline is defined in `.github/workflows/build-push.yaml`.

### Triggers

| Event | Condition |
|---|---|
| Push to `main` or `develop` | Only when `Containerfile`, `toolchains/**`, or the workflow file changes |
| Semver tag (`v*`) | Always |
| `workflow_dispatch` | Manual trigger with optional `push_image` toggle |

Concurrent runs on the same branch are cancelled automatically, preventing redundant builds from stacking up.

### Job 1: build (matrix: 4 targets)

For each of `runtime`, `runtime-slim`, `development`, `development-slim`:

1. Set up Docker BuildKit v0.19 (pinned for reproducibility).
2. Extract metadata — branch, SHA, and semver tags — via `docker/metadata-action`.
3. Build and push via `docker/build-push-action` with:
   - `provenance: true` — attaches a SLSA provenance attestation to the image manifest.
   - `sbom: true` — attaches a Docker-native SBOM attestation to the manifest.
   - Registry-backed layer cache (`buildcache-{target}` tags) for fast incremental builds.
4. **Validation test** (runtime target, push events only): runs compiler and tool checks inside the freshly pushed `latest-runtime` image to confirm the build is functional.
5. **Trivy scan** (push events): scans `latest-{target}` for CRITICAL and HIGH CVEs, uploads SARIF results to the GitHub Security tab.
6. **Trivy config scan** (PR events): lints the Containerfile for misconfigurations before merging.

### Job 2: sbom (matrix: 4 targets x 2 formats)

Runs after `build` on push events. Uses Syft (`anchore/sbom-action`) — not Trivy — for authoritative SBOM generation. Syft provides superior package detection accuracy (~95-98%); Trivy is kept dedicated to vulnerability scanning.

Generates 8 SBOM artifacts:

- **SPDX-JSON** (`.spdx.json`) — for NIST and Executive Order 14028 compliance.
- **CycloneDX-JSON** (`.cdx.json`) — for OWASP and SLSA compliance.

SBOMs are uploaded as workflow artifacts and submitted to the GitHub Dependency Graph (`dependency-snapshot: true`).

### Job 3: update-readme

Runs after `build` on pushes to `main` only. Syncs `README.md` to the Docker Hub repository description using `peter-evans/dockerhub-description`.

### Required GitHub secrets

| Secret | Purpose |
|---|---|
| `DOCKER_USERNAME` | Docker Hub username for authentication |
| `DOCKER_PASSWORD` | Docker Hub password or access token |

Set these at `https://github.com/bmigeri/devcon-cpp/settings/secrets/actions`.

---

## Security posture

**Non-root user by default**: All published images run as `developer` (UID 1000). The user has `sudo` access for tasks that require elevation, but normal builds and tests run without root.

**Root-owned toolchain binaries**: The container switches to root for the `COPY` instruction when placing compiled libraries into the runtime stages, so `/opt/grpc` and `/opt/gtest` are owned by root. This prevents the `developer` user from modifying compiler plugins or libraries without explicit escalation (CWE-732).

**Stripped binaries**: Static libraries are stripped with `--strip-debug` and binaries with `--strip-unneeded` during the build stage. This reduces image size and removes debug symbols from shipped artifacts.

**No trailing colons in library paths**: `LD_LIBRARY_PATH` and `PKG_CONFIG_PATH` are set with explicit values and no trailing colons, which would otherwise cause the dynamic linker to search the current working directory (CWE-426).

**Trivy scans on every push**: CRITICAL and HIGH CVEs are reported to the GitHub Security tab as SARIF results. Containerfile misconfigurations are scanned on every pull request before merge.

**BuildKit pinned**: `moby/buildkit:v0.19` is pinned by version rather than `latest`, making builds reproducible and auditable.

**SLSA provenance and SBOM**: Every published image manifest includes a SLSA provenance attestation and a Docker-native SBOM attestation. Syft generates authoritative SBOMs in SPDX-JSON and CycloneDX-JSON formats.

**Dev Container security options**: The Dev Container configuration adds `SYS_PTRACE` and disables seccomp/apparmor confinement. This is required for debuggers (lldb, gdb) to attach to processes. These options apply only to the local development container — never to the base images themselves.

---

## Local development and contributing

### First-time setup

```bash
git clone https://github.com/bmigeri/devcon-cpp.git
cd devcon-cpp
./setup.sh
```

`setup.sh` will:
- Check that Docker and git are installed.
- Prompt for and save Docker Hub credentials to `.env` (excluded from git).
- Guide you through configuring GitHub Actions secrets.
- Create example C++ and gRPC projects under `examples/`.
- Install a pre-commit hook that auto-formats staged `.cpp` and `.h` files with clang-format.

### Making changes

1. Edit the `Containerfile` (the primary artifact of this repository).
2. Build and test locally before pushing:

   ```bash
   make build        # Build the runtime image
   make test         # Run validation checks inside the container
   make lint         # Lint the Containerfile with hadolint
   ```

3. For a vulnerability scan:

   ```bash
   make scan         # Runs Trivy (uses local binary if available, otherwise Docker)
   ```

4. Open a pull request against `main`. The CI pipeline lints the Containerfile for misconfigurations on every PR.

### Updating library versions

Library versions are controlled by build arguments at the top of each builder stage in the `Containerfile`:

```dockerfile
# grpc-builder
ARG GRPC_VERSION=v1.78.1

# gtest-builder
ARG GTEST_VERSION=v1.14.0

# dev-tools-base
ARG CMAKE_VERSION=4.2.1
```

When updating `CMAKE_VERSION`, also update the `CMAKE_SHA256` values for both `x86_64` and `aarch64` architectures in the `dev-tools-base` stage. The SHA256 values are verified at build time — the build will fail if they do not match.

### Linting the Containerfile

The `make lint` target runs [hadolint](https://github.com/hadolint/hadolint). It uses a local `hadolint` binary if available, or pulls the `hadolint/hadolint` Docker image otherwise:

```bash
make lint
```

---

## Makefile reference

Run `make help` to see the full list of targets and current variable values.

### Building

| Target | Description |
|---|---|
| `make build` | Build the `runtime` image (with gRPC) |
| `make build-dev` | Build the `development` image (gRPC + dev tools) |
| `make build-slim` | Build the `runtime-slim` image (no gRPC) |
| `make build-dev-slim` | Build the `development-slim` image (no gRPC + dev tools) |
| `make build-all` | Build all four variants |
| `make build-cached` | Build with registry-backed layer cache and push |
| `make build-multiplatform` | Multi-architecture build for `linux/amd64,linux/arm64` (requires push) |

### Testing and quality

| Target | Description |
|---|---|
| `make test` | Run compiler and tool validation checks inside the container |
| `make test-compile` | Compile and run a minimal C++ program as a smoke test |
| `make lint` | Lint the Containerfile with hadolint |
| `make scan` | Trivy vulnerability scan of the built image |

### Running

| Target | Description |
|---|---|
| `make shell` | Start an interactive bash shell in the container |
| `make run` | Run the container with `./workspace` mounted at `/workspace` |

### Registry

| Target | Description |
|---|---|
| `make push` | Build and push to Docker Hub |
| `make pull` | Pull the image from Docker Hub |

### Utilities

| Target | Description |
|---|---|
| `make size` | Print the local image size |
| `make inspect` | Print the image layer history |
| `make export` | Export the image to a `.tar.gz` file |
| `make import` | Import an image from a `.tar.gz` file |
| `make clean` | Remove local images and build cache |
| `make prune` | Deep clean — removes all unused Docker data (prompts for confirmation) |

### Variable overrides

The following Makefile variables can be overridden on the command line:

| Variable | Default | Description |
|---|---|---|
| `TARGET` | `runtime` | Build target (`runtime`, `development`, `runtime-slim`, `development-slim`) |
| `TAG` | `latest` | Image tag prefix |
| `USERNAME` | `bmigeri` | Docker Hub username |
| `IMAGE_NAME` | `devcon-cpp` | Docker Hub repository name |
| `PLATFORM` | `linux/amd64` | Target platform |
| `BUILD_JOBS` | `$(nproc)` | Parallel compilation jobs |

Example:

```bash
make build TARGET=development-slim TAG=v2.0 BUILD_JOBS=16
```

---

## Repository structure

```
devcon-cpp/
├── Containerfile               # Multi-stage OCI build definition (9 stages)
├── devcontainer.json           # VS Code Dev Container configuration
├── docker-compose.yaml         # Local docker compose service definitions
├── Makefile                    # Build, test, lint, push convenience targets
├── setup.sh                    # First-time setup (credentials, git hooks, examples)
├── init-volumes.sh             # Creates and permissions Docker volumes
├── toolchains/
│   ├── cmake-kits.json             # CMake kit definitions (x86_64, armhf, aarch64)
│   ├── arm-linux-gnueabihf.cmake   # ARM hard-float toolchain file
│   └── aarch64-linux-gnu.cmake     # AArch64 toolchain file
├── .clang-format               # Google-based style, IndentWidth:2, ColumnLimit:80
├── .dockerignore
├── .github/
│   └── workflows/
│       └── build-push.yaml     # CI/CD: build, test, scan, SBOM, push
└── README.md
```

---

## Related resources

- [Docker Hub: bmigeri/devcon-cpp](https://hub.docker.com/r/bmigeri/devcon-cpp)
- [VS Code Dev Containers documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [gRPC C++ quick start](https://grpc.io/docs/languages/cpp/quickstart/)
- [GoogleTest primer](https://google.github.io/googletest/primer.html)
- [CMake cross-compilation documentation](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html)
- [Syft SBOM tool](https://github.com/anchore/syft)
- [Trivy vulnerability scanner](https://github.com/aquasecurity/trivy)
- [hadolint Dockerfile linter](https://github.com/hadolint/hadolint)

---

Licensed under the [MIT License](LICENSE). Copyright (c) Bruce Migeri.
