package main

//import "core:fmt"
import rl "vendor:raylib"
import "../map_generator"



main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(800, 420, "raylib [models] example - cubesmap loading and drawing")
    rl.SetTargetFPS(60)

    camera := rl.Camera {
        position = rl.Vector3{ 16.0, 14.0, 16.0 },    // Camera position
        target = rl.Vector3{ 0.0, 0.0, 0.0 },         // Camera looking at point
        up = rl.Vector3{ 0.0, 1.0, 0.0 },             // Camera up vector (rotation towards target)
        fovy = 45.0,                                   // Camera field-of-view Y
        projection = .PERSPECTIVE,              // Camera projection type
    }

    pause: bool = false

    model: rl.Model = map_generator.generate_map("../resources/cubicmap.png", "../resources/cubicmap_atlas.png")

    for !rl.WindowShouldClose() {
    // Update
        //----------------------------------------------------------------------------------
        if rl.IsKeyPressed(.P) { pause = !pause}

        if !pause { rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL) }
        //----------------------------------------------------------------------------------

    // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)

        rl.DrawModel(model, rl.Vector3{-16.0, 0.0, -8.0 }, 1.0, rl.WHITE)


        rl.EndMode3D()

        rl.DrawFPS(10, 10)

        rl.EndDrawing()
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.UnloadModel(model)         // Unload map model

    rl.CloseWindow()              // Close window and OpenGL context
}
