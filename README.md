# C++ Development Container

[![Build Status](https://github.com/bruce-mig/cpp-devcontainers/workflows/Build%20and%20Push%20C++%20Dev%20Container/badge.svg)](https://github.com/bmigeri/cpp-devcontainers/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/bmigeri/cpp-dev)](https://hub.docker.com/r/bmigeri/cpp-dev)
[![Image Size](https://img.shields.io/docker/image-size/bmigeri/cpp-dev/latest-runtime)](https://hub.docker.com/r/bmigeri/cpp-dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready, optimized C++ development container with comprehensive tooling for modern C++ development, cross-compilation, and CI/CD integration.

## 🚀 Features

### Core Development Tools
- **Compilers**: GCC (x86_64, ARM 32-bit, ARM 64-bit)
- **Build Systems**: CMake 3.28+, Ninja
- **Debuggers**: GDB, Valgrind
- **Code Quality**: clang-format, clang-tidy, cppcheck

### Libraries
- **gRPC** v1.62.0 - Modern RPC framework
- **GoogleTest** v1.14.0 - Testing framework (GTest + GMock)
- **PCL** v1.14.1 - Point Cloud Library (x64 only)

### Cross-Compilation Support
- ARM 32-bit (armhf) toolchain
- ARM 64-bit (aarch64) toolchain
- Pre-configured CMake toolchain files
- VS Code CMake Kits integration

## 📦 Available Images

| Image Tag | Size | Use Case |
|-----------|------|----------|
| `latest-runtime` | ~850MB | Production builds, CI/CD pipelines |
| `latest-development` | ~1.07GB | Full development environment |

## 🛠️ Quick Start

### Using Pre-built Image

```bash
# Pull the runtime image
docker pull bmigeri/cpp-dev:latest-runtime

# Run interactive shell
docker run -it --rm \
  -v $(pwd):/workspace \
  bmigeri/cpp-dev:latest-runtime
```

### Using VS Code Dev Containers

> [!NOTE]
> See example `devcontainer.json` for usage.

1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Clone this repository
3. Open in VS Code
4. Click "Reopen in Container" when prompted

### Building Locally

```bash
# Using Make
make build              # Build runtime image
make build-dev          # Build development image
make test               # Run validation tests

# Using Docker directly
docker build --target runtime -t cpp-dev:runtime .
docker build --target development -t cpp-dev:development .
```

## 📋 Usage Examples

### Basic C++ Project

```bash
# Create and build a simple project
mkdir my-project && cd my-project
docker run -it --rm -v $(pwd):/workspace bmigeri/cpp-dev:latest-runtime bash

# Inside container
cat > main.cpp << 'EOF'
#include <iostream>
int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF

g++ main.cpp -o hello
./hello
```

### Using CMake

```bash
# Inside container
mkdir build && cd build
cmake .. -GNinja
ninja
```

### Cross-Compiling for ARM

```bash
# Inside container
mkdir build-arm && cd build-arm

# For ARM 32-bit
cmake .. -GNinja \
  -DCMAKE_TOOLCHAIN_FILE=/opt/toolchains/arm-linux-gnueabihf.cmake

# For ARM 64-bit
cmake .. -GNinja \
  -DCMAKE_TOOLCHAIN_FILE=/opt/toolchains/aarch64-linux-gnu.cmake

ninja
```

### Using gRPC

```cpp
// example.cpp
#include <grpcpp/grpcpp.h>
#include <iostream>

int main() {
    auto channel = grpc::CreateChannel(
        "localhost:50051", 
        grpc::InsecureChannelCredentials()
    );
    std::cout << "gRPC channel created" << std::endl;
    return 0;
}
```

```bash
# Compile with gRPC
g++ example.cpp -o example \
  $(pkg-config --cflags --libs grpc++ protobuf)
```

### Using GoogleTest

```cpp
// test_example.cpp
#include <gtest/gtest.h>

TEST(ExampleTest, BasicAssertion) {
    EXPECT_EQ(2 + 2, 4);
}

int main(int argc, char **argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
```

```bash
# Compile and run tests
g++ test_example.cpp -o test \
  $(pkg-config --cflags --libs gtest) \
  -pthread
./test
```

## 🔧 Configuration

### CMake Kits for VS Code

The container includes pre-configured CMake kits at `/opt/toolchains/cmake-kits.json`:

```json
{
  "cmake.additionalKits": ["/opt/toolchains/cmake-kits.json"]
}
```

Available kits:
- **GCC x86_64** - Native compilation
- **GCC ARM 32-bit (armhf)** - ARM 32-bit cross-compilation
- **GCC ARM 64-bit (aarch64)** - ARM 64-bit cross-compilation

### Environment Variables

```bash
PKG_CONFIG_PATH=/opt/grpc/lib/pkgconfig:/opt/gtest/lib/pkgconfig:/opt/pcl/lib/pkgconfig
LD_LIBRARY_PATH=/opt/grpc/lib:/opt/gtest/lib:/opt/pcl/lib
CMAKE_PREFIX_PATH=/opt/grpc:/opt/gtest:/opt/pcl
```

## 🏗️ CI/CD Integration

### GitHub Actions

The repository includes a complete GitHub Actions workflow for automated builds:

```yaml
# Triggered on push to main/develop
- Builds both runtime and development images
- Multi-architecture support (amd64, arm64)
- Layer caching for faster builds
- Security scanning with Trivy
- SBOM generation
- Automatic Docker Hub updates
```

### GitLab CI

```yaml
# .gitlab-ci.yml example
build:
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build --target runtime -t $CI_REGISTRY_IMAGE:latest .
    - docker push $CI_REGISTRY_IMAGE:latest
```

### Jenkins

```groovy
// Jenkinsfile example
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'make build'
            }
        }
        stage('Test') {
            steps {
                sh 'make test'
            }
        }
        stage('Push') {
            steps {
                sh 'make push'
            }
        }
    }
}
```

## 🔐 Security

- Non-root user (`developer`) for safer operation
- Multi-stage builds minimize attack surface
- Regular security scanning with Trivy
- SBOM generation for transparency
- Minimal runtime dependencies

## 📊 Image Optimization

This Dockerfile uses several optimization techniques:

1. **Multi-stage builds** - Separates build and runtime environments
2. **Build caching** - Leverages Docker BuildKit cache mounts
3. **Layer optimization** - Combines commands to reduce layers
4. **Minimal base** - Uses Ubuntu 22.04 as lean base
5. **Runtime-only deps** - Final image contains only runtime libraries

### Size Comparison

```bash
# Check image sizes
make size

# Expected results:
# runtime:      ~850MB
# development: ~1.07GB
```

## 🐛 Troubleshooting

### Build Issues

```bash
# Clear Docker cache
make clean

# Deep clean (removes all Docker data)
make prune

# Check Docker disk usage
docker system df
```

### Storage Issues During Build

If building locally fails due to storage:

1. Use the provided GitHub Actions workflow
2. Enable Docker BuildKit: `export DOCKER_BUILDKIT=1`
3. Use `make build-cached` with registry caching

### Permission Issues

```bash
# If you encounter permission issues in the container
docker run --user root ...  # Run as root temporarily
```

## 📚 Documentation

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [CMake Documentation](https://cmake.org/documentation/)
- [gRPC C++ Guide](https://grpc.io/docs/languages/cpp/)
- [GoogleTest Primer](https://google.github.io/googletest/primer.html)

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Google for gRPC and GoogleTest
- Point Cloud Library (PCL) team
- The C++ community

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bmigeri/cpp-devcontainers/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bmigeri/cpp-devcontainers/discussions)
- **Docker Hub**: [bmigeri/cpp-dev](https://hub.docker.com/r/bmigeri/cpp-dev)

---

**Built with ❤️ for C++ developers**