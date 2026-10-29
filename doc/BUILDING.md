# Building

CVM consumes the installed CWhip SDK; it does not build or download
the compiler or SDK for you. Use the complete SDK installation prefix, not
just its `bin/` directory. CMake requires Cwhip SDK version `0.0.2`, the
`numeric-v2` ABI, and an
installation that supports configurable application output directories and
the public binary `File.readBytes`, `readAllBytes`, and `writeBytes` APIs.
The numeric ABI and public C header are checked during configuration, and
configuration also checks the binary file API signatures. Use a current SDK
with parenthesized keyword arguments (`return(value)` and `raise(error)`),
string indexing (`text[index]`, with no `String.byteAt` or `String.slice`),
postfix callable types (`int64<int64>`), and bracket dictionary literals
(`[key: value]`, `[:]`). An older numeric-v2 SDK is not necessarily
source-compatible. No SDK is built, downloaded or overwritten by CVM.

The installed SDK must also provide `cwhip_apply_application_defaults`
([chucktilbury/cwhip#21](https://github.com/chucktilbury/cwhip/pull/21) or newer).
Updating the Cwhip source checkout alone is insufficient: rebuild and reinstall
the SDK at the selected prefix before configuring CVM. Configuration reports
that prefix and an actionable error when this capability is missing; it does
not silently fall back to older behavior.

An installed cparsegen supporting `--library` and emitting the current CWhip
syntax with explicit `int64` parser indices is also required at build time.
Put its executable on `PATH` or pass
`-DCPARSEGEN_EXECUTABLE=/absolute/path/to/cparsegen` to CMake. It generates
CWhip from the CVM-owned `grammar/assembly.cpg` in `build/assembler/`.
No cparsegen source checkout is required or used by CVM, and the installed
assembler needs neither the generator nor its grammar at runtime.
The generated source is compiled as emitted; CVM does not rewrite legacy
types or keyword syntax. Upgrade cparsegen as well as the SDK when migrating
an older installation.

CVM's assembly language is independent of CWhip syntax: assembly semicolon
comments and brace-delimited array initializers remain unchanged. The CWhip
implementation uses parenthesized return expressions; it contains no callable
types, dictionary literals, or mixed bitwise/comparison expressions requiring
additional migration.

Run `scripts/setup --clean` after updating the SDK or cparsegen so package
locks and generated parser sources are recreated for the selected tools.

## Select an SDK

`scripts/setup` (and direct CMake configuration) selects the SDK in this exact
order:

1. An explicit, non-empty `CWHIP_SDK` environment variable.
2. The top-level TOML string `sdk_prefix` in
   `$XDG_CONFIG_HOME/cwhip/sdk.toml`, or
   `$HOME/.config/cwhip/sdk.toml` when `XDG_CONFIG_HOME` is unset/empty.
3. The legacy `settings.toml` file in that same directory, **only if
   `sdk.toml` is absent**.
4. Normal CMake package discovery, including `CMAKE_PREFIX_PATH` and
   `Cwhip_DIR`, when neither selection is present.

For example, the dedicated SDK configuration file `cwhip/sdk.toml` can contain:

```toml
sdk_prefix = "/absolute/path/to/installed/sdk"
```

This matches the compiler installer's SDK registration location and keeps SDK
selection separate from editor/debugger preferences in `settings.toml`.
Rewriting those preferences cannot erase the dedicated SDK selection.
A non-empty `XDG_CONFIG_HOME` must be absolute and selects the only config root:
a missing file there does not fall back to the home settings file.
If neither `XDG_CONFIG_HOME` nor `HOME` is available, the template retains
normal CMake discovery. An explicit `CWHIP_SDK` bypasses config-home lookup.

The value is the **whole installation prefix**, not its `bin/` directory or
the CMake package directory. Paths with spaces and TOML-escaped quotes are
preserved; TOML literal strings are also supported. A settings prefix must
be a non-empty absolute path to an existing directory, without NUL or line
breaks. Python 3.11+ (`tomllib`) is required only when reading an existing
settings file; `scripts/setup` uses `python3`, while direct CMake configuration
uses CMake's Python3 interpreter discovery.

The Cwhip installer also registers application defaults in the same file:

```toml
[applications]
install_prefix = "/absolute/path/to/installed/sdk"
build_type = "Release"
```

These values describe the actual Cwhip installation prefix and the build
configuration used to produce that SDK. CVM calls the SDK's
`cwhip_apply_application_defaults()` helper after finding Cwhip but before
`project()`. For a registration whose `sdk_prefix` matches the selected SDK,
the helper provides defaults for `CMAKE_INSTALL_PREFIX` and
`CMAKE_BUILD_TYPE`; explicit command-line values and values already stored in
the build cache, including empty values, take precedence. Explicit
`CMAKE_INSTALL_PREFIX` and `CMAKE_BUILD_TYPE` environment values also take
precedence. CVM does not edit `sdk.toml`, share the SDK's build directory, or
add arbitrary compiler flags. `cmake --install --prefix` can still select a
one-off installation location, and `DESTDIR` stages an installation without
changing the registered prefix.

To temporarily override the shared setting:

```sh
export CWHIP_SDK="/path/to/cwhip-sdk"
./scripts/setup
```

An explicit non-empty `CWHIP_SDK` bypasses both configuration files for SDK
prefix selection and TOML validation, even if they are malformed. The SDK's
application-defaults helper is still called and may read a matching registration
from `sdk.toml`; this override does not disable application defaults.
An unset or empty override allows settings discovery.
A missing file or absent top-level key leaves normal CMake discovery unchanged.
An existing `sdk.toml` is authoritative even without a top-level `sdk_prefix`:
it never falls back to legacy preferences. An explicitly empty `sdk_prefix`
is invalid, not an instruction to use legacy preferences. When discovering a
prefix from configuration, malformed TOML, an invalid value, or an unreadable
selected configuration file stops configuration with a diagnostic; it does not
silently select another SDK.

When either `CWHIP_SDK` or `sdk_prefix` selects a prefix, CMake searches only
that prefix and clears the previously cached `Cwhip_DIR`. A prefix without a
compatible Cwhip package fails configuration rather than falling back. To
return to normal CMake discovery, unset `CWHIP_SDK` and remove the
`sdk_prefix` setting from `sdk.toml` (or from legacy `settings.toml` if no
`sdk.toml` exists), and clear `Cwhip_DIR` in an existing build cache if
needed.

The template never edits user settings or copies the SDK into the project.

## Configure and build

`scripts/setup [--clean] [debug|release|profile]` configures the `build/`
directory and launches an interactive
project shell there. An explicit build type overrides the SDK and cache; when
omitted, CVM leaves `CMAKE_BUILD_TYPE` unset on the CMake command line so the
SDK helper or existing build cache can provide it:

| Argument | CMake build type |
| --- | --- |
| `debug` | `Debug` |
| `release` | `Release` |
| `profile` | `RelWithDebInfo` |

Build and run the example from the project shell:

```sh
scripts/setup --clean release
# In the project shell (build/):
build
../bin/hello
../bin/cvm-as ../tests/fixtures/minimal.asm -o minimal.cvm
rebuild hello
```

Omit `--clean` to preserve the existing build cache and outputs. The flag may
also follow the build type. `build [TARGET...]` and `rebuild [TARGET...]` are
Bash functions; the latter cleans before building without reconfiguring.
Both return CMake's status and leave the project shell running.

The Cwhip application helper writes generated sources and package metadata
inside the build tree. The compiled application is written directly to
`bin/`. Neither `bin/` nor `lib/` is created during configuration; the build
creates an output directory only when a target needs it.

## Customize output directories

The cache variables `CWHIP_BIN_DIR` and `CWHIP_LIB_DIR` choose output
locations. They default to the project-root `bin/` and `lib/`; native runtime
targets use the former, and native library/archive targets use the latter.
For custom cache variables, direct CMake configuration is needed because
setup accepts only the clean flag and build type. Configure once, then enter
the normal project shell:

```sh
cmake -S . -B build \
  -DCWHIP_BIN_DIR="$PWD/out/bin" \
  -DCWHIP_LIB_DIR="$PWD/out/lib"
scripts/setup
# In the project shell:
build
```

The starter Cwhip executable follows `CWHIP_BIN_DIR`. Generated output
directories are ignored by Git.

The assembler follows the same output variable. Its explicit compile rule
isolates HOME/XDG settings and selects the installed SDK resources plus
the CVM-owned package root, without copying CVM packages into the SDK.
For automation without an interactive shell, use CMake directly (setup opens
an interactive Bash shell and does not accept arbitrary CMake options):

```sh
export CWHIP_SDK=/path/to/binary-io-sdk
cmake -S . -B build \
  -DCPARSEGEN_EXECUTABLE=/path/to/bin/cparsegen -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel 2
cmake --install build --prefix "$PWD/build/install"
build/install/bin/cvm-as tests/fixtures/minimal.asm -o build/minimal.cvm
```

Install includes `bin/cvm-as`, `bin/cvm-run`, the template `bin/hello`, and
versioned `cvm`, `cvmfile`, and `cvmrun` modules under
`share/cwhip/modules`. The installed runner does not require cparsegen or the
source tree at runtime.

## Clean

From the project shell, use the retained cleanup script to remove the default
`build/`, `bin/`, `lib/`, `doc/out/`, and `share/` directories:

```sh
clean
exit
scripts/setup release
```

For a full clean reconfiguration in one step, exit any project shell and run
`scripts/setup --clean [debug|release|profile]`. To clean build artifacts while
retaining the CMake cache, use `build clean`; `rebuild` cleans and builds again.
Custom output paths are not removed by the cleanup script and must be cleaned
separately.

## Test template discovery

Run the discovery regression suite with Python 3.11+, CMake 3.24+, and a host
C compiler:

```sh
python3 -m unittest discover -s tests -p test_sdk_discovery.py -v
```

The discovery suite uses temporary mock SDK packages, a mock build-time
generator and isolated home directories. It also covers cleanup ordering,
argument validation, the active-shell guard, and build/rebuild function
argument forwarding and failure statuses.
It exercises real CMake configuration, setup's shell handoff, and the shell's
SDK search path without requiring an installed CWhip compiler or user input.
The filename filter excludes the installed-consumer suites, which require
both `CWHIP_SDK` and `CVM_BUILD_DIR`; CTest supplies these for the configured
build below. The discovery suite is also registered with CTest, so a full
CTest run covers both discovery and installed consumers.

The bytecode and assembler installed-consumer conformance tests use the selected
installed CWhip SDK. Configure and build first, then run:

```sh
ctest --test-dir build --output-on-failure
```

That test installs into a temporary prefix, copies the installed package to a
separate CWhip consumer project, and checks the 183-byte container against an
independent decoder and the normative section layouts.
The assembler suite also runs the installed tool away from the checkout with
no cparsegen/SDK runtime environment; checks complete approved-example
goldens and every opcode/service; and reloads accepted output using the
public byte-file adapter and structural validator. See [Assembler](ASSEMBLER.md)
for supported syntax and remaining verification limits.
