package main

import "core:fmt"
import "vendor:raylib"

DISPLAY_WIDTH :: 640;
DISPLAY_HEIGHT :: 480;

main :: proc() 
{
    // Create PSX state
    psx, success := psx_init();
    defer psx_cleanup(psx);


    // Set raylib logging
    raylib.SetTraceLogLevel(raylib.TraceLogLevel.WARNING);

    // Init window
    raylib.InitWindow(DISPLAY_WIDTH, DISPLAY_HEIGHT, "PS-Odin");
    defer raylib.CloseWindow();

    // Limit to 60 herts
    raylib.SetTargetFPS(60);

    // Main loop
    for raylib.WindowShouldClose() == false
    {
        // Start drawing the display
        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        // Clear the background
        raylib.ClearBackground(raylib.BLACK);
    }
}