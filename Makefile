# Local-only buf code generation + verification across Go, Python, TypeScript
# and Kotlin. All plugins live under tools/ after `make install`; nothing is
# fetched from the Buf Schema Registry at generation time.

BUF := tools/_bin/buf

.PHONY: all install lint generate test test-go test-python test-ts test-kotlin verify clean

all: generate test

## Install buf + every local code-generation plugin into the repo.
install:
	bash tools/install.sh

## Lint the protobuf sources.
lint:
	$(BUF) lint

## Generate stubs for every target language into gen/.
generate:
	$(BUF) generate

test-go:
	go test ./...

test-python:
	python3 examples/python/smoke_test.py

test-ts:
	npm run --silent typecheck
	npm run --silent smoke

test-kotlin:
	cd examples/kotlin && ./gradlew --no-daemon --console=plain run

## Build/run a smoke test that consumes the generated code in each language.
test: test-go test-python test-ts test-kotlin

## One-shot: generate everything then verify it in every language.
verify: generate test

clean:
	rm -rf gen examples/kotlin/build examples/kotlin/.gradle
