# buf-grpc-examples

A **local-only** [buf](https://buf.build) setup that generates gRPC and
[Connect](https://connectrpc.com) stubs for **Go, Python, TypeScript, and
Kotlin** from a single `.proto` file — and a CI job that proves the generated
code compiles and runs in every language.

"Local only" means `buf generate` never calls the Buf Schema Registry for
[remote plugins](https://buf.build/docs/bsr/remote-plugins/usage/). Every plugin
runs from `tools/` on your machine (see [How it works](#how-it-works)).

## Target matrix

| Language   | Messages                         | gRPC                                            | Connect                          |
| ---------- | -------------------------------- | ----------------------------------------------- | -------------------------------- |
| Go         | `protoc-gen-go`                  | `protoc-gen-go-grpc`                             | `protoc-gen-connect-go`          |
| Python     | `protoc` builtin (via bridge)    | `protoc` `grpc_python` builtin (via bridge)     | — *(no first-party generator)*   |
| TypeScript | `protoc-gen-es`                  | via the Connect-ES runtime (gRPC / gRPC-Web)    | `protoc-gen-es` + Connect-ES     |
| Kotlin     | `protoc` java/kotlin builtins    | `protoc-gen-grpc-java` + `protoc-gen-grpc-kotlin` | `protoc-gen-connect-kotlin`     |

## Requirements

Language toolchains only — everything else is fetched by `make install`:

- Go 1.25+
- Node.js 22+
- Python 3.11+
- JDK 21+

## Quick start

```bash
make install     # buf + every codegen plugin -> tools/_bin, tools/_jars, node_modules
make generate    # buf generate -> gen/{go,python,ts,kotlin}
make test        # compile + run a smoke test in each language
```

`make verify` runs `generate` + `test` in one go.

## Layout

```
proto/greet/v1/greet.proto   # the single source service
buf.yaml                     # module + lint config
buf.gen.yaml                 # all local plugins, one per target
tools/install.sh             # fetches buf + every plugin into the repo (pinned)
tools/protoc_builtin_bridge.py  # exposes protoc builtins as a buf plugin
examples/{go,python,ts,kotlin}  # smoke tests that consume gen/
gen/                         # generated output (git-ignored; run `make generate`)
.github/workflows/ci.yml     # installs, generates, and verifies all four
```

## How it works

`buf.gen.yaml` uses only [`local` plugins](https://buf.build/docs/configuration/v2/buf-gen-yaml/#local).
Most are ordinary protoc plugins (`protoc-gen-go`, `protoc-gen-es`, the Kotlin
jars, the grpc-java native binary).

The exception is the first-party **Python** and **Java/Kotlin** generators,
which ship only as *builtins compiled into `protoc`* — there is no standalone
`protoc-gen-python` / `protoc-gen-java` binary for buf to call.
`tools/protoc_builtin_bridge.py` bridges that gap: it reads the
`CodeGeneratorRequest` buf hands it, replays it through a real `protoc` (via
`--descriptor_set_in`, so no `.proto` source or include paths are needed), and
repackages the result into a `CodeGeneratorResponse`. The output is exactly what
`protoc --python_out` / `--java_out` / `--kotlin_out` produces, but driven by
`buf generate`.

## CI

`.github/workflows/ci.yml` runs the same `make install → lint → generate → test`
path on every push and pull request, confirming the local setup generates valid,
compilable stubs for all four languages.
