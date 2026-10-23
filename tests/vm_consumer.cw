import cvmfile as IO
import cvmrun as VM
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
    if (mode.equals("repeat")) {
        int before = Sys.FileSystem().listDir("/proc/self/fd").length
        int iteration = 0
        while (iteration < 5) {
            result = machine.run(loaded.bytes())
            iteration = iteration + 1
        }
        int after = Sys.FileSystem().listDir("/proc/self/fd").length
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
