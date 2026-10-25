class StackDepth {
    void fail(String message, Instruction instruction) {
        raise(AssemblyError(message, instruction.line, instruction.column))
    }

    int64 target(Function function, int64 offset) {
        int64 index = 0
        while (index < function.instructions.length) {
            if ((function.instructions[index] as Instruction).offset == offset) { return(index) }
            index = index + 1
        }
        return(-1)
    }

    void enqueue(Function function, list depths, list pending, int64 index, int64 depth, Instruction origin) {
        if (index < 0 || index >= function.instructions.length) { fail("reachable fallthrough or invalid branch", origin) }
        int64 previous = depths[index] as int64
        if (previous >= 0 && previous != depth) { fail("inconsistent stack depth at control-flow join", origin) }
        if (previous < 0) {
            depths[index] = depth
            pending.append(index)
        }
    }

    int64 maximum(Function function, list functions) {
        list depths = []
        list pending = []
        int64 index = 0
        while (index < function.instructions.length) {
            Instruction instruction = function.instructions[index] as Instruction
            int64 op = instruction.opcode
            int64 returnType = -1
            if (op == CVM.Opcode.RET) { returnType = 0 }
            if (op == CVM.Opcode.RET_I32) { returnType = 1 }
            if (op == CVM.Opcode.RET_U8) { returnType = 2 }
            if (op == CVM.Opcode.RET_FILE) { returnType = 3 }
            if (returnType >= 0 && returnType != function.result) { fail("return opcode does not match declared return type", instruction) }
            depths.append(int64(-1))
            index = index + 1
        }
        depths[0] = int64(0)
        pending.append(int64(0))
        int64 cursor = 0
        int64 maximumDepth = 0
        while (cursor < pending.length) {
            int64 at = pending[cursor] as int64
            cursor = cursor + 1
            Instruction instruction = function.instructions[at] as Instruction
            int64 op = instruction.opcode
            int64 required = 0
            int64 produced = 0
            bool returns = false
            if (op == CVM.Opcode.CONST_I32 || op == CVM.Opcode.CONST_U8 || op == CVM.Opcode.LDLOC || op == CVM.Opcode.LDGLOBAL || op == CVM.Opcode.ARRAY) { produced = 1 }
            if (op == CVM.Opcode.STLOC || op == CVM.Opcode.STGLOBAL || op == CVM.Opcode.ALEN || op == CVM.Opcode.NEG_I32 || op == CVM.Opcode.TO_U8 || op == CVM.Opcode.TO_I32) { required = 1
                produced = 1 }
            if (op == CVM.Opcode.AGET || (op >= CVM.Opcode.ADD_I32 && op <= CVM.Opcode.REM_I32) || (op >= CVM.Opcode.EQ_I32 && op <= CVM.Opcode.GE_I32)) { required = 2
                produced = 1 }
            if (op == CVM.Opcode.ASET) { required = 3
                produced = 1 }
            if (op == CVM.Opcode.DUP) { required = 1
                produced = 2 }
            if (op == CVM.Opcode.POP || op == CVM.Opcode.JZ) { required = 1 }
            if (op == CVM.Opcode.CALL) {
                Function callee = functions[instruction.value] as Function
                required = callee.parameters
                if (callee.result != 0) { produced = 1 }
            }
            if (op == CVM.Opcode.SYS) {
                CVM.Service service = CVM.Service()
                required = service.parameterCount(instruction.value)
                produced = service.resultCount(instruction.value)
            }
            if (op == CVM.Opcode.RET || op == CVM.Opcode.RET_I32 || op == CVM.Opcode.RET_U8 || op == CVM.Opcode.RET_FILE) {
                returns = true
                if (function.result != 0) { required = 1 }
            }
            int64 depth = depths[at] as int64
            if (depth < required) { fail("evaluation stack underflow", instruction) }
            if (returns && depth != required) { fail("extra evaluation stack values at return", instruction) }
            depth = depth - required + produced
            if (depth > 65535) { fail("maximum stack exceeds v1 range", instruction) }
            if (depth > maximumDepth) { maximumDepth = depth }
            if (!returns) {
                if (op == CVM.Opcode.JMP || op == CVM.Opcode.JZ) { enqueue(function, depths, pending, target(function, instruction.value), depth, instruction) }
                if (op != CVM.Opcode.JMP) { enqueue(function, depths, pending, at + 1, depth, instruction) }
            }
        }
        return(maximumDepth)
    }
}
