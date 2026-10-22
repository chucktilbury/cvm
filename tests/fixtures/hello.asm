.version 1.0
.entry main
.array greeting: u8[13] = "Hello, CVM!\n"

.func main() -> i32
    array greeting
    const.i32 0
    const.i32 12
    sys stdout_write
    pop
    const.i32 20
    const.i32 22
    add.i32
    ret.i32
.end
