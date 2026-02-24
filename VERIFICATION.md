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
- **gh** (GitHub CLI) — to download SBOM artifacts from CI runs; install via `brew install gh` or from [GitHub releases](https://github.com/cli/cli/releases)

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

## Step 5: Verify a Downloaded SBOM Artifact

The CI workflow uploads SBOMs as GitHub Actions artifacts in addition to attaching them as cosign attestations. You can download these files directly and cross-check them against the attested payload to confirm the artifact has not been tampered with after the CI run.

### 5a — Download the artifact using `gh`

Artifact names follow the pattern `sbom-{target}-{format}`:

| Artifact name | Downloaded file |
|---|---|
| `sbom-runtime-spdx-json` | `sbom-runtime.spdx.json` |
| `sbom-runtime-cyclonedx-json` | `sbom-runtime.cdx.json` |
| `sbom-development-spdx-json` | `sbom-development.spdx.json` |
| `sbom-development-cyclonedx-json` | `sbom-development.cdx.json` |

The same naming applies to `-slim` variants.

```bash
# Find the run ID for the workflow that produced the image
gh run list --repo bruce-mig/cpp-devcontainers --workflow build-push.yaml --limit 5

# Download the SBOM artifacts
gh run download <RUN_ID> --repo bruce-mig/cpp-devcontainers \
  --name sbom-runtime-spdx-json --dir ./sbom-artifacts

gh run download <RUN_ID> --repo bruce-mig/cpp-devcontainers \
  --name sbom-runtime-cyclonedx-json --dir ./sbom-artifacts
```

### 5b — Cross-check against the cosign attestation

Extract the predicate from the attested SBOM and diff it against the downloaded file to confirm they are identical.

**SPDX:**

```bash
cosign verify-attestation \
  --certificate-identity=https://github.com/bruce-mig/cpp-devcontainers/.github/workflows/build-push.yaml@refs/heads/main \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --type spdxjson \
  docker.io/<DOCKER_USERNAME>/devcon-cpp@<DIGEST> \
  | jq -r '.payload | @base64d | fromjson | .predicate' > attested.spdx.json

diff <(jq -S . attested.spdx.json) <(jq -S . ./sbom-artifacts/sbom-runtime.spdx.json) && echo "Match: SBOM is authentic"
```

**CycloneDX:**

```bash
cosign verify-attestation \
  --certificate-identity=https://github.com/bruce-mig/cpp-devcontainers/.github/workflows/build-push.yaml@refs/heads/main \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --type cyclonedx \
  docker.io/<DOCKER_USERNAME>/devcon-cpp@<DIGEST> \
  | jq -r '.payload | @base64d | fromjson | .predicate' > attested.cdx.json

diff <(jq -S . attested.cdx.json) <(jq -S . ./sbom-artifacts/sbom-runtime.cdx.json) && echo "Match: SBOM is authentic"
```

A clean `diff` (exit 0) confirms the artifact matches what was signed and recorded in Rekor.

---

## Notes

- All commands use `@<DIGEST>` (not a tag) — cosign requires a content-addressed reference for integrity guarantees.
- No `--key` flag is needed. Verification is performed against Sigstore's public Rekor transparency log using the certificate embedded in the signature.
- The `--certificate-identity` URL must match the exact workflow file path and branch ref used during signing.
