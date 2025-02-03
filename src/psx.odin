package main

PSXState :: struct
{
    ram: [2048 * 1024]u8,
    ex1: [512 * 1024]u8,
    scrathpad: [1024]u8,
    bios: [512 * 1024]u8,
    sio: [0x10]u8,
    memoryControl1: [0x40]u8,
    memoryControl2: [0x10]u8,

    memoryCache: u32,
}

bus_load_bios :: proc(ps: ^PSXState, addr: u32) -> u32
{
    biosPtr: = &ps.bios[addr & 0x1F_FFFF];
    return (cast(^u32)biosPtr)^;
}

bus_load_ram :: proc(ps: ^PSXState, addr: u32) -> u32
{
    ramPtr: = &ps.ram[addr & 0x1F_FFFF];
    return (cast(^u32)ramPtr)^;
}