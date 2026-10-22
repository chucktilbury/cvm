.version 1.0
.entry main

.func sum_to(n:i32) -> i32
    .local i: i32
    .local sum: i32
    const.i32 0
    stloc i
    pop
    const.i32 0
    stloc sum
    pop
loop:
    ldloc i
    ldloc n
    le.i32
    jz done
    ldloc sum
    ldloc i
    add.i32
    stloc sum
    pop
    ldloc i
    const.i32 1
    add.i32
    stloc i
    pop
    jmp loop
done:
    ldloc sum
    ret.i32
.end

.func main() -> i32
    const.i32 10
    call sum_to
    sys stdout_i32
    const.i32 0
    ret.i32
.end
