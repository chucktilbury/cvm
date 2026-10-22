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
    VM.ExecutionResult result = null
    if (Sys.Process().argc() == 3 && Sys.Process().arg(2).equals("steps")) {
        VM.Limits limits = VM.Limits(16777216, 1, 65536, 256, 16777216)
        result = VM.VirtualMachine().run(loaded.bytes(), limits)
    } else {
        result = VM.VirtualMachine().run(loaded.bytes())
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
