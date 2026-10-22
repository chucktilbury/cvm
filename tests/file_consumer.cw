import system as Sys
import cvmfile as IO
import cvm as CVM

start {
    IO.Files files = IO.Files()
    String path = Sys.Process().arg(1)
    buffer all = buffer[]
    int index = 0
    while (index < 256) {
        all.append(index)
        index = index + 1
    }
    IO.Result saved = files.write(path, all)
    if (!saved.ok()) {
        Sys.StandardIO().writeErrorLine(saved.error())
        Sys.Process().exit(1)
    }
    IO.Result loaded = files.read(path)
    if (!loaded.ok() || loaded.bytes().length != 256) { Sys.Process().exit(2) }
    index = 0
    while (index < 256) {
        if (int(loaded.bytes()[index]) != index) { Sys.Process().exit(3) }
        index = index + 1
    }
    if (files.read(format("{}/missing", path)).ok()) { Sys.Process().exit(4) }
    if (files.write(format("{}/missing", path), all).ok()) { Sys.Process().exit(5) }
    if (Sys.Process().argc() > 2 && Sys.Process().arg(2).equals("--io")) {
        int before = Sys.FileSystem().listDir("/proc/self/fd").length
        int repeat = 0
        while (repeat < 32) {
            if (files.read("/proc/self/mem").ok()) { Sys.Process().exit(8) }
            if (files.write("/dev/full", all).ok()) { Sys.Process().exit(9) }
            repeat = repeat + 1
        }
        if (Sys.FileSystem().listDir("/proc/self/fd").length != before) { Sys.Process().exit(10) }
        buffer large = buffer[]
        index = 0
        while (index < 131329) {
            large.append(index % 256)
            index = index + 1
        }
        if (!files.write(path, large).ok()) { Sys.Process().exit(11) }
        IO.Result copied = files.read(path)
        if (!copied.ok() || copied.bytes().length != large.length) { Sys.Process().exit(12) }
        index = 0
        while (index < large.length) {
            if (copied.bytes()[index] != large[index]) { Sys.Process().exit(13) }
            index = index + 1
        }
        if (files.write("/dev/full", large).ok()) { Sys.Process().exit(14) }
        if (files.write(path, null).ok()) { Sys.Process().exit(15) }
        if (!files.write(path, buffer[]).ok()) { Sys.Process().exit(16) }
        IO.Result empty = files.read(path)
        if (!empty.ok() || empty.bytes().length != 0) { Sys.Process().exit(17) }
        Sys.Process().exit(0)
    }
    if (Sys.Process().argc() > 2) {
        IO.Result binary = files.read(Sys.Process().arg(2))
        if (!binary.ok()) {
            Sys.StandardIO().writeErrorLine(binary.error())
            Sys.Process().exit(6)
        }
        CVM.ValidationResult valid = CVM.ContainerValidator().validate(binary.bytes())
        if (!valid.valid()) {
            Sys.StandardIO().writeErrorLine(valid.message())
            Sys.Process().exit(7)
        }
    }
}
