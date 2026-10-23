.version 1.0
.entry main
.array path: u8[18] = "integer-files.bin"
.array mode: u8[2] = "w"
.array payload: u8[3] = {0, 128, 255}
.func main() -> i32
    .local handle: i32
    .local count: i32
    array path
    array mode
    sys file_open
    stloc handle
    pop
    ldloc handle
    array payload
    const.i32 3
    sys file_write_handle
    stloc count
    pop
    ldloc handle
    sys file_close_handle
    ldloc count
    ret.i32
.end
