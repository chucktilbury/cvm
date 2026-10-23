# CVM bytecode library

The installable CWhip package is named `cvm`, exports namespace `CVM`, and is
versioned `1.0.0`. CMake installs it to
`share/cwhip/modules/cvm/1.0.0/`. Consumers import it with `import cvm` and
use the `CVM` namespace. The package contains no compiler/runtime private
headers, native shims, or build-time dependency on the CVM source tree.

## Public API

- `CVM.Format` publishes v1 header, directory, section, and fixed-record
  sizes/identifiers.
- `CVM.Opcode` publishes the complete opcode-number set, validity and operand
  width/kind queries, mnemonic names, and human-readable operand schemas.
- `CVM.Service` publishes the v1 service IDs, assembly names and parameter/
  result counts. The installable `cvmrun` package implements these contracts
  through public CWhip SDK APIs; the metadata remains canonical.
- `CVM.ByteReader` reads u8/u16/u32/i32 values in little-endian order from a
  CWhip `buffer`. Reads past the input set `TRUNCATED` and preserve the first
  failing byte offset. `seek`, `offset`, `errorCode`, and `errorOffset`
  expose the reader state.
- `CVM.ByteWriter` writes range-checked u8/u16/u32/i32 values. An invalid
  value sets `RANGE_ERROR`; subsequent writes fail without changing the
  output. Use `bytes()` to obtain the current buffer.
- `CVM.InstructionBuilder` emits every v1 opcode using the canonical operand
  width and range rules. `emitNoOperand` rejects instructions that require an
  operand; `emit` rejects unknown opcodes and out-of-range operands.
- `CVM.ContainerBuilder` creates the required seven sections, accepts checked
  function/global/array records, and serializes the v1 header and directory.
  `addFunction` consumes already encoded code and parameter/local type bytes;
  the instruction builder can be used to produce the code. `addArray` accepts
  either an initializer buffer of the exact element width or an empty buffer
  for zero-initialized storage. `encode` returns `CVM.BuildResult` and rejects
  invalid or oversized containers. `setDebug` adds the optional DEBUG table;
  `addOptionalSection` adds unknown optional records (including IDs below the
  known required sections) and emits them in ascending directory order.
- `CVM.ContainerValidator.validate(buffer)` returns
  `CVM.ValidationResult`; callers inspect `valid`, `code`, `section`, `offset`,
  and `message` rather than parsing a display string.
- `CVM.ContainerDecoder.decode(buffer)` validates and exposes the entry
  function, directory counts, per-section count units, and copied raw section
  buffers through `CVM.ContainerDecodeResult`. Unknown optional sections are
  retained as raw section data; callers can preserve their bytes and counts
  when transforming containers.

The initial validator checks the magic, supported version, fixed header and
reserved fields, directory order/flags, required sections, exact record and
byte counts, tightly packed section extents, exact file size, entry index,
function code extents, function names, instruction opcodes and operand
truncation, local/global/array/function/service indexes, in-function branch
targets, and instruction-boundary branch targets. All indexes and extents
are checked before slicing or indexed reads.

This is **structural validation only**, not a verifier or security boundary.
It does not yet check global/array record contents and initializers, all string
references, DEBUG records, UTF-8 validity, data/type range overlap,
array ownership, call signatures, stack/type dataflow or joins, reachable
fallthrough, return correctness, maximum stack declarations, or runtime
behavior. The `cvm` library does not execute bytecode. The separate
`cvmrun` package defensively checks data it consumes and traps on invalid
runtime transitions, but is not a verifier or security boundary. Do not treat
a structurally accepted file as safe to execute.

## Byte I/O boundary

The codec operates on CWhip `buffer` objects and is independent of file access.
The separate installable `cvmfile` 1.0.0 package provides `CVMFile.Files.read`
and `write` over the public SDK's `File.readBytes` and `writeBytes` APIs.
It handles partial transfers, SDK errors, EOF and explicit resource cleanup
without converting binary data through String. It requires the SDK binary
File API addition (Cwhip PR #20 or newer); the pure `cvm` package does not.
See [the assembler/adapter guide](ASSEMBLER.md#reusable-binary-file-adapter)
for the result API and failure policy. Installed-consumer tests reload actual
assembler output and preserve all 256 byte values through files.

## Specification golden

The 32-byte header in section 2.3 of
[the specification](BYTECODE-ASSEMBLY.md#23-numeric-golden-example) encodes
`07 00` at header offsets 12-13, matching the normative minimum section count
and the seven directory entries in the 183-byte minimal container. The
conformance test checks this exact header and verifies the complete container
with an independent decoder.
