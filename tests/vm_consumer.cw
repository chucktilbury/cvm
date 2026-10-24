import cvmfile as IO
import cvmrun as VM
import cvm as CVM
import system as Sys

start {
    if (Sys.Process().argc() != 2 && Sys.Process().argc() != 3) { Sys.Process().exit(2) }
    IO.Result loaded = IO.Files().read(Sys.Process().arg(1))
    if (!loaded.ok()) {
        Sys.StandardIO().writeErrorLine(loaded.error())
        Sys.Process().exit(3)
    }
    VM.VirtualMachine machine = VM.VirtualMachine()
    VM.ExecutionResult result = null
    String mode = ""
    if (Sys.Process().argc() == 3) { mode = Sys.Process().arg(2) }
    if (mode.equals("handles")) {
        VM.ExecutionResult first = machine.run(loaded.bytes())
        VM.ExecutionResult second = machine.run(loaded.bytes())
        if (!first.ok() || !second.ok() || first.guestResult() <= 0 ||
            second.guestResult() <= first.guestResult()) { Sys.Process().exit(6) }
        CVM.InstructionBuilder code = CVM.InstructionBuilder()
        code.emit(CVM.Opcode.CONST_I32, first.guestResult())
        code.emit(CVM.Opcode.SYS, CVM.Service.FILE_CLOSE_HANDLE)
        code.emit(CVM.Opcode.CONST_I32, 0)
        code.emitNoOperand(CVM.Opcode.RET_I32)
        CVM.ContainerBuilder builder = CVM.ContainerBuilder()
        builder.addFunction("main", code.bytes(), buffer[], 0, 0, 1, 1)
        CVM.BuildResult encoded = builder.encode()
        if (!encoded.ok()) { Sys.Process().exit(7) }
        VM.ExecutionResult stale = machine.run(encoded.bytes())
        VM.ExecutionResult foreign = VM.VirtualMachine().run(encoded.bytes())
        if (stale.category() != VM.ExecutionResult.RUNTIME_TRAP ||
            foreign.category() != VM.ExecutionResult.RUNTIME_TRAP) { Sys.Process().exit(8) }
        Sys.StandardIO().writeLine(format("{}:{}", second.guestResult(),
            second.instructionsExecuted()))
        Sys.Process().exit(0)
    }
    if (mode.equals("repeat")) {
        int64 before = Sys.FileSystem().listDir("/proc/self/fd").length
        int64 iteration = 0
        while (iteration < 5) {
            result = machine.run(loaded.bytes())
            iteration = iteration + 1
        }
        int64 after = Sys.FileSystem().listDir("/proc/self/fd").length
        if (before != after) { Sys.Process().exit(5) }
    } else {
        if (mode.equals("steps")) {
        VM.Limits limits = VM.Limits(16777216, 1, 65536, 256, 16777216)
            result = machine.run(loaded.bytes(), limits)
        } else {
            if (mode.equals("no-stdout")) {
                result = machine.run(loaded.bytes(), VM.Limits(),
                    VM.Capabilities(true, false, true, 64))
            } else {
                if (mode.equals("no-files")) {
                    result = machine.run(loaded.bytes(), VM.Limits(),
                        VM.Capabilities(true, true, false, 64))
                } else {
                    if (mode.equals("zero-files")) {
                        result = machine.run(loaded.bytes(), VM.Limits(),
                            VM.Capabilities(true, true, true, 0))
                    } else {
                        result = machine.run(loaded.bytes())
                    }
                }
            }
        }
    }
    if (!result.ok()) {
        Sys.StandardIO().writeErrorLine(format("{}:{}:{}:{}",
            result.category(), result.functionIndex(),
            result.instructionOffset(), result.message()))
        Sys.Process().exit(4)
    }
    Sys.StandardIO().writeLine(format("{}:{}", result.guestResult(),
        result.instructionsExecuted()))
}
