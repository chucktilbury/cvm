import cvmfile as IO
import cvmrun as VM
import system as Sys

class RunnerCLI {
    int64 parseLimit(String text, int64 maximum, bool allowZero) {
        if (text.length == 0) { return(-1) }
        int64 value = 0
        int64 index = 0
        while (index < text.length) {
            int64 byte = int64(text[index])
            if (byte < 48 || byte > 57) { return(-1) }
            int64 digit = byte - 48
            if (value > (maximum - digit) / 10) { return(-1) }
            value = value * 10 + digit
            index = index + 1
        }
        if (!allowZero && value == 0) { return(-1) }
        return(value)
    }

    String usage() {
        return("usage: cvm-run [--max-program-bytes N] [--max-instructions N] [--max-stack-values N] [--max-call-depth N] [--max-heap-bytes N] [--max-open-files N] [--no-stdin] [--no-stdout] [--no-files] INPUT.cvm")
    }

    void usageError() {
        Sys.StandardIO().writeErrorLine(usage())
    }

    int64 run() {
        Sys.Process process = Sys.Process()
        if (process.argc() == 2 && process.arg(1).equals("--help")) {
            Sys.StandardIO().writeLine(usage())
            return(0)
        }

        VM.Limits defaults = VM.Limits()
        int64 programBytes = defaults.programBytes()
        int64 instructions = defaults.instructions()
        int64 stackValues = defaults.stackValues()
        int64 callDepth = defaults.callDepth()
        int64 heapBytes = defaults.heapBytes()
        VM.Capabilities defaultCapabilities = VM.Capabilities()
        bool stdinEnabled = defaultCapabilities.stdinEnabled()
        bool stdoutEnabled = defaultCapabilities.stdoutEnabled()
        bool filesEnabled = defaultCapabilities.filesEnabled()
        int64 maxOpenFiles = defaultCapabilities.maxOpenFiles()
        String input = ""
        int64 index = 1
        while (index < process.argc()) {
            String argument = process.arg(index)
            if (argument.equals("--no-stdin")) {
                stdinEnabled = false
                index = index + 1
            } else {
                if (argument.equals("--no-stdout")) {
                    stdoutEnabled = false
                    index = index + 1
                } else {
                    if (argument.equals("--no-files")) {
                        filesEnabled = false
                        index = index + 1
                    } else {
                        if (argument.equals("--max-program-bytes") || argument.equals("--max-instructions") || argument.equals("--max-stack-values") || argument.equals("--max-call-depth") || argument.equals("--max-heap-bytes") || argument.equals("--max-open-files")) {
                            if (index + 1 >= process.argc()) {
                                usageError()
                                return(2)
                            }
                            int64 maximum = VM.Limits.MAX_PROGRAM_BYTES
                            bool allowZero = false
                            if (argument.equals("--max-program-bytes")) { maximum = VM.Limits.MAX_PROGRAM_BYTES }
                            if (argument.equals("--max-instructions")) { maximum = VM.Limits.MAX_INSTRUCTIONS }
                            if (argument.equals("--max-stack-values")) { maximum = VM.Limits.MAX_STACK_VALUES }
                            if (argument.equals("--max-call-depth")) { maximum = VM.Limits.MAX_CALL_DEPTH }
                            if (argument.equals("--max-heap-bytes")) {
                                maximum = VM.Limits.MAX_HEAP_BYTES
                                allowZero = true
                            }
                            if (argument.equals("--max-open-files")) {
                                maximum = VM.Capabilities.MAX_OPEN_FILES
                                allowZero = true
                            }
                            int64 value = parseLimit(process.arg(index + 1), maximum, allowZero)
                            if (value < 0) {
                                usageError()
                                return(2)
                            }
                            if (argument.equals("--max-program-bytes")) { programBytes = value }
                            if (argument.equals("--max-instructions")) { instructions = value }
                            if (argument.equals("--max-stack-values")) { stackValues = value }
                            if (argument.equals("--max-call-depth")) { callDepth = value }
                            if (argument.equals("--max-heap-bytes")) { heapBytes = value }
                            if (argument.equals("--max-open-files")) { maxOpenFiles = value }
                            index = index + 2
                        } else {
                            if (!input.equals("")) {
                                usageError()
                                return(2)
                            }
                            input = argument
                            index = index + 1
                        }
                    }
                }
            }
        }
        if (input.equals("")) {
            usageError()
            return(2)
        }
        VM.Limits limits = VM.Limits(programBytes, instructions, stackValues, callDepth, heapBytes)
        VM.Capabilities capabilities = VM.Capabilities(stdinEnabled, stdoutEnabled,
            filesEnabled, maxOpenFiles)
        if (!limits.valid() || !capabilities.valid()) {
            usageError()
            return(2)
        }

        IO.Result loaded = IO.Files().readLimited(input, limits.programBytes())
        if (!loaded.ok()) {
            String category = "load"
            if (loaded.category() == IO.Result.LIMIT_EXCEEDED) { category = "resource limit" }
            Sys.StandardIO().writeErrorLine(format("{}: {}: {}", input, category, loaded.error()))
            return(1)
        }
        VM.ExecutionResult result = VM.VirtualMachine().run(loaded.bytes(), limits, capabilities)
        if (result.ok()) {
            String summary = format("result: {}", result.guestResult())
            Sys.StandardIO io = Sys.StandardIO()
            int64 written = -1
            String error = ""
            try {
                written = io.writeLine(summary)
                error = Sys.System().lastError()
                if (error.equals("") && written == summary.length + 1) {
                    io.flush()
                    error = Sys.System().lastError()
                }
            } except(Exception) as caught {
                error = caught.message
            }
            if (!error.equals("") || written != summary.length + 1) {
                if (error.equals("")) { error = "incomplete stdout write" }
                Sys.StandardIO().writeErrorLine(format("stdout: I/O error: {}", error))
                return(1)
            }
            return(0)
        }

        String category = "runtime trap"
        if (result.category() == VM.ExecutionResult.LOAD_ERROR) { category = "load" }
        if (result.category() == VM.ExecutionResult.VALIDATION_ERROR) { category = "validation" }
        if (result.category() == VM.ExecutionResult.UNSUPPORTED_SERVICE) { category = "unsupported service" }
        if (result.category() == VM.ExecutionResult.RESOURCE_LIMIT) { category = "resource limit" }
        if (result.category() == VM.ExecutionResult.IO_ERROR) { category = "I/O error" }
        if (result.category() == VM.ExecutionResult.CONFIGURATION_ERROR) { category = "configuration error" }
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
        return(1)
    }
}

start { Sys.Process().exit(RunnerCLI().run()) }
