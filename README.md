# CVM: CWhip Virtual Machine

CVM is a proposed portable stack virtual machine and assembler implemented in
CWhip. The bytecode format, instruction set, assembly syntax, and runtime
boundary are described in the [proposed v1 specification](doc/BYTECODE-ASSEMBLY.md).
That document is a design target, not a claim that the VM, assembler, shared
bytecode library, or SmallC backend is implemented.

This repository currently retains the CWhip project starter build shell. Its
`src/main.cw` hello-world is still a template sample; CMake builds it into the
project's `bin/` directory. It is not the VM or assembler.

## Get started

Install the complete CWhip SDK prefix and its host prerequisites. SDK selection
uses a non-empty `CWHIP_SDK` override first, then the top-level `sdk_prefix`
string in `$XDG_CONFIG_HOME/cwhip/sdk.toml` (or
`$HOME/.config/cwhip/sdk.toml` when `XDG_CONFIG_HOME` is unset/empty).
Only when `sdk.toml` is absent is the legacy `settings.toml` consulted.
Without a selected prefix, use normal CMake discovery
through `CMAKE_PREFIX_PATH` or `Cwhip_DIR`. Both direct CMake configuration and
`scripts/setup` use this order. Reading settings requires Python 3.11+.
Then start the project shell and build:

```sh
./scripts/setup
cmake --build .
../bin/hello
```

The default build type is `debug`. Choose `release` or `profile` with
`./scripts/setup release` or `./scripts/setup profile`.

See [Building](doc/BUILDING.md) for SDK selection and output-directory
customization, and [Project shell](doc/PROJECT-SHELL.md) for the shell
environment and available commands. See the [changelog](doc/CHANGELOG.md) for
starter-shell history.
