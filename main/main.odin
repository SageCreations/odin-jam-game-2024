package main

//import "core:fmt"
import rl "vendor:raylib"
import "../map_generator"
import "core:fmt"
import "core:c"
import "core:sys/posix"
import "core:os"
import "core:math/rand"

ControlPoint :: struct {
    start: rl.Vector2,
    end:   rl.Vector2,
}


ItemType :: enum {
    ENEMY_SPAWN_LOC = 0,
    HEALTH_BOOST = 1,
    ATTACK_BOOST = 2,
    PLAYER_START_LOC = 3,
}


GameData :: struct {
    player: Player,
    player_spawn: rl.Vector3,
    enemy_list: [dynamic]Enemy, //enemy id as key and its position data
    health_boost_spawn_points: [dynamic]rl.Vector3,
    attack_boost_spawn_points: [dynamic]rl.Vector3,
}



main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(1920, 1080, "raylib [models] example - cubesmap loading and drawing")
    rl.SetTargetFPS(60)
    rl.DisableCursor()
    //rl.SetMouseCursor(.CROSSHAIR)



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


    db_ctx.gameInit.player = Player{
        health = 100,
        attack = 20,
        position = {0.2, 0.4, 0.2}
    }

    camera := rl.Camera3D {
        position = db_ctx.gameInit.player.position,            // Camera position
        target = rl.Vector3{ 0.0, 1.0, 0.0 },         // Camera looking at point
        up = rl.Vector3{ 0.0, 1.0, 0.0 },             // Camera up vector (rotation towards target)
        fovy = 90.0,                                  // Camera field-of-view Y
        projection = .PERSPECTIVE,                    // Camera projection type
    }
    cameraMode: rl.CameraMode = .FIRST_PERSON

    editorCubePosition: rl.Vector3 = { 0.0, 1.0, 0.0 }
    editorCubeSize: rl.Vector3 = { 2.0, 2.0, 2.0 }
    size: f32 = 0.5
    cubeMesh: rl.Mesh = rl.GenMeshCube(size,size,size)
    cubeModel: rl.Model  = rl.LoadModelFromMesh(cubeMesh)


    isInitSetting: bool = false // for checkbox to dictate which part of the database to update
    isEditorMode: bool = false // whether we are in editor mode or not
    isGameOver: bool = false // is the game over

    itemPlacementActive: ItemType = .ENEMY_SPAWN_LOC // drop down option
    itemPlacementEdit: bool = false // drop down editor stuff

    // generate the map
    model: rl.Model = map_generator.generate_map("../resources/cubicmap.png", "../resources/cubicmap_atlas.png")

    for !rl.WindowShouldClose() {
    // Update
        //--------------------------------------------------------------------------------------------------------------
        if rl.IsKeyPressed(.J) { // toggle between editing/play mode
            isEditorMode = !isEditorMode

            if isEditorMode == false {
                //rl.UpdateCamera(&camera, .FIRST_PERSON)
                camera.position = db_ctx.storedSession.player.position
            } else {

                //rl.UpdateCamera(&camera, .FREE)
            }
        }

        if isEditorMode {
            if rl.IsCursorHidden() {
                if rl.IsKeyPressed(.K) {
                    rl.EnableCursor()
                }
                cameraMode = .FREE
            } else {
                if rl.IsKeyPressed(.K) {
                    rl.DisableCursor()
                }
                cameraMode = .CUSTOM
            }
        } else {
            cameraMode = .FIRST_PERSON

            db_ctx.storedSession.player.position = camera.position
        }


        rl.UpdateCamera(&camera, cameraMode)









        //--------------------------------------------------------------------------------------------------------------


    // Draw
        //--------------------------------------------------------------------------------------------------------------
        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)

        rl.BeginMode3D(camera)

        // draw the map
        rl.DrawModel(model, rl.Vector3{-16.0, 0.0, -8.0 }, 1.0, rl.WHITE)

        // draw enemies
        for  {

        }




        rl.EndMode3D()
        //--------------------------------------------------------------------------------------------------------------

    //GUI CODE
        //--------------------------------------------------------------------------------------------------------------
        rl.DrawFPS(rl.GetScreenWidth()-100, 10)

        if isEditorMode {
            // camera dubug info
            rl.DrawRectangle(10, 10, 250, 100, rl.Fade(rl.SKYBLUE, 0.7))
            rl.DrawRectangleLines(10, 10, 250, 100, rl.BLUE)
            rl.DrawText("Camera status:", 20, 15, 15, rl.BLACK)
            rl.DrawText(rl.TextFormat("- Mode: %s", (cameraMode == .FREE) ? "FREE" : "FirstPerson"), 20, 45, 12, rl.BLACK)
            rl.DrawText(rl.TextFormat("- Position: (%06.3f, %06.3f, %06.3f)", camera.position.x, camera.position.y, camera.position.z), 20, 60, 12, rl.BLACK)
            rl.DrawText(rl.TextFormat("- Target: (%06.3f, %06.3f, %06.3f)", camera.target.x, camera.target.y, camera.target.z), 20, 75, 12, rl.BLACK)
            rl.DrawText(rl.TextFormat("- Up: (%06.3f, %06.3f, %06.3f)", camera.up.x, camera.up.y, camera.up.z), 20, 90, 12, rl.BLACK)

            // dropdown for item type to save location
            rl.DrawRectangle(10, 150, 250, 150, rl.Fade(rl.RAYWHITE, 0.7))
            rl.DrawRectangleLines(10, 150, 250, 150, rl.BLACK)
            rl.DrawText("Item Placement:", 15, 160, 15, rl.BLACK)
            // Check all possible UI states that require controls lock
            if itemPlacementEdit{
                rl.GuiLock()
            }
            rl.GuiCheckBox(rl.Rectangle{ 20, 178, 20, 20 }, "Edit Initial Game State", &isInitSetting)
            rl.GuiUnlock()
            rl.GuiLabel(rl.Rectangle{ 20, 200, 150, 24 }, "Item position to store:")
            if rl.GuiDropdownBox(rl.Rectangle{ 20, 195 + 24, 190, 28 }, "ENEMY_SPAWN_LOC;HEALTH_BOOST;ATTACK_BOOST;PLAYER_START_LOC", cast(^i32)&itemPlacementActive, itemPlacementEdit) {
                itemPlacementEdit = !itemPlacementEdit
            }
            isSave: bool = rl.GuiButton(rl.Rectangle{20, 270, 100, 24}, "Save")
            if isSave {
                switch itemPlacementActive {
                    case .ENEMY_SPAWN_LOC:
                        new_id: string = fmt.aprintf("%d", rand.int_max(100000000))
                        if new_id in db_ctx.gameInit.enemy_spawn_points {
                            db_ctx.gameInit.enemy_spawn_points[new_id] = camera.position
                        } else { fmt.printfln("DO IT AGAIN, REPEATED ID") }
                    case .HEALTH_BOOST:
                        append(&db_ctx.gameInit.health_boost_spawn_points, camera.position)
                    case .ATTACK_BOOST:
                        append(&db_ctx.gameInit.attack_boost_spawn_points, camera.position)
                    case .PLAYER_START_LOC:
                        db_ctx.gameInit.player_spawn = camera.position
                }
            }
        }

        if isGameOver {
            //TODO: pause game
            //TODO: show mouse
            //TODO: let user choose to restart or exit
        }

        //--------------------------------------------------------------------------------------------------------------
        rl.EndDrawing()
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.UnloadModel(model)         // Unload map model

    save_database_or_err(db_ctx)


    rl.CloseWindow()              // Close window and OpenGL context
}
