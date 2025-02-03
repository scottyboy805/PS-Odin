package main

SR :: 12;
CAUSE :: 13;
EPC :: 14;
BADA :: 8;
JUMPDEST :: 6;

CPUState :: struct
{
    instr: u32,
    pcNow: u32,
    pcPredictor: u32,
    pc: u32,
    gpr: [32]u32,
    hi: u32,
    lo: u32,

    cop0Grp: [16]u32,
    writeBack: Mem,
    memoryLoad: Mem,
    delayedMemoryLoad: Mem,

    opcodeIsBranch: bool,
    opcodeIsDelaySlot: bool,
    opcodeTookBranch: bool,
    opcodeInDelaySlotTookBranch: bool,
    dontIsolateCache: bool,

    debug: bool,
}

Mem :: struct
{
    register: u32,
    value: u32,
}

cpu_execute :: proc(ps: ^PSXState, cpu: ^CPUState) -> i32
{
    // Fetch the instruction
    ticks := cpu_fetch_decode(ps, cpu);

    // Execute except for NOP
    if(cpu.instr != 0)
    {
        // Get the opcode
        opcode := instruction_get_opcode(cpu.instr);

        // Execute the op code
        cpu_execute_primary_opcode(ps, cpu, opcode);
    }

    // Mem access
    if(cpu.delayedMemoryLoad.register != cpu.memoryLoad.register)
    {

    }
    cpu.memoryLoad = cpu.delayedMemoryLoad;
    cpu.delayedMemoryLoad.register = 0;

    // Write back
    cpu.writeBack.register = 0;

    return ticks;
}

cpu_execute_primary_opcode :: proc(ps: ^PSXState, cpu: ^CPUState, opcode: u32)
{
    switch opcode
    {
        // Special
        case 0x00:
            {
                // Get the function
                func := instruction_get_function(cpu.instr);

                // Execute special
                cpu_execute_secondary_opcode(ps, cpu, func);
            }
        // BCONDZ
        case 0x01:
            {
                cpu.opcodeIsBranch = true;
                op := instruction_get_rt(cpu.instr);
                rs := instruction_get_rs(cpu.instr);

                shouldLink := (op & 0x1E) == 0x10;
                shouldBranch := i32(cpu.gpr[rs] ~ (op << 31)) < 0;

                // Check for link
                if shouldLink
                {
                    cpu.gpr[31] = cpu.pcPredictor;
                }

                // Check for branch
                if shouldBranch
                {
                    cpu.opcodeTookBranch = true;
                    cpu.pcPredictor = cpu.pc + (instruction_get_imm_s(cpu.instr) << 2);
                }
            }
        // J
        case 0x02:
            {
                // Branch
                cpu.opcodeIsBranch = true;
                cpu_execute_take_branch(cpu);
            }
        // JAL
        case 0x03:
            {
                cpu.writeBack.register = 31;
                cpu.writeBack.value = cpu.pcPredictor;

                // Branch
                cpu.opcodeIsBranch = true;
                cpu_execute_take_branch(cpu);
            }
        // BEQ
        case 0x04:
            {
                cpu.opcodeIsBranch = true;
                rs := instruction_get_rs(cpu.instr);
                rt := instruction_get_rt(cpu.instr);

                // Condition
                if cpu.gpr[rs] == cpu.gpr[rt]
                {
                    // Branch
                    cpu_execute_take_branch(cpu);
                }
            }
        // BNE
        case 0x05:
            {
                cpu.opcodeIsBranch = true;
                rs := instruction_get_rs(cpu.instr);
                rt := instruction_get_rt(cpu.instr);

                // Condition
                if cpu.gpr[rs] != cpu.gpr[rt]
                {
                    // Branch
                    cpu_execute_take_branch(cpu);
                }
            }
        // BLEZ
        case 0x06:
            {
                cpu.opcodeIsBranch = true;
                rs := instruction_get_rs(cpu.instr);

                // Condition
                if i32(cpu.gpr[rs]) <= 0
                {
                    // Branch
                    cpu_execute_take_branch(cpu);
                }
            }
        // BGTZ
        case 0x07:
            {
                cpu.opcodeIsBranch = true;
                rs := instruction_get_rs(cpu.instr);

                // Condition
                if i32(cpu.gpr[rs]) >= 0
                {
                    // Branch
                    cpu_execute_take_branch(cpu);
                }
            }
        // ADDI
        case 0x08:
            {
                rs := instruction_get_rs(cpu.instr);
                imm_s := instruction_get_imm_s(cpu.instr);
                result := cpu.gpr[rs] + imm_s;

                cpu.writeBack.register = instruction_get_rt(cpu.instr);
                cpu.writeBack.value = result;
            }
    }
}

cpu_execute_secondary_opcode :: proc(ps: ^PSXState, cpu: ^CPUState, func: u32)
{

}

cpu_execute_take_branch :: proc(cpu: ^CPUState)
{
    // Jump
    cpu.opcodeTookBranch = true;
    cpu.pcPredictor = cpu.pc + (instruction_get_imm_s(cpu.instr) << 2);
}

cpu_fetch_decode :: proc(ps: ^PSXState, cpu: ^CPUState) -> i32
{
    // Exe addr space is clamped to ram and bios
    maskedPc := cpu.pc & 0x1FFF_FFFF;

    // Update pc
    cpu.pcNow = cpu.pc;
    cpu.pc = cpu.pcPredictor;
    cpu.pcPredictor += 4;

    cpu.opcodeIsDelaySlot = cpu.opcodeIsBranch;
    cpu.opcodeInDelaySlotTookBranch = cpu.opcodeTookBranch;
    cpu.opcodeIsBranch = false;
    cpu.opcodeTookBranch = false;

    if maskedPc < 0x1F00_0000
    {
        // Read instruction
        cpu.instr = bus_load_ram(ps, maskedPc)
        return 1;
    }
    else
    {
        // Read bios
        cpu.instr = bus_load_bios(ps, maskedPc);
        return 20;
    }
}

// Get opcode from instruction
instruction_get_opcode :: proc(data: u32) -> u32
{
    return data >> 26;
}

// Get register source from instruction
instruction_get_rs :: proc(data: u32) -> u32
{
    return (data >> 21) & 0x1F;
}

// Get register target
instruction_get_rt :: proc(data: u32) -> u32
{
    return (data >> 16) & 0x1F;
}

// Get immediate value
instruction_get_imm :: proc(data: u32) -> u32
{
    return u32(u16(data));
}

// Get immediate value sign extended
instruction_get_imm_s :: proc(data: u32) -> u32
{
    return u32(i16(data));
}

instruction_get_rd :: proc(data: u32) -> u32
{
    return (data >> 11) & 0x1F;
}

instruction_get_sa :: proc(data: u32) -> u32
{
    return (data >> 6) & 0xF1;
}

instruction_get_function :: proc(data: u32) -> u32
{
    return data & 0x3F;
}

instruction_get_addr :: proc(data: u32) -> u32
{
    return data & 0x3FFFFFF;
}

instruction_get_id :: proc(data: u32) -> u32
{
    return instruction_get_opcode(data) & 0x3;
}