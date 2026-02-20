# syntax=docker/dockerfile:1.4
# ==============================================================================
# Production-ready C++ Development Container
# Optimized multi-stage build with minimal final image size
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Base builder with common build tools
# ------------------------------------------------------------------------------
FROM ubuntu:24.04 AS base-builder

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive \
   TZ=UTC

# Install common build dependencies in a single layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
   --mount=type=cache,target=/var/lib/apt,sharing=locked \
   apt-get update && apt-get install -y --no-install-recommends \
   build-essential \
   cmake \
   ninja-build \
   git \
   wget \
   curl \
   ca-certificates \
   pkg-config \
   autoconf \
   automake \
   libtool \
   && rm -rf /var/lib/apt/lists/*

# Set number of build jobs based on available cores
ARG BUILD_JOBS=4
ENV MAKEFLAGS="-j${BUILD_JOBS}"

# ------------------------------------------------------------------------------
# Stage 2: Build gRPC (largest dependency)
# ------------------------------------------------------------------------------
FROM base-builder AS grpc-builder

ARG GRPC_VERSION=v1.78.1
ENV GRPC_INSTALL_PREFIX=/opt/grpc

WORKDIR /tmp/grpc

# Clone with shallow depth to save space and time
RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch ${GRPC_VERSION} \
   https://github.com/grpc/grpc.git . && \
   mkdir -p cmake/build

WORKDIR /tmp/grpc/cmake/build

# Build and install gRPC with optimizations
RUN cmake ../.. \
   -GNinja \
   -DCMAKE_BUILD_TYPE=Release \
   -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PREFIX} \
   -DCMAKE_CXX_STANDARD=17 \
   -DgRPC_INSTALL=ON \
   -DgRPC_BUILD_TESTS=OFF \
   -DgRPC_BUILD_CSHARP_EXT=OFF \
   -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
   -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
   -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
   -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
   -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
   -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF \
   -DABSL_ENABLE_INSTALL=ON \
   && ninja install \
   && find ${GRPC_INSTALL_PREFIX} -name "*.a" -exec strip --strip-debug {} \; \
   && for BIN in protoc grpc_cpp_plugin; do \
   BIN_PATH="${GRPC_INSTALL_PREFIX}/bin/${BIN}"; \
   [ -f "${BIN_PATH}" ] && strip --strip-unneeded "${BIN_PATH}"; \
   done \
   && "${GRPC_INSTALL_PREFIX}/bin/protoc" --version \
   && rm -rf /tmp/grpc

# ------------------------------------------------------------------------------
# Stage 3: Build GoogleTest
# ------------------------------------------------------------------------------
FROM base-builder AS gtest-builder

ARG GTEST_VERSION=v1.14.0
ENV GTEST_INSTALL_PREFIX=/opt/gtest

WORKDIR /tmp/gtest

RUN git clone --depth 1 --branch ${GTEST_VERSION} \
   https://github.com/google/googletest.git . && \
   mkdir build

WORKDIR /tmp/gtest/build

RUN cmake .. \
   -GNinja \
   -DCMAKE_BUILD_TYPE=Release \
   -DCMAKE_INSTALL_PREFIX=${GTEST_INSTALL_PREFIX} \
   -DBUILD_GMOCK=ON \
   && ninja install \
   && find ${GTEST_INSTALL_PREFIX} -name "*.a" -exec strip --strip-debug {} \; \
   && rm -rf /tmp/gtest

# ------------------------------------------------------------------------------
# Stage 4: Runtime base — packages, gtest, cross-compilers, user setup (no gRPC)
# Intermediate stage; not directly published.
# OCI labels are intentionally omitted here — the CI pipeline injects them via
# docker/metadata-action so a baked-in version string does not drift.
# ------------------------------------------------------------------------------
FROM ubuntu:24.04 AS runtime-base

ENV DEBIAN_FRONTEND=noninteractive \
   TZ=UTC

# Install runtime dependencies and development tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
   --mount=type=cache,target=/var/lib/apt,sharing=locked \
   apt-get update && apt-get install -y --no-install-recommends \
   # Build essentials
   build-essential \
   cmake \
   ninja-build \
   pkg-config \
   git \
   # Debugging and analysis
   gdb \
   # Code quality tools
   clangd \
   clang-format \
   clang-tidy \
   cppcheck \
   # Cross-compilation toolchains
   gcc-arm-linux-gnueabihf \
   g++-arm-linux-gnueabihf \
   gcc-aarch64-linux-gnu \
   g++-aarch64-linux-gnu \
   # SSL/TLS support (libssl3 resolves to the correct package on Noble and future releases)
   libssl3 \
   zlib1g \
   # Utilities
   curl \
   wget \
   bash-completion \
   sudo \
   # Miscellaneous
   libjsoncpp-dev \
   && rm -rf /var/lib/apt/lists/*

# Copy compiled gtest library from build stage
COPY --from=gtest-builder /opt/gtest /opt/gtest
# Copy toolchain files directly from host (no intermediate stage needed)
COPY toolchains/ /opt/toolchains/

# Setup library paths for gtest (explicit values without variable expansion — prevents
# trailing colons that would make the dynamic linker search CWD, CWE-426)
ENV PKG_CONFIG_PATH=/opt/gtest/lib/pkgconfig \
   LD_LIBRARY_PATH=/opt/gtest/lib \
   CMAKE_PREFIX_PATH=/opt/gtest

# Create non-root user for development
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN groupadd --gid ${USER_GID} ${USERNAME} \
   && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
   && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
   && chmod 0440 /etc/sudoers.d/${USERNAME} \
   && mkdir -p /workspace \
   && chown ${USERNAME}:${USERNAME} /workspace

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER ${USERNAME}

# Add helpful aliases and environment setup
RUN echo 'alias ll="ls -lah"' >> ~/.bashrc \
   && echo 'alias cmake-debug="cmake -DCMAKE_BUILD_TYPE=Debug -GNinja"' >> ~/.bashrc \
   && echo 'alias cmake-release="cmake -DCMAKE_BUILD_TYPE=Release -GNinja"' >> ~/.bashrc \
   && echo 'export PS1="\[\e[32m\]\u@cpp-dev\[\e[m\]:\[\e[34m\]\w\[\e[m\]\$ "' >> ~/.bashrc

CMD ["/bin/bash"]

# ------------------------------------------------------------------------------
# Stage 5: Runtime slim — no gRPC (published target)
# Identical to runtime-base; exists solely to provide a separately tagged
# published image. No additional layers are added.
# ------------------------------------------------------------------------------
FROM runtime-base AS runtime-slim

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
   CMD bash -c "g++ --version > /dev/null && cmake --version > /dev/null"

# ------------------------------------------------------------------------------
# Stage 6: Runtime — adds gRPC on top of runtime-base (published target)
# ------------------------------------------------------------------------------
FROM runtime-base AS runtime

# Switch to root so /opt/grpc is root-owned after the COPY — prevents the
# developer user from modifying toolchain binaries without escalation (CWE-732)
USER root
COPY --from=grpc-builder /opt/grpc /opt/grpc

# Extend library paths to include gRPC (overrides the gtest-only ENV from runtime-base)
ENV PKG_CONFIG_PATH=/opt/grpc/lib/pkgconfig:/opt/gtest/lib/pkgconfig \
   LD_LIBRARY_PATH=/opt/grpc/lib:/opt/gtest/lib \
   PATH=/opt/grpc/bin:${PATH} \
   CMAKE_PREFIX_PATH=/opt/grpc:/opt/gtest

ARG USERNAME=developer
USER ${USERNAME}

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
   CMD bash -c "g++ --version > /dev/null && cmake --version > /dev/null"

# ------------------------------------------------------------------------------
# Stage 7: Dev-tools base — shared layer for both development variants (not published)
# Single source of truth for the dev toolset; avoids duplicating the apt block
# and CMake SHA256 values across development and development-slim.
# Inherits runtime-base; does NOT include gRPC. Leaf stages add gRPC if needed.
# Ends as root so leaf-stage COPY instructions run with correct ownership.
# ------------------------------------------------------------------------------
FROM runtime-base AS dev-tools-base

USER root

# Install additional development tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
   --mount=type=cache,target=/var/lib/apt,sharing=locked \
   apt-get update && apt-get install -y --no-install-recommends \
   # Additional debugging tools
   lldb \
   gdb-multiarch \
   # Performance profiling
   perf-tools-unstable \
   # Debugging and analysis
   valgrind \
   strace \
   # Documentation
   doxygen \
   graphviz \
   # Python for scripting
   python3 \
   python3-pip \
   # Network tools
   netcat \
   iputils-ping \
   # Static analysis
   iwyu \
   # Editor tools
   vim \
   nano \
   && rm -rf /var/lib/apt/lists/*

# Install latest CMake with integrity check and architecture detection
ARG CMAKE_VERSION=4.2.1
RUN set -eux; \
   ARCH="$(uname -m)"; \
   case "${ARCH}" in \
   x86_64)  CMAKE_ARCH="linux-x86_64";  CMAKE_SHA256="5977a65f3edfb64743fc2e1b6554f1e51f4cf1b7338cf33953519ae71c8bcb17" ;; \
   aarch64) CMAKE_ARCH="linux-aarch64"; CMAKE_SHA256="3e178207a2c42af4cd4883127f8800b6faf99f3f5187dccc68bfb2cc7808f5f7" ;; \
   *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;; \
   esac; \
   wget -q "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-${CMAKE_ARCH}.tar.gz" \
   -O /tmp/cmake.tar.gz; \
   echo "${CMAKE_SHA256}  /tmp/cmake.tar.gz" | sha256sum -c -; \
   mkdir -p /opt/cmake; \
   tar --strip-components=1 -xzf /tmp/cmake.tar.gz -C /opt/cmake; \
   ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake; \
   ln -sf /opt/cmake/bin/ctest /usr/local/bin/ctest; \
   ln -sf /opt/cmake/bin/cpack /usr/local/bin/cpack; \
   rm /tmp/cmake.tar.gz

# Intentionally left as root — leaf stages restore the non-root user.

# ------------------------------------------------------------------------------
# Stage 8: Development — dev tools + gRPC (published target)
# ------------------------------------------------------------------------------
FROM dev-tools-base AS development

# dev-tools-base ends as root; COPY runs as root so /opt/grpc is root-owned
COPY --from=grpc-builder /opt/grpc /opt/grpc

ENV PKG_CONFIG_PATH=/opt/grpc/lib/pkgconfig:/opt/gtest/lib/pkgconfig \
   LD_LIBRARY_PATH=/opt/grpc/lib:/opt/gtest/lib \
   PATH=/opt/grpc/bin:${PATH} \
   CMAKE_PREFIX_PATH=/opt/grpc:/opt/gtest

ARG USERNAME=developer
USER ${USERNAME}

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
   CMD bash -c "g++ --version > /dev/null && cmake --version > /dev/null"

CMD ["/bin/bash"]

# ------------------------------------------------------------------------------
# Stage 9: Development slim — dev tools without gRPC (published target)
# Identical to dev-tools-base + user switch; the slim variant exists to provide
# a separately tagged published image for projects that do not need gRPC.
# ------------------------------------------------------------------------------
FROM dev-tools-base AS development-slim

ARG USERNAME=developer
USER ${USERNAME}

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
   CMD bash -c "g++ --version > /dev/null && cmake --version > /dev/null"

CMD ["/bin/bash"]
