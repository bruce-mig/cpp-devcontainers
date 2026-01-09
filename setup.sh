#!/bin/bash
# Setup script for C++ Development Container
# This script helps configure the repository for your environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install:"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        echo "  - Git: https://git-scm.com/downloads"
        exit 1
    fi
    
    info "✓ All prerequisites satisfied"
}

# Get Docker Hub credentials
configure_registry() {
    info "Configuring Docker registry..."
    
    # Check if credentials exist
    if [ -f .env ]; then
        source .env
        if [ -n "$DOCKER_USERNAME" ]; then
            info "Using existing credentials from .env"
            return
        fi
    fi
    
    echo ""
    read -p "Enter your Docker Hub username: " username
    read -sp "Enter your Docker Hub password/token: " password
    echo ""
    
    # Create .env file
    cat > .env << EOF
# Docker Registry Configuration
DOCKER_USERNAME=${username}
DOCKER_PASSWORD=${password}
REGISTRY=docker.io
IMAGE_NAME=cpp-dev
EOF
    
    info "✓ Credentials saved to .env"
    warn "⚠ Add .env to .gitignore to keep credentials secure"
    
    # Add to .gitignore if not already there
    if ! grep -q "^.env$" .gitignore 2>/dev/null; then
        echo ".env" >> .gitignore
        info "✓ Added .env to .gitignore"
    fi
}

# Setup GitHub Actions secrets
setup_github_secrets() {
    info "Setting up GitHub Actions..."
    
    echo ""
    echo "To use GitHub Actions CI/CD, add these secrets to your repository:"
    echo ""
    echo "  1. Go to: https://github.com/YOUR_USERNAME/cpp-dev/settings/secrets/actions"
    echo "  2. Add the following secrets:"
    echo "     - DOCKER_USERNAME: Your Docker Hub username"
    echo "     - DOCKER_PASSWORD: Your Docker Hub password or access token"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Create example C++ project
create_example_project() {
    info "Creating example C++ project..."
    
    mkdir -p examples/hello-world
    
    # Create main.cpp
    cat > examples/hello-world/main.cpp << 'EOF'
#include <iostream>
#include <string>

int main(int argc, char** argv) {
    std::string name = (argc > 1) ? argv[1] : "World";
    std::cout << "Hello, " << name << "!" << std::endl;
    return 0;
}
EOF

    # Create CMakeLists.txt
    cat > examples/hello-world/CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.20)
project(HelloWorld VERSION 1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(hello main.cpp)

# Install target
install(TARGETS hello DESTINATION bin)
EOF

    # Create test file
    cat > examples/hello-world/test_main.cpp << 'EOF'
#include <gtest/gtest.h>

TEST(HelloWorldTest, BasicTest) {
    EXPECT_EQ(1 + 1, 2);
}

int main(int argc, char** argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
EOF

    info "✓ Example project created in examples/hello-world/"
}

# Create gRPC example
create_grpc_example() {
    info "Creating gRPC example..."
    
    mkdir -p examples/grpc-hello
    
    # Create proto file
    cat > examples/grpc-hello/hello.proto << 'EOF'
syntax = "proto3";

package hello;

service Greeter {
    rpc SayHello (HelloRequest) returns (HelloReply) {}
}

message HelloRequest {
    string name = 1;
}

message HelloReply {
    string message = 1;
}
EOF

    # Create CMakeLists.txt
    cat > examples/grpc-hello/CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.20)
project(GrpcHello)

set(CMAKE_CXX_STANDARD 17)

# Find packages
find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG REQUIRED)

# Generate proto files
set(PROTO_FILES hello.proto)
add_library(hello_proto ${PROTO_FILES})
target_link_libraries(hello_proto
    PUBLIC
        protobuf::libprotobuf
        gRPC::grpc++
)

# Server
add_executable(server server.cpp)
target_link_libraries(server hello_proto)

# Client
add_executable(client client.cpp)
target_link_libraries(client hello_proto)
EOF

    info "✓ gRPC example created in examples/grpc-hello/"
}

# Initialize git hooks
setup_git_hooks() {
    info "Setting up Git hooks..."
    
    mkdir -p .git/hooks
    
    # Pre-commit hook for formatting
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook to format C++ files

# Find all staged C++ files
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(cpp|cc|cxx|h|hpp)$')

if [ -n "$files" ]; then
    echo "Formatting C++ files..."
    for file in $files; do
        clang-format -i "$file"
        git add "$file"
    done
fi

exit 0
EOF
    
    chmod +x .git/hooks/pre-commit
    info "✓ Git hooks configured"
}

# Main setup
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║   C++ Development Container - Setup Script           ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    configure_registry
    setup_github_secrets
    create_example_project
    create_grpc_example
    
    if [ -d .git ]; then
        setup_git_hooks
    fi
    
    echo ""
    info "═══════════════════════════════════════════════════════"
    info "✓ Setup complete!"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Build the container:"
    echo "     $ make build"
    echo ""
    echo "  2. Run the container:"
    echo "     $ make shell"
    echo ""
    echo "  3. Or use VS Code:"
    echo "     - Install 'Dev Containers' extension"
    echo "     - Press F1 and select 'Reopen in Container'"
    echo ""
    echo "  4. Build the example project:"
    echo "     $ cd examples/hello-world"
    echo "     $ mkdir build && cd build"
    echo "     $ cmake .. -GNinja"
    echo "     $ ninja"
    echo "     $ ./hello"
    echo ""
    echo "Documentation:"
    echo "  - README.md - Full documentation"
    echo "  - Makefile - Available commands (run 'make help')"
    echo ""
    info "═══════════════════════════════════════════════════════"
}

# Run main
main