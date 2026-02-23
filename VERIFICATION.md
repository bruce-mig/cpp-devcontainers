# Verifying Image Signatures and SBOM Attestations

Images published by this repository are signed and attested using **keyless OIDC signing** via [Sigstore](https://www.sigstore.dev/). No private key is required — verification relies on Sigstore's public Rekor transparency log.

What is verified:
- **Image signatures** — proves the image was built by this repository's CI workflow
- **In-toto SBOM attestations** — proves the attached SPDX and CycloneDX SBOMs were generated from the same CI run

---

## Prerequisites

- **cosign** — install via `brew install cosign`, `go install github.com/sigstore/cosign/v2/cmd/cosign@latest`, or download from [GitHub releases](https://github.com/sigstore/cosign/releases)
- **Docker CLI** — to pull image digests
- **jq** — to extract the digest from `docker buildx imagetools` output

---

## Step 1: Find the Image Digest

All `cosign` commands require a digest reference (`@sha256:...`) rather than a tag.

Available tags: `latest-runtime`, `latest-runtime-slim`, `latest-development`, `latest-development-slim`

```bash
DIGEST=$(docker buildx imagetools inspect docker.io/<DOCKER_USERNAME>/devcon-cpp:latest-runtime \
  --format '{{json .}}' | jq -r '.manifest.digest')
echo $DIGEST
```

Replace `<DOCKER_USERNAME>` with the Docker Hub username used to publish the image (e.g. `bmigeri`).

---

## Step 2: Verify the Image Signature

```bash
cosign verify \
  --certificate-identity=https://github.com/bruce-mig/cpp-devcontainers/.github/workflows/build-push.yaml@refs/heads/main \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  docker.io/<DOCKER_USERNAME>/devcon-cpp@<DIGEST>
```

A successful result prints the verified certificate chain and exits 0.

---

## Step 3: Verify SBOM Attestations

### SPDX JSON

```bash
cosign verify-attestation \
  --certificate-identity=https://github.com/bruce-mig/cpp-devcontainers/.github/workflows/build-push.yaml@refs/heads/main \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --type spdxjson \
  docker.io/<DOCKER_USERNAME>/devcon-cpp@<DIGEST>
```

### CycloneDX JSON

```bash
cosign verify-attestation \
  --certificate-identity=https://github.com/bruce-mig/cpp-devcontainers/.github/workflows/build-push.yaml@refs/heads/main \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --type cyclonedx \
  docker.io/<DOCKER_USERNAME>/devcon-cpp@<DIGEST>
```

---

## Step 4: Inspect the SBOM Payload (Optional)

Pipe the attestation output through `jq` to read the embedded SBOM:

```bash
cosign verify-attestation \
  --certificate-identity=https://github.com/bruce-mig/cpp-devcontainers/.github/workflows/build-push.yaml@refs/heads/main \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --type spdxjson \
  docker.io/<DOCKER_USERNAME>/devcon-cpp@<DIGEST> \
  | jq -r '.payload | @base64d | fromjson | .predicate'
```

---

## Notes

- All commands use `@<DIGEST>` (not a tag) — cosign requires a content-addressed reference for integrity guarantees.
- No `--key` flag is needed. Verification is performed against Sigstore's public Rekor transparency log using the certificate embedded in the signature.
- The `--certificate-identity` URL must match the exact workflow file path and branch ref used during signing.
