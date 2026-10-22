# CVM: CWhip Virtual Machine

CVM is a portable stack virtual machine project implemented in CWhip. Its
approved v1 bytecode format and assembly syntax are described in the
[specification](doc/BYTECODE-ASSEMBLY.md).

The first implementation milestone is the versioned `cvm` shared bytecode
package (`CVM`, version `1.0.0`). It provides canonical v1 format/opcode
definitions, checked byte readers and writers, instruction and container
builders, and structural validation. The package is installed under
`share/cwhip/modules/cvm/1.0.0` for import by other CWhip applications.

This milestone does **not** implement the assembler, interpreter, runtime
services, or SmallC backend. Validation checks the container structure,
function extents, instruction encoding, table indexes, and branch boundaries;
it does not claim control-flow, stack/type, return, or execution safety. The
full boundary and public APIs are documented in
[the bytecode library guide](doc/BYTECODE-LIBRARY.md).

The template `src/main.cw` hello-world remains as a build-shell example.

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
implementation history.
