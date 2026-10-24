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
disabled-capability, I/O, configuration, and resource-limit errors exit 1 on
stderr. Runtime diagnostics include the function name and table index plus
the function-relative instruction byte offset. Validation diagnostics include
the validator's section and byte offset. The public API preserves these
categories and fields in `CVMRun.ExecutionResult`.

An unrecognized argument is treated as the input path, not rejected as an
unknown option. For example, `cvm-run --not-an-option` attempts to load a file
with that name and exits 1 if it cannot be opened; an additional input argument
is a usage error and exits 2.

## Execution scope

The interpreter executes every v1 opcode and all thirteen specified host services:

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

Services follow the exact signatures and behavior in
[the bytecode specification](BYTECODE-ASSEMBLY.md#6-runtime-services-and-io-boundary).
Console output is byte-exact, including NUL and high bytes; `stdin_byte`
returns one byte at a time or `-1` at EOF. Files are opened in binary mode.
Reads return short counts and zero at EOF; writes return actual positive
progress for nonempty requests so guests can retry short transfers. Host I/O
errors are distinct `IO_ERROR` results, never EOF or fake handles. Invalid,
stale, closed, or foreign file IDs trap. Handles are unique within a VM
instance; open handles are closed after normal return and after runtime or
service failure. Cleanup errors do not replace a primary failure.

Services 9..12 add integer descriptors without changing opaque `file`
services 4..8. See the [canonical service table](BYTECODE-ASSEMBLY.md#6-runtime-services-and-io-boundary)
for exact signatures, zero-length semantics and descriptor scope.
`file_open` accepts only NUL-terminated `r`, `w`, or `a` and always uses binary
I/O. `a` creates a missing file or preserves existing bytes and appends.
`file_read_handle`/`file_write_handle` use buffer index zero, never an offset.
The byte length must fit the fixed u8 array. An integer descriptor can pass
through ordinary i32 locals, globals, parameters and returns; it cannot be
used as an opaque `file`, or retained for another run.

**Compatibility:** earlier `cvmrun` builds trapped every `sys` instruction as
`UNSUPPORTED_SERVICE`. This version deliberately enables the specified
services by default. `--no-stdin`, `--no-stdout`, and `--no-files` (or the
matching `Capabilities` fields) retain an explicit `UNSUPPORTED_SERVICE`
failure for the corresponding disabled service group before host I/O.

`CVMRun.Capabilities` configures stdin, stdout, filesystem access, and the
maximum number of open file objects. All three capabilities are enabled by
default; the default open-file limit is 64 and the maximum is 4,096. The limit
counts the lazily opened stdin stream as well as guest files, so zero prevents
all new file opens, including stdin. The CLI capabilities can be restricted
with `--no-stdin`, `--no-stdout`, `--no-files`, and `--max-open-files N`. For
example:

```sh
cvm-run --no-files --max-open-files 0 program.cvm
```

The SDK currently exposes text-only standard input, which cannot represent
arbitrary bytes. To preserve the normative byte contract, `stdin_byte` opens
`/dev/stdin` as a separate binary `Sys.File` through the public SDK File API.
This follows the project's POSIX host target, but depends on that conventional
path; hosts without it receive a distinct I/O error. Cleanup closes the opened
file object, not the process's borrowed stdin descriptor. Execution is
synchronous and has no cancellation hook; process termination leaves final
descriptor reclamation to the operating system.

Filesystem capability controls guest file opens, not the container loader or
the host's ability to access paths. Paths are valid UTF-8 from the first-NUL
terminated guest byte array; paths are not constrained to a directory. CVM
provides no filesystem containment or security sandbox. The host must apply
any path policy needed for its deployment. DEBUG source annotations are not
currently decoded.

## Deterministic limits

The CLI defaults are:

| Resource | Default | Maximum accepted by API/CLI |
|---|---:|---:|
| Container bytes | 16 MiB | 64 MiB |
| Executed instructions per run | 1,000,000 | 100,000,000 |
| Live operand-stack values and active scalar local slots | 65,536 | 1,048,576 |
| Active call frames, including entry | 256 | 4,096 |
| Live guest array heap (payload plus per-instance charge) | 16 MiB | 256 MiB |
| Open guest file handles plus the lazily opened binary stdin stream | 64 | 4,096 |

Override them with `--max-program-bytes`, `--max-instructions`,
`--max-stack-values`, `--max-call-depth`, `--max-heap-bytes`, and
`--max-open-files`, each followed by a decimal integer. Zero is permitted for
heap bytes and open-file handles. Invalid limits are usage errors. The
in-memory API accepts the VM values through
`CVMRun.Limits(programBytes, instructions, stackValues, callDepth, heapBytes)`;
its no-argument constructor supplies the defaults. The stack-value limit also
bounds local slots in active frames, preventing deep calls to functions with
large local tables from creating unbounded state. Array heap accounting adds
the payload bytes and a fixed 256-byte
logical charge for every live array instance, including frame-local
instances. This deterministic budget is not an estimate of exact host
allocator overhead. Container bytes, stack/local values and call frames have
separate limits.

## Integer-file reproduction and SmallC lowering

From a built checkout, this fixture opens `integer-files.bin` with mode `w`,
writes the first three payload bytes (NUL, 128, 255), closes the descriptor,
and returns the actual progress count:

```sh
bin/cvm-as tests/fixtures/integer-files.asm -o build/integer-files.cvm
(cd build && ../bin/cvm-run integer-files.cvm)
# result: 3
od -An -tu1 build/integer-files.bin
# 0 128 255
```

The fixture is also exercised by the public assembler-to-runner suite. Its
regular-file three-byte write normally completes at once; applications must
still handle short positive progress for general host files.

The intended C-like pseudo-functions lower as follows (these are frontend
intrinsics, not new CVM guest function types):

| Frontend API | Left-to-right VM arguments | Service |
|---|---|---|
| `void print(char[])` | u8 ArrayRef, offset 0, length before first NUL | `stdout_write` (2); consume/retry actual progress |
| `int open(char[] path, char[] mode)` | path ArrayRef, mode ArrayRef | `file_open` (9) |
| `int read(int h, int n, char[] buf)` | h, buf ArrayRef, n | `file_read_handle` (10) |
| `int write(int h, int n, char[] buf)` | h, buf ArrayRef, n | `file_write_handle` (11) |
| `close(int h)` | h | `file_close_handle` (12), void result |

In particular the frontend's `(h, n, buf)` order must be reordered to
`(h, buf, n)` for the VM. Reads/writes use the requested byte length, not a
NUL scan: binary payloads can contain any byte. No integer-to-opaque-file
conversion or general guest array-parameter support is needed. A print
intrinsic must not leave `stdout_write`'s count on the stack when its
frontend return type is void.

## Public API

Import `cvmrun` as `CVMRun`. `CVMRun.VirtualMachine().run(buffer)` uses default
limits and capabilities; `run(buffer, CVMRun.Limits(...))` sets limits,
`run(buffer, CVMRun.Capabilities(...))` sets capabilities, and
`run(buffer, limits, capabilities)` sets both. Each returns
`CVMRun.ExecutionResult`. `Capabilities(stdinEnabled, stdoutEnabled,
filesEnabled, maxOpenFiles)` provides explicit host policy. Inspect `ok()`,
`category()`,
`guestResult()`, `message()`, `section()`, `byteOffset()`, `functionIndex()`,
`functionName()`, `instructionOffset()`, and `instructionsExecuted()`.
Categories distinguish success, load errors, structural validation errors,
runtime traps, disabled services, I/O errors, configuration errors, and
resource exhaustion.

Structural validation and the VM's execution checks are deliberately separate.
The runner repeats checks on decoded metadata, indexes, types, frame
transitions, array initialization/extents and instruction reads before use.
This is defensive execution behavior, not a guarantee that an accepted
program is safe, and should not be used as a security boundary.

## Tests

`tests/test_runner.py` assembles fixtures with the installed `cvm-as` and
runs the installed CLI away from the source tree with a restricted `PATH`.
It checks exact input/output bytes, EOF, binary copies including all 256 byte
values, empty and multichunk files, UTF-8 and invalid paths, stale handles,
file errors, capability switches, limits, cleanup after success and traps,
and the existing opcode/runtime regression cases. Linux-specific
`/proc/self/mem`, `/dev/full`, and descriptor-cleanup fixtures are platform
gated. The suite also compiles an installed-package consumer that exercises
the in-memory VM API and repeated-run cleanup.
Integer-service cases additionally cover exact modes, append/create/truncate,
all 256 bytes including invalid UTF-8, bounded and short reads, untouched
buffer suffixes, zero requests, wrong access modes, double close and
close/reopen non-aliasing, mixed opaque/integer open-file limits, repeated-run
registry isolation, and cleanup after service and arithmetic traps.
Regular-file writes do not portably force a successful short write, and
exhausting 2,147,483,647 issued tokens is not a practical conformance fixture;
those paths are checked in the runtime's progress and pre-open range guards.
