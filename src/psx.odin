package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"

PSX_MHZ :: 33868800;
SYNC_CYCLES :: 100;
MIPS_UNDERCLOCK :: 3;
CYCLES_PER_FRAME :: PSX_MHZ / 60;
SYNC_LOOPS :: (CYCLES_PER_FRAME / (SYNC_CYCLES * MIPS_UNDERCLOCK)) + 1;

BIOS_FILE :: "Bios/scph1001.bin";

REGION_MASK :: []u32{
    0xFFFF_FFFF, 0xFFFF_FFFF, 0xFFFF_FFFF, 0xFFFF_FFFF, // KUSEG: 2048MB
    0x7FFF_FFFF,                                        // KSEG0:  512MB
    0x1FFF_FFFF,                                        // KSEG1:  512MB
    0xFFFF_FFFF, 0xFFFF_FFFF,                           // KSEG2: 1024MB
};

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

    cpu: CPUState,
    gpu: GPUState,
}

psx_init :: proc() -> (ps: ^PSXState, success: bool)
{
    // Create state
    state := new(PSXState);

    // Init cpu
    cpu_init(&state.cpu);

    // Get bios file
    defaultBiosFile := BIOS_FILE;

    // Load the bios
    successful := psx_load_bios(state, defaultBiosFile);

    // Get return value
    return state, successful;
}

psx_execute_cycle :: proc(ps: ^PSXState)
{
    // Get the cpu
    cpu := &ps.cpu;

    sync := 0;
    syncLoops := SYNC_LOOPS;
    syncCycles := SYNC_CYCLES;

    // Run frame
    for i := 0; i < syncLoops; i += 1
    {
        for sync < syncCycles
        {
            // Run the CPU
            sync += int(cpu_execute(ps, cpu));
        }

        // Decrease sync
        sync -= syncCycles;
    }
}

psx_cleanup :: proc(ps: ^PSXState)
{
    free(ps);
}

psx_load_bios :: proc(ps: ^PSXState, biosPath: string) -> bool
{
    // Get current dir
    currentDir := os.get_current_directory();

    // Get the full path
    biosFullPath := filepath.join([]string{currentDir, biosPath});

    // Read bytes
    data, success := os.read_entire_file_from_filename(biosFullPath);

    // Check for error
    if success == false
    {
        fmt.printfln("Error reading bios image: ", biosFullPath);
        return false;
    }

    // Get memory pointers
    biosMemPtr := &ps.bios[0];
    biosImagePtr := &data[0];

    // Copy into memory
    mem.copy(biosMemPtr, biosImagePtr, len(data));
    return true;
}

bus_loadmem_bios :: proc(ps: ^PSXState, addr: u32) -> u32
{
    biosPtr: = &ps.bios[addr & 0x1F_FFFF];
    return (cast(^u32)biosPtr)^;
}

bus_loadmem_ram :: proc(ps: ^PSXState, addr: u32) -> u32
{
    ramPtr: = &ps.ram[addr & 0x1F_FFFF];
    return (cast(^u32)ramPtr)^;
}