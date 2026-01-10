# syntax=docker/dockerfile:1.4
# ==============================================================================
# Production-ready C++ Development Container
# Optimized multi-stage build with minimal final image size
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Base builder with common build tools
# ------------------------------------------------------------------------------
FROM ubuntu:22.04 AS base-builder

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

ARG GRPC_VERSION=v1.76.0
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
   && rm -rf /tmp/gtest

# ------------------------------------------------------------------------------
# Stage 4: Build PCL (Point Cloud Library) - x64 only
# ------------------------------------------------------------------------------
FROM base-builder AS pcl-builder

ARG PCL_VERSION=pcl-1.14.1
ENV PCL_INSTALL_PREFIX=/opt/pcl

# Install PCL dependencies (without visualization)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
   --mount=type=cache,target=/var/lib/apt,sharing=locked \
   apt-get update && apt-get install -y --no-install-recommends \
   libboost-all-dev \
   libeigen3-dev \
   libflann-dev \
   libqhull-dev \
   libusb-1.0-0-dev \
   && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/pcl

RUN git clone --depth 1 --branch ${PCL_VERSION} \
   https://github.com/PointCloudLibrary/pcl.git . && \
   mkdir build

WORKDIR /tmp/pcl/build

RUN cmake .. \
   -GNinja \
   -DCMAKE_BUILD_TYPE=Release \
   -DCMAKE_INSTALL_PREFIX=${PCL_INSTALL_PREFIX} \
   -DBUILD_examples=OFF \
   -DBUILD_tools=OFF \
   -DBUILD_apps=OFF \
   -DBUILD_visualization=OFF \
   -DPCL_BUILD_WITH_BOOST_DYNAMIC_LINKING_WIN32=OFF \
   -DWITH_OPENGL=OFF \
   -DWITH_QT=OFF \
   && ninja install \
   && rm -rf /tmp/pcl

# ------------------------------------------------------------------------------
# Stage 5: Setup ARM cross-compilation toolchain
# ------------------------------------------------------------------------------
FROM base-builder AS arm-toolchain

# Install ARM GCC toolchain
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
   --mount=type=cache,target=/var/lib/apt,sharing=locked \
   apt-get update && apt-get install -y --no-install-recommends \
   gcc-arm-linux-gnueabihf \
   g++-arm-linux-gnueabihf \
   gcc-aarch64-linux-gnu \
   g++-aarch64-linux-gnu \
   && rm -rf /var/lib/apt/lists/*

# Copy toolchain files from local directory
# These files should be created in the toolchains/ directory of your repository
COPY toolchains/ /opt/toolchains/

# ------------------------------------------------------------------------------
# Stage 6: Final runtime image (slim)
# ------------------------------------------------------------------------------
FROM ubuntu:22.04 AS runtime

# Metadata labels
LABEL maintainer="bmigeri@gmail.com"
LABEL description="Optimized C++ Development Container with cross-compilation support"
LABEL version="1.0"

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
   valgrind \
   strace \
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
   # Runtime libraries for gRPC
   libssl3 \
   zlib1g \
   # Runtime libraries for PCL (without visualization)
   libboost-system1.74.0 \
   libboost-filesystem1.74.0 \
   libboost-iostreams1.74.0 \
   libboost-thread1.74.0 \
   libeigen3-dev \
   libflann1.9 \
   libqhull8.0 \
   # Utilities
   curl \
   wget \
   vim \
   nano \
   bash-completion \
   # Miscellaneous
   gcc-arm-none-eabi \
   libnanoflann-dev \
   libjsoncpp-dev \
   libgtest-dev \
   libgmock-dev \
   libi2c-dev \
   plantuml \
   && rm -rf /var/lib/apt/lists/*

# Copy compiled libraries from build stages
COPY --from=grpc-builder /opt/grpc /opt/grpc
COPY --from=gtest-builder /opt/gtest /opt/gtest
COPY --from=pcl-builder /opt/pcl /opt/pcl
COPY --from=arm-toolchain /opt/toolchains /opt/toolchains

# Setup library paths
ENV PKG_CONFIG_PATH=/opt/grpc/lib/pkgconfig:/opt/gtest/lib/pkgconfig:/opt/pcl/lib/pkgconfig:${PKG_CONFIG_PATH} \
   LD_LIBRARY_PATH=/opt/grpc/lib:/opt/gtest/lib:/opt/pcl/lib:${LD_LIBRARY_PATH} \
   PATH=/opt/grpc/bin:${PATH} \
   CMAKE_PREFIX_PATH=/opt/grpc:/opt/gtest:/opt/pcl:${CMAKE_PREFIX_PATH}

# Create non-root user for development
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN groupadd --gid ${USER_GID} ${USERNAME} \
   && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
   && apt-get update \
   && apt-get install -y sudo \
   && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
   && chmod 0440 /etc/sudoers.d/${USERNAME} \
   && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER ${USERNAME}

# Set shell to bash with completion
SHELL ["/bin/bash", "-c"]

# Add helpful aliases and environment setup
RUN echo 'alias ll="ls -lah"' >> ~/.bashrc \
   && echo 'alias cmake-debug="cmake -DCMAKE_BUILD_TYPE=Debug -GNinja"' >> ~/.bashrc \
   && echo 'alias cmake-release="cmake -DCMAKE_BUILD_TYPE=Release -GNinja"' >> ~/.bashrc \
   && echo 'export PS1="\[\e[32m\]\u@cpp-dev\[\e[m\]:\[\e[34m\]\w\[\e[m\]\$ "' >> ~/.bashrc

# Health check to verify key tools are available
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
   CMD g++ --version && cmake --version || exit 1

CMD ["/bin/bash"]

# ------------------------------------------------------------------------------
# Stage 7: Development image (includes extra tools)
# ------------------------------------------------------------------------------
FROM runtime AS development

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
   linux-tools-generic \
   # Documentation
   doxygen \
   graphviz \
   # Python for scripting
   python3 \
   python3-pip \
   # Network tools
   netcat \
   telnet \
   iputils-ping \
   # Static analysis
   clang-tools \
   iwyu \
   # Misc utilities
   && rm -rf /var/lib/apt/lists/*

# Install latest CMake
ARG CMAKE_VERSION=4.2.1
RUN wget -qO- "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" | \
   tar --strip-components=1 -xz -C /usr/local

USER ${USERNAME}

# Pre-compile commonly used headers (optional optimization)
RUN sudo c++ -x c++-header /usr/include/c++/11/iostream -o /tmp/iostream.gch || true

CMD ["/bin/bash"]