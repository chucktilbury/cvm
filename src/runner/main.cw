import cvmfile as IO
import cvmrun as VM
import system as Sys

class RunnerCLI {
    int parseLimit(String text, int maximum, bool allowZero) {
        if (text.length == 0) { return -1 }
        int value = 0
        int index = 0
        while (index < text.length) {
            int byte = int(text.byteAt(index))
            if (byte < 48 || byte > 57) { return -1 }
            int digit = byte - 48
            if (value > (maximum - digit) / 10) { return -1 }
            value = value * 10 + digit
            index = index + 1
        }
        if (!allowZero && value == 0) { return -1 }
        return value
    }

    String usage() {
        return "usage: cvm-run [--max-program-bytes N] [--max-instructions N] [--max-stack-values N] [--max-call-depth N] [--max-heap-bytes N] INPUT.cvm"
    }

    void usageError() {
        Sys.StandardIO().writeErrorLine(usage())
    }

    int run() {
        Sys.Process process = Sys.Process()
        if (process.argc() == 2 && process.arg(1).equals("--help")) {
            Sys.StandardIO().writeLine(usage())
            return 0
        }

        VM.Limits defaults = VM.Limits()
        int programBytes = defaults.programBytes()
        int instructions = defaults.instructions()
        int stackValues = defaults.stackValues()
        int callDepth = defaults.callDepth()
        int heapBytes = defaults.heapBytes()
        String input = ""
        int index = 1
        while (index < process.argc()) {
            String argument = process.arg(index)
            if (argument.equals("--max-program-bytes") || argument.equals("--max-instructions") || argument.equals("--max-stack-values") || argument.equals("--max-call-depth") || argument.equals("--max-heap-bytes")) {
                if (index + 1 >= process.argc()) {
                    usageError()
                    return 2
                }
                int maximum = VM.Limits.MAX_PROGRAM_BYTES
                bool allowZero = false
                if (argument.equals("--max-program-bytes")) { maximum = VM.Limits.MAX_PROGRAM_BYTES }
                if (argument.equals("--max-instructions")) { maximum = VM.Limits.MAX_INSTRUCTIONS }
                if (argument.equals("--max-stack-values")) { maximum = VM.Limits.MAX_STACK_VALUES }
                if (argument.equals("--max-call-depth")) { maximum = VM.Limits.MAX_CALL_DEPTH }
                if (argument.equals("--max-heap-bytes")) {
                    maximum = VM.Limits.MAX_HEAP_BYTES
                    allowZero = true
                }
                int value = parseLimit(process.arg(index + 1), maximum, allowZero)
                if (value < 0) {
                    usageError()
                    return 2
                }
                if (argument.equals("--max-program-bytes")) { programBytes = value }
                if (argument.equals("--max-instructions")) { instructions = value }
                if (argument.equals("--max-stack-values")) { stackValues = value }
                if (argument.equals("--max-call-depth")) { callDepth = value }
                if (argument.equals("--max-heap-bytes")) { heapBytes = value }
                index = index + 2
            } else {
                if (!input.equals("")) {
                    usageError()
                    return 2
                }
                input = argument
                index = index + 1
            }
        }
        if (input.equals("")) {
            usageError()
            return 2
        }
        VM.Limits limits = VM.Limits(programBytes, instructions, stackValues, callDepth, heapBytes)
        if (!limits.valid()) {
            usageError()
            return 2
        }

        IO.Result loaded = IO.Files().readLimited(input, limits.programBytes())
        if (!loaded.ok()) {
            String category = "load"
            if (loaded.category() == IO.Result.LIMIT_EXCEEDED) { category = "resource limit" }
            Sys.StandardIO().writeErrorLine(format("{}: {}: {}", input, category, loaded.error()))
            return 1
        }
        VM.ExecutionResult result = VM.VirtualMachine().run(loaded.bytes(), limits)
        if (result.ok()) {
            Sys.StandardIO().writeLine(format("result: {}", result.guestResult()))
            return 0
        }

        String category = "runtime trap"
        if (result.category() == VM.ExecutionResult.LOAD_ERROR) { category = "load" }
        if (result.category() == VM.ExecutionResult.VALIDATION_ERROR) { category = "validation" }
        if (result.category() == VM.ExecutionResult.UNSUPPORTED_SERVICE) { category = "unsupported service" }
        if (result.category() == VM.ExecutionResult.RESOURCE_LIMIT) { category = "resource limit" }
        String detail = ""
        if (result.functionIndex() >= 0) {
            detail = format(" function {}[{}]", result.functionName(), result.functionIndex())
            if (result.instructionOffset() >= 0) {
                detail.append(format("+{}", result.instructionOffset()))
            }
        }
        if (result.functionIndex() < 0 && result.category() == VM.ExecutionResult.VALIDATION_ERROR) {
            detail = format(" section {} byte {}", result.section(), result.byteOffset())
        }
        if (result.functionIndex() < 0 && result.category() == VM.ExecutionResult.LOAD_ERROR && result.section() != 0) {
            detail = format(" section {} byte {}", result.section(), result.byteOffset())
        }
        String diagnostic = format("{}: {}", input, category)
        if (!detail.equals("")) { diagnostic.append(format(":{}", detail)) }
        diagnostic.append(format(": {}", result.message()))
        Sys.StandardIO().writeErrorLine(diagnostic)
        return 1
    }
}

start { Sys.Process().exit(RunnerCLI().run()) }
