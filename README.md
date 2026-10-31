# cvm

`cvm` is the Cwhip virtual machine: a portable stack VM with a v1 bytecode
format, assembler, and interpreter. Source:
[github.com/chucktilbury/cvm](https://github.com/chucktilbury/cvm).

This directory contains the assembler and runner in `src/`, installable
packages under `modules/` (`cvm`, `cvmfile`, `cvmrun`), the assembler grammar
in `grammar/`, tests in `tests/`, and build helpers in `scripts/`. `cvm-as`
needs a separately installed `cparsegen` on `PATH` at build time.

With a current Cwhip SDK installed, run `scripts/setup [--clean] [debug|release|profile]`
from the checkout, then `build` in the project shell. Use `rebuild` for a
clean-first build, or `clean` to remove generated outputs; exit the shell before
running setup again.

- [Bytecode and assembly specification](doc/BYTECODE-ASSEMBLY.md)
- [Bytecode library](doc/BYTECODE-LIBRARY.md)
- [Assembler](doc/ASSEMBLER.md)
- [Interpreter](doc/INTERPRETER.md)
- [Building](doc/BUILDING.md)
- [Project shell](doc/PROJECT-SHELL.md)
- [Changelog](doc/CHANGELOG.md)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
