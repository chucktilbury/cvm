# CVM interpreter

The installed `cvm-run` command loads a v1 container through the public
`cvmfile` byte adapter, validates it through the shared `cvm` library, and
executes it using the installable `cvmrun` 1.0.0 package. The runner is a
CWhip program using public SDK APIs; it does not need the source tree or
cparsegen after installation. Its file adapter enforces the program-byte
limit while reading, before retaining the complete input buffer.

```sh
cvm-as tests/fixtures/minimal.asm -o minimal.cvm
cvm-run minimal.cvm
# result: 42
```

On success, `cvm-run` prints `result: <signed-i32>` and exits with status 0,
independent of the guest result. It does not truncate or map the guest result
to a host process status. Usage errors exit 2. File, validation, load, runtime,
unsupported-service, and resource-limit errors exit 1 on stderr. Runtime
diagnostics include the function name and table index plus the
function-relative instruction byte offset. Validation diagnostics include
the validator's section and byte offset. The public API preserves these
categories and fields in `CVMRun.ExecutionResult`.

## Execution scope

The interpreter executes every non-service v1 opcode:

- Constants, typed scalar locals and globals, zero/initialized global and
  frame-local arrays, array length/load/store, and checked array bounds.
- Checked i32 add/subtract/multiply/divide/remainder/negation, signed
  comparisons, checked `to.u8`, zero-extending `to.i32`, `dup` and `pop`.
- Unconditional/zero branches, direct calls, and all return forms (`ret`,
  `ret.i32`, `ret.u8`, `ret.file`) with runtime signature, stack-depth and
  type checks.
- Entry execution requires the named `main` function to have signature
  `main() -> i32`. Its result is returned in the API and printed by the CLI.

Comparison results are i32 values 0 or 1; branch truth is any nonzero i32.
Call arguments are checked against declared parameter types and are copied
into a fresh frame. Scalar locals begin uninitialized; reading one before a
store traps. Each local array is created from its initializer or zero-filled
again on every function entry, and is invalidated on return. A caller may
keep its ArrayRef on its stack across a scalar-only call. Runtime checks are
performed even after structural validation because the validator does not
verify stack types, call signatures, all record contents, or reachability.

All nine `sys` services (IDs 0 through 8) trap as
`UNSUPPORTED_SERVICE` before any host I/O, with the service name and guest
instruction location. No console, stdin, filesystem, or fake-handle
implementation is provided. File values are type-checked, but no valid file
handle can be produced by this runner. DEBUG source annotations are not
currently decoded. This milestone is not a security sandbox.

## Deterministic limits

The CLI defaults are:

| Resource | Default | Maximum accepted by API/CLI |
|---|---:|---:|
| Container bytes | 16 MiB | 64 MiB |
| Executed instructions per run | 1,000,000 | 100,000,000 |
| Live operand-stack values and active scalar local slots | 65,536 | 1,048,576 |
| Active call frames, including entry | 256 | 4,096 |
| Live guest array heap (payload plus per-instance charge) | 16 MiB | 256 MiB |

Override them with `--max-program-bytes`, `--max-instructions`,
`--max-stack-values`, `--max-call-depth`, and `--max-heap-bytes`, each
followed by a decimal integer. Zero is permitted only for heap bytes. Invalid
limits are usage errors. The in-memory API accepts the same values through
`CVMRun.Limits(programBytes, instructions, stackValues, callDepth, heapBytes)`;
its no-argument constructor supplies the defaults. The stack-value limit also bounds local slots in active frames, preventing
deep calls to functions with large local tables from creating unbounded
state. Array heap accounting adds the payload bytes and a fixed 256-byte
logical charge for every live array instance, including frame-local
instances. This deterministic budget is not an estimate of exact host
allocator overhead. Container bytes, stack/local values and call frames have
separate limits.

## Public API

Import `cvmrun` as `CVMRun`. `CVMRun.VirtualMachine().run(buffer)` uses default
limits; `run(buffer, CVMRun.Limits(...))` uses caller-selected limits and
returns `CVMRun.ExecutionResult`. Inspect `ok()`, `category()`,
`guestResult()`, `message()`, `section()`, `byteOffset()`, `functionIndex()`,
`functionName()`, `instructionOffset()`, and `instructionsExecuted()`.
Categories distinguish success, load errors, structural validation errors,
runtime traps, unsupported services, and resource exhaustion.

Structural validation and the VM's execution checks are deliberately separate.
The runner repeats checks on decoded metadata, indexes, types, frame
transitions, array initialization/extents and instruction reads before use.
This is defensive execution behavior, not a guarantee that an accepted
program is safe, and should not be used as a security boundary.

## Tests

`tests/test_runner.py` assembles fixtures with the installed `cvm-as` and
runs the installed CLI away from the source tree with a restricted `PATH`.
It checks exact result output/status, arithmetic and conversion traps,
branches/loops, globals, arrays, frame isolation, nested calls, entry and
type errors, malformed/truncated files, unsupported services, invalid paths,
and all configurable resource limits. It also compiles an installed-package
consumer that exercises the in-memory VM API.
