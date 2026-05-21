#!/usr/bin/env python3
"""Expose protoc's *builtin* code generators as a standard buf/protoc plugin.

Several first-party generators (Python, Python gRPC, Java, Kotlin, ...) ship
only as builtins compiled into `protoc` -- there is no standalone
`protoc-gen-python` / `protoc-gen-java` binary to hand to buf. buf only drives
plugins that speak CodeGeneratorRequest on stdin / CodeGeneratorResponse on
stdout, so it cannot invoke those builtins directly.

This bridge closes that gap. It reads the CodeGeneratorRequest that buf sends,
replays it through a real protoc (using --descriptor_set_in so no .proto source
or include paths are required), and repackages the produced files back into a
CodeGeneratorResponse. The result is fully local, first-party output driven by
`buf generate`.

Usage:
    protoc_builtin_bridge.py --protoc <cmd> <generator> [<generator> ...]

    --protoc <cmd>  "grpc_tools" -> python -m grpc_tools.protoc (Python builtins)
                    any other value -> a path to / name of a real protoc binary
                    (used for the Java/Kotlin builtins)
    generator       one or more of: python, grpc_python, pyi, java, kotlin
                    (each maps to protoc's --<generator>_out flag)
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile

from google.protobuf import descriptor_pb2
from google.protobuf.compiler import plugin_pb2

_KNOWN_GENERATORS = {"python", "grpc_python", "pyi", "java", "kotlin"}


def _protoc_command(cmd: str) -> list[str]:
    if cmd == "grpc_tools":
        return [sys.executable, "-m", "grpc_tools.protoc"]
    return [cmd]


def _run() -> int:
    if len(sys.argv) < 4 or sys.argv[1] != "--protoc":
        sys.stderr.write(__doc__ or "")
        return 2

    protoc_cmd = sys.argv[2]
    generators = sys.argv[3:]
    for name in generators:
        if name not in _KNOWN_GENERATORS:
            sys.stderr.write(f"protoc_builtin_bridge: unknown generator {name!r}\n")
            return 2

    request = plugin_pb2.CodeGeneratorRequest.FromString(sys.stdin.buffer.read())

    # buf already hands us every transitive descriptor in dependency order, so a
    # FileDescriptorSet lets protoc resolve all imports without source access.
    fds = descriptor_pb2.FileDescriptorSet(file=request.proto_file)

    response = plugin_pb2.CodeGeneratorResponse()
    response.supported_features = (
        plugin_pb2.CodeGeneratorResponse.FEATURE_PROTO3_OPTIONAL
    )

    with tempfile.TemporaryDirectory() as workdir:
        descriptor_path = os.path.join(workdir, "image.binpb")
        with open(descriptor_path, "wb") as handle:
            handle.write(fds.SerializeToString())

        out_dir = os.path.join(workdir, "out")
        os.makedirs(out_dir, exist_ok=True)

        cmd = _protoc_command(protoc_cmd)
        cmd.append(f"--descriptor_set_in={descriptor_path}")
        for name in generators:
            cmd.append(f"--{name}_out={out_dir}")
            if request.parameter:
                cmd.append(f"--{name}_opt={request.parameter}")
        cmd.extend(request.file_to_generate)

        proc = subprocess.run(cmd, capture_output=True)
        if proc.returncode != 0:
            sys.stderr.buffer.write(proc.stderr)
            return proc.returncode

        for root, _dirs, files in os.walk(out_dir):
            for filename in files:
                abs_path = os.path.join(root, filename)
                rel_path = os.path.relpath(abs_path, out_dir)
                with open(abs_path, "rb") as handle:
                    content = handle.read()
                out_file = response.file.add()
                out_file.name = rel_path.replace(os.sep, "/")
                out_file.content = content.decode("utf-8")

    sys.stdout.buffer.write(response.SerializeToString())
    return 0


if __name__ == "__main__":
    raise SystemExit(_run())
