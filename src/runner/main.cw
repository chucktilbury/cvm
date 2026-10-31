import cvmfile as IO
import cvmrun as VM
import system as Sys
import cli as Cli

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

    Cli.Option numberOption(String longName, String name, String description) {
        Cli.Option option = Cli.Option()
        option.longName = longName
        option.name = name
        option.description = description
        option.valueType = Cli.ValueType().STRING
        return(option)
    }

    Cli.CommandLine parser() {
        Cli.CommandLine commandLine = Cli.CommandLine("cvm-run", "run a CVM container", "1.0.0")
        Cli.Option help = Cli.Option()
        help.longName = "help"
        help.name = "help"
        help.action = Cli.Action().HELP
        commandLine.addOption(help)
        commandLine.addOption(numberOption("max-program-bytes", "max-program-bytes", "program byte limit"))
        commandLine.addOption(numberOption("max-instructions", "max-instructions", "instruction limit"))
        commandLine.addOption(numberOption("max-stack-values", "max-stack-values", "stack value limit"))
        commandLine.addOption(numberOption("max-call-depth", "max-call-depth", "call depth limit"))
        commandLine.addOption(numberOption("max-heap-bytes", "max-heap-bytes", "heap byte limit"))
        commandLine.addOption(numberOption("max-open-files", "max-open-files", "open file limit"))
        Cli.Option noStdin = Cli.Option()
        noStdin.longName = "no-stdin"
        noStdin.name = "no-stdin"
        noStdin.description = "disable guest stdin"
        commandLine.addOption(noStdin)
        Cli.Option noStdout = Cli.Option()
        noStdout.longName = "no-stdout"
        noStdout.name = "no-stdout"
        noStdout.description = "disable guest stdout"
        commandLine.addOption(noStdout)
        Cli.Option noFiles = Cli.Option()
        noFiles.longName = "no-files"
        noFiles.name = "no-files"
        noFiles.description = "disable guest filesystem"
        commandLine.addOption(noFiles)
        Cli.Positional input = Cli.Positional()
        input.name = "input"
        input.description = "CVM container"
        input.required = true
        commandLine.addPositional(input)
        return(commandLine)
    }

    int64 applyLimit(Cli.CommandLine commandLine, String name, int64 maximum, bool allowZero, int64 current) {
        if (commandLine.wasProvided(name) == false) {
            return(current)
        }
        int64 value = parseLimit(commandLine.value(name), maximum, allowZero)
        if (value < 0) {
            return(-1)
        }
        return(value)
    }

    int64 run() {
        Cli.CommandLine commandLine = parser()
        try {
            commandLine.parseArgv()
        } except() {
            usageError()
            return(2)
        }
        if (commandLine.currentAction() == Cli.Action().HELP) {
            Sys.StandardIO().writeLine(usage())
            return(0)
        }
        if (commandLine.allPositionalValues().length != 1) {
            usageError()
            return(2)
        }

        VM.Limits defaults = VM.Limits()
        int64 programBytes = applyLimit(commandLine, "max-program-bytes",
            VM.Limits.MAX_PROGRAM_BYTES, false, defaults.programBytes())
        int64 instructions = applyLimit(commandLine, "max-instructions",
            VM.Limits.MAX_INSTRUCTIONS, false, defaults.instructions())
        int64 stackValues = applyLimit(commandLine, "max-stack-values",
            VM.Limits.MAX_STACK_VALUES, false, defaults.stackValues())
        int64 callDepth = applyLimit(commandLine, "max-call-depth",
            VM.Limits.MAX_CALL_DEPTH, false, defaults.callDepth())
        int64 heapBytes = applyLimit(commandLine, "max-heap-bytes",
            VM.Limits.MAX_HEAP_BYTES, true, defaults.heapBytes())
        VM.Capabilities defaultCapabilities = VM.Capabilities()
        int64 maxOpenFiles = applyLimit(commandLine, "max-open-files",
            VM.Capabilities.MAX_OPEN_FILES, true, defaultCapabilities.maxOpenFiles())
        if (programBytes < 0 or instructions < 0 or stackValues < 0 or callDepth < 0 or heapBytes < 0 or maxOpenFiles < 0) {
            usageError()
            return(2)
        }
        bool stdinEnabled = defaultCapabilities.stdinEnabled()
        bool stdoutEnabled = defaultCapabilities.stdoutEnabled()
        bool filesEnabled = defaultCapabilities.filesEnabled()
        if (commandLine.switchValue("no-stdin")) { stdinEnabled = false }
        if (commandLine.switchValue("no-stdout")) { stdoutEnabled = false }
        if (commandLine.switchValue("no-files")) { filesEnabled = false }
        String input = commandLine.allPositionalValues()[0] as String

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
