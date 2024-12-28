package main

//import "core:fmt"
import rl "vendor:raylib"
import "../map_generator"
import "core:fmt"
import "core:c"
import "core:sys/posix"
import "core:os"

ControlPoint :: struct {
    start: rl.Vector2,
    end:   rl.Vector2,
}

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(1920, 1080, "raylib [models] example - cubesmap loading and drawing")
    rl.SetTargetFPS(60)
    //rl.DisableCursor()
    rl.SetMouseCursor(.CROSSHAIR)

    // extract data context from project file to workwith in main loop.
    db_ctx, err := load_database_or_err()
    if err != nil {
        fmt.printfln("err: %v", err)
        switch err {
        case .Not_Exist, .Invalid_File, .Invalid_Dir, .Invalid_Path, os.ENOENT: // needed on linux but doesnt with development in linux
            fmt.printfln("Creating new Project file")
            db_ctx = init_data()
        case:
            fmt.eprintln("Failed to create a DB context")
            os.exit(1)
        }
    }
    fmt.printfln("database: %v", db_ctx)




    db_ctx.player = Player{
        health = 100,
        attack = 20,
        position = {0.2, 0.4, 0.2}
    }

    ray: rl.Ray = {}                     // Picking line ray
    collision: rl.RayCollision = {}     // Ray collision hit info

    camera := rl.Camera3D {
        position = db_ctx.player.position,            // Camera position
        target = rl.Vector3{ 0.0, 0.0, 0.0 },         // Camera looking at point
        up = rl.Vector3{ 0.0, 1.0, 0.0 },             // Camera up vector (rotation towards target)
        fovy = 90.0,                                  // Camera field-of-view Y
        projection = .PERSPECTIVE,                    // Camera projection type
    }
    rl.UpdateCamera(&camera, .FREE)

    pause: bool = false

    model: rl.Model = map_generator.generate_map("../resources/cubicmap.png", "../resources/cubicmap_atlas.png")

    for !rl.WindowShouldClose() {
    // Update
        //----------------------------------------------------------------------------------
        if rl.IsKeyPressed(.P) { pause = !pause}

        if !pause {
            rl.UpdateCamera(&camera, .CUSTOM)
        } else {
            rl.UpdateCamera(&camera, rl.CameraMode.FREE)
        }



        //----------------------------------------------------------------------------------


    // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)

        rl.DrawModel(model, rl.Vector3{-16.0, 0.0, -8.0 }, 1.0, rl.WHITE)


        rl.EndMode3D()

        rl.DrawFPS(10, 10)



        rl.DrawRectangle(600, 5, 195, 100, rl.Fade(rl.SKYBLUE, 0.5))
        rl.DrawRectangleLines(600, 5, 195, 100, rl.BLUE)

        rl.DrawText("Camera status:", 610, 15, 10, rl.BLACK)
        rl.DrawText(rl.TextFormat("- Mode: %s", "FREE"), 610, 45, 10, rl.BLACK)
        rl.DrawText(rl.TextFormat("- Position: (%06.3f, %06.3f, %06.3f)", camera.position.x, camera.position.y, camera.position.z), 610, 60, 10, rl.BLACK)
        rl.DrawText(rl.TextFormat("- Target: (%06.3f, %06.3f, %06.3f)", camera.target.x, camera.target.y, camera.target.z), 610, 75, 10, rl.BLACK)
        rl.DrawText(rl.TextFormat("- Up: (%06.3f, %06.3f, %06.3f)", camera.up.x, camera.up.y, camera.up.z), 610, 90, 10, rl.BLACK)

        rl.EndDrawing()
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.UnloadModel(model)         // Unload map model

    save_database_or_err(db_ctx)


    rl.CloseWindow()              // Close window and OpenGL context
}
