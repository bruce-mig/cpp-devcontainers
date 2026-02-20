# Makefile for C++ Development Container
# Simplifies common Docker operations

# Variables
IMAGE_NAME ?= devcon-cpp
REGISTRY ?= docker.io
USERNAME ?= bmigeri
TAG ?= latest
TARGET ?= runtime
PLATFORM ?= linux/amd64
BUILD_JOBS ?= $(shell nproc)

FULL_IMAGE_NAME = $(REGISTRY)/$(USERNAME)/$(IMAGE_NAME):$(TAG)-$(TARGET)

.PHONY: help build build-dev build-slim build-dev-slim build-all push pull test clean run shell lint

# Default target
help:
	@echo "C++ Development Container - Make Commands"
	@echo "=========================================="
	@echo ""
	@echo "Building:"
	@echo "  make build          - Build runtime image (production)"
	@echo "  make build-dev      - Build development image (with extra tools)"
	@echo "  make build-slim     - Build runtime-slim image (no gRPC)"
	@echo "  make build-dev-slim - Build development-slim image (no gRPC)"
	@echo "  make build-all      - Build all 4 image variants"
	@echo ""
	@echo "Docker Registry:"
	@echo "  make push           - Push image to registry"
	@echo "  make pull           - Pull image from registry"
	@echo ""
	@echo "Testing:"
	@echo "  make test           - Run image validation tests"
	@echo "  make lint           - Lint Containerfile"
	@echo ""
	@echo "Running:"
	@echo "  make run            - Run container with workspace mounted"
	@echo "  make shell          - Start interactive shell in container"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean          - Remove local images and build cache"
	@echo "  make prune          - Deep clean (removes all unused Docker data)"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  USERNAME=$(USERNAME)"
	@echo "  TAG=$(TAG)"
	@echo "  TARGET=$(TARGET)"
	@echo "  BUILD_JOBS=$(BUILD_JOBS)"
	@echo ""
	@echo "Example: make build TARGET=development TAG=v1.0"

# Build targets
build:
	@echo "Building $(TARGET) image..."
	docker buildx build \
		--target $(TARGET) \
		--platform $(PLATFORM) \
		--build-arg BUILD_JOBS=$(BUILD_JOBS) \
		--tag $(FULL_IMAGE_NAME) \
		--load \
		.

build-dev:
	@$(MAKE) build TARGET=development

build-slim:  ## Build runtime-slim image (no gRPC)
	@$(MAKE) build TARGET=runtime-slim

build-dev-slim:  ## Build development-slim image (no gRPC)
	@$(MAKE) build TARGET=development-slim

build-all:
	@$(MAKE) build TARGET=runtime
	@$(MAKE) build TARGET=development
	@$(MAKE) build TARGET=runtime-slim
	@$(MAKE) build TARGET=development-slim

# Build with cache optimization
build-cached:
	@echo "Building with registry cache..."
	docker buildx build \
		--target $(TARGET) \
		--platform $(PLATFORM) \
		--build-arg BUILD_JOBS=$(BUILD_JOBS) \
		--cache-from type=registry,ref=$(FULL_IMAGE_NAME)-buildcache \
		--cache-to type=registry,ref=$(FULL_IMAGE_NAME)-buildcache,mode=max \
		--tag $(FULL_IMAGE_NAME) \
		--push \
		.

# Multi-platform build (requires buildx)
build-multiplatform:
	docker buildx build \
		--target $(TARGET) \
		--platform linux/amd64,linux/arm64 \
		--build-arg BUILD_JOBS=$(BUILD_JOBS) \
		--tag $(FULL_IMAGE_NAME) \
		--push \
		.

# Push to registry
push: build
	@echo "Pushing $(FULL_IMAGE_NAME)..."
	docker push $(FULL_IMAGE_NAME)

# Pull from registry
pull:
	@echo "Pulling $(FULL_IMAGE_NAME)..."
	docker pull $(FULL_IMAGE_NAME)

# Run container with workspace mounted
run:
	docker run -it --rm \
		-v $(PWD):/workspace \
		-v cpp-dev-cache:/home/developer/.cache \
		--name devcon-cpp-container \
		$(FULL_IMAGE_NAME)

# Interactive shell
shell:
	docker run -it --rm \
		-v $(PWD):/workspace \
		-v cpp-dev-cache:/home/developer/.cache \
		--name devcon-cpp-shell \
		$(FULL_IMAGE_NAME) \
		/bin/bash

# Run with VS Code devcontainer
devcontainer:
	@echo "Starting devcontainer..."
	@if command -v code >/dev/null 2>&1; then \
		code . && code --remote containers; \
	else \
		echo "VS Code CLI not found. Opening manually..."; \
	fi

# Testing
test: build
	@echo "Running tests on $(FULL_IMAGE_NAME)..."
	@docker run --rm $(FULL_IMAGE_NAME) bash -c " \
		set -e && \
		echo '=== Compiler Tests ===' && \
		g++ --version && \
		arm-linux-gnueabihf-g++ --version && \
		aarch64-linux-gnu-g++ --version && \
		echo && \
		echo '=== Build Tools ===' && \
		cmake --version && \
		ninja --version && \
		echo && \
		echo '=== Libraries ===' && \
		pkg-config --exists grpc++ && echo 'gRPC: ✓' || echo 'gRPC: ✗' && \
		pkg-config --exists gtest && echo 'GTest: ✓' || echo 'GTest: ✗' && \
		test -f /opt/toolchains/cmake-kits.json && echo 'CMake Kits: ✓' || echo 'CMake Kits: ✗' && \
		echo && \
		echo '=== Code Quality Tools ===' && \
		clang-format --version && \
		clang-tidy --version && \
		echo && \
		echo '✓ All tests passed!' \
	"

# Test a simple C++ compilation
test-compile:
	@echo "Testing C++ compilation..."
	@docker run --rm -v $(PWD):/workspace $(FULL_IMAGE_NAME) bash -c " \
		cd /workspace && \
		echo '#include <iostream>' > /tmp/test.cpp && \
		echo 'int main() { std::cout << \"Hello from C++\" << std::endl; return 0; }' >> /tmp/test.cpp && \
		g++ /tmp/test.cpp -o /tmp/test && \
		/tmp/test && \
		echo '✓ Compilation test passed!' \
	"

# Lint Containerfile
lint:
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Containerfile; \
	else \
		docker run --rm -i hadolint/hadolint < Containerfile; \
	fi

# Security scan
scan: build
	@echo "Scanning $(FULL_IMAGE_NAME) for vulnerabilities..."
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image $(FULL_IMAGE_NAME); \
	else \
		docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
			aquasec/trivy image $(FULL_IMAGE_NAME); \
	fi

# Check image size
size: build
	@echo "Image size for $(FULL_IMAGE_NAME):"
	@docker images $(FULL_IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Inspect image layers
inspect: build
	docker history $(FULL_IMAGE_NAME)

# Clean up local images
clean:
	@echo "Removing local images..."
	-docker rmi $(REGISTRY)/$(USERNAME)/$(IMAGE_NAME):$(TAG)-runtime 2>/dev/null || true
	-docker rmi $(REGISTRY)/$(USERNAME)/$(IMAGE_NAME):$(TAG)-runtime-slim 2>/dev/null || true
	-docker rmi $(REGISTRY)/$(USERNAME)/$(IMAGE_NAME):$(TAG)-development 2>/dev/null || true
	-docker rmi $(REGISTRY)/$(USERNAME)/$(IMAGE_NAME):$(TAG)-development-slim 2>/dev/null || true
	@echo "Cleaning build cache..."
	docker builder prune -f

# Deep clean
prune:
	@echo "Warning: This will remove ALL unused Docker data!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker system prune -a --volumes -f; \
	fi

# Show container logs
logs:
	docker logs devcon-cpp-container

# Export image to tar
export:
	@echo "Exporting $(FULL_IMAGE_NAME) to tar..."
	docker save $(FULL_IMAGE_NAME) | gzip > devcon-cpp-$(TAG)-$(TARGET).tar.gz
	@echo "Exported to devcon-cpp-$(TAG)-$(TARGET).tar.gz"

# Import image from tar
import:
	@echo "Importing image from tar..."
	@if [ -f devcon-cpp-$(TAG)-$(TARGET).tar.gz ]; then \
		docker load < devcon-cpp-$(TAG)-$(TARGET).tar.gz; \
	else \
		echo "Error: devcon-cpp-$(TAG)-$(TARGET).tar.gz not found"; \
	fi