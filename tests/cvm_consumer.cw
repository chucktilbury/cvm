import cvm as CVM
import system as Sys

start {
    CVM.InstructionBuilder instructions = CVM.InstructionBuilder()
    instructions.emit(CVM.Opcode.CONST_I32, 42)
    instructions.emitNoOperand(CVM.Opcode.RET_I32)
    CVM.ContainerBuilder builder = CVM.ContainerBuilder()
    builder.addFunction("main", instructions.bytes(), buffer[], 0, 0, 1, 1)
    CVM.BuildResult encoded = builder.encode()
    if (!encoded.ok()) { Sys.StandardIO().writeError(encoded.message()) }
    if (!encoded.ok()) { Sys.Process().exit(1) }

    CVM.ContainerValidator validator = CVM.ContainerValidator()
    CVM.ValidationResult valid = validator.validate(encoded.bytes())
    if (!valid.valid()) { Sys.StandardIO().writeError(format("{}:{} {}", valid.section(), valid.offset(), valid.message())) }
    if (!valid.valid()) { Sys.Process().exit(2) }
    CVM.ContainerDecodeResult decoded = CVM.ContainerDecoder().decode(encoded.bytes())
    if (!decoded.valid() || decoded.entryFunction() != 0 || decoded.directoryCount() != 7 || decoded.countForSection(CVM.Format.FUNCS) != 1) { Sys.Process().exit(16) }
    buffer decodedCode = decoded.sectionBytes(CVM.Format.CODE)
    if (decodedCode.length != 6 || int64(decodedCode[0]) != CVM.Opcode.CONST_I32 || int64(decodedCode[5]) != CVM.Opcode.RET_I32) { Sys.Process().exit(17) }

    CVM.ByteWriter boundaryWriter = CVM.ByteWriter()
    boundaryWriter.writeU8(0)
    boundaryWriter.writeU8(255)
    boundaryWriter.writeU16(65535)
    boundaryWriter.writeU32(4294967295u)
    boundaryWriter.writeI32(-2147483648)
    boundaryWriter.writeI32(2147483647)
    CVM.ByteReader boundaryReader = CVM.ByteReader(boundaryWriter.bytes())
    if (boundaryReader.readU8() != 0 || boundaryReader.readU8() != 255 || boundaryReader.readU16() != 65535) { Sys.Process().exit(9) }
    if (boundaryReader.readU32() != 4294967295 || boundaryReader.readI32() != -2147483648 || boundaryReader.readI32() != 2147483647) { Sys.Process().exit(10) }
    CVM.ByteReader shortReader = CVM.ByteReader(buffer[])
    if (shortReader.readU8() != 0 || shortReader.errorCode() != CVM.ByteReader.TRUNCATED || shortReader.errorOffset() != 0) { Sys.Process().exit(22) }
    CVM.ByteWriter invalidWriter = CVM.ByteWriter()
    if (invalidWriter.writeU8(256) || invalidWriter.errorCode() != CVM.ByteWriter.RANGE_ERROR) { Sys.Process().exit(11) }
    CVM.InstructionBuilder invalidInstruction = CVM.InstructionBuilder()
    if (invalidInstruction.emit(CVM.Opcode.CONST_I32, 2147483648) || invalidInstruction.errorCode() != CVM.InstructionBuilder.INVALID_VALUE) { Sys.Process().exit(23) }
    CVM.InstructionBuilder missingOperand = CVM.InstructionBuilder()
    if (missingOperand.emitNoOperand(CVM.Opcode.CONST_I32) || missingOperand.errorCode() != CVM.InstructionBuilder.INVALID_INSTRUCTION) { Sys.Process().exit(24) }
    CVM.ContainerBuilder invalidGlobalBuilder = CVM.ContainerBuilder()
    if (invalidGlobalBuilder.addGlobal("bad", 2, -1) || invalidGlobalBuilder.errorCode() == 0) { Sys.Process().exit(18) }
    CVM.Opcode opcodeSchema = CVM.Opcode()
    int64 opcodeNumber = 0
    while (opcodeNumber <= CVM.Opcode.RET_FILE) {
        if (!opcodeSchema.isValid(opcodeNumber) || opcodeSchema.mnemonic(opcodeNumber).length == 0 || opcodeSchema.operandSchema(opcodeNumber).length == 0 || opcodeSchema.stackEffect(opcodeNumber).length == 0 || opcodeSchema.operation(opcodeNumber).length == 0) { Sys.Process().exit(21) }
        opcodeNumber = opcodeNumber + 1
    }
    CVM.Service services = CVM.Service()
    list arities = [int64(1), int64(1), int64(3), int64(0), int64(1), int64(1), int64(4), int64(4), int64(1), int64(2), int64(3), int64(3), int64(1)]
    list results = [int64(0), int64(0), int64(1), int64(1), int64(1), int64(1), int64(1), int64(1), int64(0), int64(1), int64(1), int64(1), int64(0)]
    int64 service = 0
    while (service <= CVM.Service.FILE_CLOSE_HANDLE) {
        if (services.name(service).length == 0 || services.parameterCount(service) != (arities[service] as int64) || services.resultCount(service) != (results[service] as int64)) { Sys.Process().exit(25) }
        CVM.InstructionBuilder serviceInstruction = CVM.InstructionBuilder()
        if (!serviceInstruction.emit(CVM.Opcode.SYS, service)) { Sys.Process().exit(27) }
        service = service + 1
    }
    if (!services.name(-1).equals("") || !services.name(13).equals("") || services.parameterCount(13) != -1 || services.resultCount(-1) != -1) { Sys.Process().exit(26) }
    CVM.InstructionBuilder invalidService = CVM.InstructionBuilder()
    if (invalidService.emit(CVM.Opcode.SYS, 13)) { Sys.Process().exit(28) }

    buffer allBytes = buffer[]
    int64 byteValue = 0
    while (byteValue < 256) {
        allBytes.append(byteValue)
        byteValue = byteValue + 1
    }
    byteValue = 0
    while (byteValue < 256) {
        if (int64(allBytes[byteValue]) != byteValue) { Sys.Process().exit(3) }
        byteValue = byteValue + 1
    }

    buffer truncatedHeader = encoded.bytes()[0:31]
    if (validator.validate(truncatedHeader).code() != CVM.ValidationResult.TRUNCATED) { Sys.Process().exit(4) }

    buffer badVersion = buffer(encoded.bytes().length)
    byteValue = 0
    while (byteValue < encoded.bytes().length) {
        badVersion[byteValue] = encoded.bytes()[byteValue]
        byteValue = byteValue + 1
    }
    badVersion[4] = 2
    if (validator.validate(badVersion).code() != CVM.ValidationResult.UNSUPPORTED_VERSION) { Sys.Process().exit(5) }

    buffer malformed = buffer(encoded.bytes().length)
    byteValue = 0
    while (byteValue < malformed.length) {
        malformed[byteValue] = encoded.bytes()[byteValue]
        byteValue = byteValue + 1
    }
    malformed[14] = 1
    if (validator.validate(malformed).code() != CVM.ValidationResult.INVALID_HEADER) { Sys.Process().exit(13) }

    byteValue = 0
    while (byteValue < malformed.length) {
        malformed[byteValue] = encoded.bytes()[byteValue]
        byteValue = byteValue + 1
    }
    malformed[34] = 1
    if (validator.validate(malformed).code() != CVM.ValidationResult.INVALID_SECTION) { Sys.Process().exit(14) }

    byteValue = 0
    while (byteValue < malformed.length) {
        malformed[byteValue] = encoded.bytes()[byteValue]
        byteValue = byteValue + 1
    }
    malformed[44] = 5
    if (validator.validate(malformed).code() != CVM.ValidationResult.INVALID_SECTION) { Sys.Process().exit(15) }

    byteValue = 0
    while (byteValue < malformed.length) {
        malformed[byteValue] = encoded.bytes()[byteValue]
        byteValue = byteValue + 1
    }
    malformed[144] = 0x23
    if (validator.validate(malformed).code() != CVM.ValidationResult.INVALID_INSTRUCTION) { Sys.Process().exit(6) }

    byteValue = 0
    while (byteValue < malformed.length) {
        malformed[byteValue] = encoded.bytes()[byteValue]
        byteValue = byteValue + 1
    }
    malformed[144] = CVM.Opcode.LDLOC
    malformed[145] = 0
    malformed[146] = 0
    if (validator.validate(malformed).code() != CVM.ValidationResult.INVALID_INDEX) { Sys.Process().exit(7) }

    byteValue = 0
    while (byteValue < malformed.length) {
        malformed[byteValue] = encoded.bytes()[byteValue]
        byteValue = byteValue + 1
    }
    malformed[158] = 1
    malformed[159] = 0
    malformed[160] = 0
    malformed[161] = 0
    if (validator.validate(malformed).code() != CVM.ValidationResult.TRUNCATED) { Sys.Process().exit(8) }

    byteValue = 0
    while (byteValue < malformed.length) {
        malformed[byteValue] = encoded.bytes()[byteValue]
        byteValue = byteValue + 1
    }
    malformed[144] = CVM.Opcode.JMP
    malformed[145] = 1
    malformed[146] = 0
    malformed[147] = 0
    malformed[148] = 0
    if (validator.validate(malformed).code() != CVM.ValidationResult.INVALID_INDEX) { Sys.Process().exit(12) }

    CVM.ContainerBuilder optionalBuilder = CVM.ContainerBuilder()
    optionalBuilder.addFunction("main", instructions.bytes(), buffer[], 0, 0, 1, 1)
    optionalBuilder.addGlobal("counter", 1, -2147483648)
    optionalBuilder.addArray("bytes", 65535, 2, 2, buffer[0, 255])
    optionalBuilder.setDebug(buffer(20), 1)
    optionalBuilder.addOptionalSection(0, buffer[42], 700)
    optionalBuilder.addOptionalSection(9, buffer[0, 255], 99)
    CVM.BuildResult optionalEncoded = optionalBuilder.encode()
    if (!optionalEncoded.ok()) { Sys.Process().exit(19) }
    CVM.ContainerDecodeResult optionalDecoded = CVM.ContainerDecoder().decode(optionalEncoded.bytes())
    buffer optionalPayload = optionalDecoded.sectionBytes(9)
    buffer zeroKindPayload = optionalDecoded.sectionBytes(0)
    if (!optionalDecoded.valid() || optionalDecoded.directoryCount() != 10 || optionalDecoded.countForSection(CVM.Format.GLOBALS) != 1 || optionalDecoded.countForSection(CVM.Format.ARRAYS) != 1 || optionalDecoded.countForSection(CVM.Format.DATA) != 2 || optionalDecoded.countForSection(CVM.Format.DEBUG) != 1 || optionalDecoded.countForSection(0) != 700 || zeroKindPayload.length != 1 || int64(zeroKindPayload[0]) != 42 || optionalDecoded.countForSection(9) != 99 || optionalPayload.length != 2 || int64(optionalPayload[0]) != 0 || int64(optionalPayload[1]) != 255) { Sys.Process().exit(20) }

    Sys.StandardIO().writeErrorBytes(allBytes)
    Sys.StandardIO().writeBytes(encoded.bytes())
}
