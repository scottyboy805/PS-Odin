package main

import "core:mem"
import "core:math"

RenderCallback :: proc(vramBits: []i32);

RESOLUTIONS :: []i32{ 256, 320, 512, 640, 368 };
DOT_CLOCK_DIV :: []i32{ 10, 8, 5, 4, 7 };

Color :: distinct [4]f32;


GPUState :: struct
{
    gpuRead: u32,
    command: u32,
    commandSize: i32,
    commandBuffer: [16]u32,
    pointer: i32,

    scanLine: i32,
    isTextureDisabledAllowed: bool,

    color1555to8888LUT: []i32,
    color0: Color,
    color1: Color,
    color2: Color,

    // GP0
    textureXBase: u8,
    textureyBase: u8,
    transparencyMode: u8,
    textureDepth: u8,
    isDithered: bool,
    isDrawingToDisplayAllowed: bool,
    maskWhileDrawing: i32,
    checkMaskBeforeDrawing: bool,
    isInterlaceField: bool,
    isReverseFlag: bool,
    isTextureDisabled: bool,
    horizontalResolution2: u8,
    horizontalResolution1: u8,
    isVerticalResolution480: bool,
    isPal: bool,
    is24BitDepth: bool,
    isVerticalInterlace: bool,
    isDisplayDisabled: bool,
    isInterruptRequested: bool,
    isDmaRequest: bool,

    isReadyToReceiveCommand: bool,
    isReadyToSendVRAMToCPU: bool,
    isReadToReceiveDMABlock: bool,
    dmcDirection: u8,
    isOddLine: bool,

    isTextureRectangleXFlipped: bool,
    isTextureRectangleYFlipped: bool,

    drawModeBits: u32,
    displayModeBits: u32,
    displayVerticalRange: u32,
    displayHorizontalRange: u32,

    textureWindowBits: u32,
    preMaskX: i32,
    preMaskY: i32,
    postMaskX: i32,
    postMaskY: i32,

    drawingAreaLeft: u16,
    drawingAreaRight: u16,
    drawingAreaTop: u16,
    drawingAreaBottom: u16,
    drawingXOffset: i16,
    drawingYOffset: i16,

    displayVRAMXStart: u16,
    displayVRAMYStart: u16,
    displayX1: u16,
    displayX2: u16,
    displayY1: u16,
    displayY2: u16,

    videoCycles: i32,
    horizontalTiming: i32,
    verticalTiming: i32,
}

gpu_init :: proc(gpu: ^GPUState)
{
    gpu.isReadyToReceiveCommand = true;
    gpu.isReadToReceiveDMABlock = true;

    gpu.drawModeBits = 0xFFFF_FFFF;
    gpu.displayModeBits = 0xFFFF_FFFF;
    gpu.displayVerticalRange = 0xFFFF_FFFF;
    gpu.displayHorizontalRange = 0xFFFF_FFFF;

    gpu.horizontalTiming = 3413;
    gpu.verticalTiming = 263;

    // Init color table
    gpu.color1555to8888LUT = make([]i32, 1 << 16);

    // Fill color table
    for m: i32 = 0; m < 2; m += 1
    {
        for r: i32 = 0; r < 32; r += 1
        {
            for g: i32 = 0; g < 32; g += 1
            {
                for b: i32 = 0; b < 32; b += 1
                {
                    gpu.color1555to8888LUT[m << 15 | b << 10 | g << 5 | r] = m << 24 | r << 16 + 3 | g << 8 + 3| b << 3;
                }
            }
        }
    }
}

gpu_tick :: proc(ps: ^PSXState, gpu: ^GPUState, cycles: i32)
{
    gpu.videoCycles += cycles * 11 / 7;
}