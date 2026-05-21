#!/usr/bin/env bash
# Install every local code-generation plugin used by buf.gen.yaml.
#
# Everything lands inside the repo (tools/_bin, tools/_jars, node_modules) so the
# whole pipeline is "local only" -- buf never reaches out to the Buf Schema
# Registry for remote plugins. Re-running is safe/idempotent.
set -euo pipefail

# ----- Pinned versions (keep in sync with examples/kotlin/build.gradle.kts) ----
BUF_VERSION="1.50.0"
PROTOC_GEN_GO_VERSION="v1.36.5"
PROTOC_GEN_GO_GRPC_VERSION="v1.5.1"
PROTOC_GEN_CONNECT_GO_VERSION="v1.18.1"
PROTOC_VERSION="25.5"            # protobuf -> Java/Kotlin builtins; runtime 3.25.5
GRPC_JAVA_VERSION="1.62.2"       # protoc-gen-grpc-java (native plugin)
GRPC_KOTLIN_VERSION="1.4.3"      # protoc-gen-grpc-kotlin (jar)
CONNECT_KOTLIN_VERSION="0.8.2"   # protoc-gen-connect-kotlin (jar)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROOT}/tools/_bin"
JARS="${ROOT}/tools/_jars"
mkdir -p "${BIN}" "${JARS}"

case "$(uname -s)" in
  Linux) OS="linux" ;;
  Darwin) OS="osx" ;;
  *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) PROTOC_ARCH="x86_64"; GRPC_ARCH="x86_64" ;;
  arm64|aarch64) PROTOC_ARCH="aarch_64"; GRPC_ARCH="aarch_64" ;;
  *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

echo ">> buf ${BUF_VERSION} -> tools/_bin/buf"
curl -fsSL "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/buf-$(uname -s)-$(uname -m)" -o "${BIN}/buf"
chmod 0755 "${BIN}/buf"

echo ">> Go plugins (protoc-gen-go, -go-grpc, -connect-go) -> tools/_bin"
GOBIN="${BIN}" go install "google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VERSION}"
GOBIN="${BIN}" go install "google.golang.org/grpc/cmd/protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VERSION}"
GOBIN="${BIN}" go install "connectrpc.com/connect/cmd/protoc-gen-connect-go@${PROTOC_GEN_CONNECT_GO_VERSION}"

echo ">> Python build tooling (grpcio-tools backs the protoc builtin bridge)"
python3 -m pip install --quiet --disable-pip-version-check -r "${ROOT}/examples/python/requirements.txt"

echo ">> Node tooling (protoc-gen-es + TypeScript runtime)"
( cd "${ROOT}" && npm ci )

echo ">> protoc ${PROTOC_VERSION} (Java/Kotlin builtins) -> tools/_bin/protoc"
tmp="$(mktemp -d)"
curl -fsSL "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-${OS}-${PROTOC_ARCH}.zip" -o "${tmp}/protoc.zip"
unzip -q -o "${tmp}/protoc.zip" -d "${tmp}/protoc"
install -m 0755 "${tmp}/protoc/bin/protoc" "${BIN}/protoc"
rm -rf "${tmp}"

echo ">> protoc-gen-grpc-java ${GRPC_JAVA_VERSION} -> tools/_bin"
curl -fsSL "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/${GRPC_JAVA_VERSION}/protoc-gen-grpc-java-${GRPC_JAVA_VERSION}-${OS}-${GRPC_ARCH}.exe" -o "${BIN}/protoc-gen-grpc-java"
chmod 0755 "${BIN}/protoc-gen-grpc-java"

echo ">> protoc-gen-grpc-kotlin ${GRPC_KOTLIN_VERSION} -> tools/_jars"
curl -fsSL "https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-kotlin/${GRPC_KOTLIN_VERSION}/protoc-gen-grpc-kotlin-${GRPC_KOTLIN_VERSION}-jdk8.jar" -o "${JARS}/protoc-gen-grpc-kotlin.jar"

echo ">> protoc-gen-connect-kotlin ${CONNECT_KOTLIN_VERSION} -> tools/_jars"
curl -fsSL "https://repo1.maven.org/maven2/com/connectrpc/protoc-gen-connect-kotlin/${CONNECT_KOTLIN_VERSION}/protoc-gen-connect-kotlin-${CONNECT_KOTLIN_VERSION}.jar" -o "${JARS}/protoc-gen-connect-kotlin.jar"

echo ">> done. Plugins installed under tools/_bin and tools/_jars."
