package main

//import "core:fmt"
import rl "vendor:raylib"
import "../map_generator"
import "core:fmt"
import "core:c"
import "core:sys/posix"
import "core:os"
import "core:math/rand"
import "core:c/libc"

ControlPoint :: struct {
    start: rl.Vector2,
    end:   rl.Vector2,
}


ItemType :: enum {
    ENEMY_SPAWN_LOC = 0,
    HEALTH_BOOST = 1,
    ATTACK_BOOST = 2,
    PLAYER_START_LOC = 3,
    WIN_LOCATION = 4,
}


GameData :: struct {
    player: Player,
    enemy_list: [dynamic]Enemy, //enemy id as key and its position data
    item_list: [dynamic]Item,
    win_location: rl.Vector3, // spawn cube here
}



main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(1920, 1080, "raylib [models] example - cubesmap loading and drawing")
    rl.SetTargetFPS(60)
    rl.DisableCursor()
    //rl.SetMouseCursor(.CROSSHAIR)
    debug: bool = true // TODO: turn false for final build
    exitWindow: bool = false


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


    player_init := Player{
        health = 100,
        attack = 20,
        position = {0.2, 0.4, 0.2}
    }
    db_ctx.gameInit.player = player_init

    camera := rl.Camera3D {
        position = db_ctx.gameInit.player.position,            // Camera position
        target = rl.Vector3{ 0.0, 1.0, 0.0 },         // Camera looking at point
        up = rl.Vector3{ 0.0, 1.0, 0.0 },             // Camera up vector (rotation towards target)
        fovy = 90.0,                                  // Camera field-of-view Y
        projection = .PERSPECTIVE,                    // Camera projection type
    }
    cameraMode: rl.CameraMode = .FIRST_PERSON

    playerCubeSize: rl.Vector3 = { 1.0, 1.0, 1.0 }
    size: f32 = 0.5



    isInitSetting: bool = false // for checkbox to dictate which part of the database to update
    isEditorMode: bool = false // whether we are in editor mode or not
    isGameOver: bool = false // is the game over
    isWin: bool = false

    itemPlacementActive: ItemType = .ENEMY_SPAWN_LOC // drop down option
    itemPlacementEdit: bool = false // drop down editor stuff

    enemySphereSize: f32 = 0.3
    enemyDetectSize: rl.Vector3 = {7.0,1.0,7.0}
    pickupDetectSize: rl.Vector3 = {1.0,1.0,1.0}

    // generate the map
    model: rl.Model = map_generator.generate_map("../resources/cubicmap.png", "../resources/cubicmap_atlas.png")

    // meshcube for the win goal
    cubeMesh: rl.Mesh = rl.GenMeshCube(0.6,0.6,0.6)
    cubeModel: rl.Model = rl.LoadModelFromMesh(cubeMesh)


    enemy_init: [dynamic]Enemy
    for enemy in db_ctx.gameInit.enemy_list {
        append(&enemy_init, enemy)
    }
    db_ctx.liveGame = db_ctx.gameInit


    rotationAngle: f32 = 0.0                         // Rotation angle
    time: f32 = 0.0

// GAME LOOP STARTS
    for !exitWindow {
        if rl.IsKeyPressed(.ESCAPE) || rl.WindowShouldClose() {
            exitWindow = true
        }
    // Update
        //--------------------------------------------------------------------------------------------------------------
        if debug {
            if rl.IsKeyPressed(.J) { // toggle between editing/play mode
                isEditorMode = !isEditorMode
                if isEditorMode == false {
                    //rl.UpdateCamera(&camera, .FIRST_PERSON)
                    camera.position = db_ctx.liveGame.player.position
                }
            }
        }

        // decide camera mode and cursor status
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
        } else if isGameOver {
            cameraMode = .CUSTOM
            if rl.IsCursorHidden() {
                rl.EnableCursor()
            }
        } else {
            cameraMode = .FIRST_PERSON

            db_ctx.liveGame.player.position = camera.position
        }


        rl.UpdateCamera(&camera, cameraMode) // update camera mode


        // enemy behavior
        for &enemy in db_ctx.liveGame.enemy_list {
            // Check collisions player vs enemy detection cube
            if rl.CheckCollisionBoxes(
                rl.BoundingBox{
                    rl.Vector3{ db_ctx.liveGame.player.position.x - playerCubeSize.x/2, db_ctx.liveGame.player.position.y - playerCubeSize.y/2, db_ctx.liveGame.player.position.z - playerCubeSize.z/2 },
                    rl.Vector3{ db_ctx.liveGame.player.position.x + playerCubeSize.x/2, db_ctx.liveGame.player.position.y + playerCubeSize.y/2, db_ctx.liveGame.player.position.z + playerCubeSize.z/2 }
                },
                rl.BoundingBox{
                    rl.Vector3{ enemy.position.x - enemyDetectSize.x/2, enemy.position.y - enemyDetectSize.y/2, enemy.position.z - enemyDetectSize.z/2 },
                    rl.Vector3{ enemy.position.x + enemyDetectSize.x/2, enemy.position.y + enemyDetectSize.y/2, enemy.position.z + enemyDetectSize.z/2 }
                })
            {
                if !isEditorMode {
                    direction: rl.Vector3 = enemy.position - camera.position
                    length: f32 = rl.Vector3Length(direction)

                    if (length > 0.7) { // Avoid division by zero
                        direction = direction * (0.01 / length) // Normalize and scale
                        enemy.position = enemy.position - direction
                    }
                    if length < 1.0 {
                        chance: int = rand.int_max(100)
                        if chance >= 50 && chance <= 51 {
                            // TODO: play sound
                            isGameOver = lose_health(&db_ctx.liveGame.player)
                        }
                    }
                }
            }
        }

        // Pickup collisons
        for item, idx in db_ctx.liveGame.item_list {
            // Check collisions player vs enemy detection cube
            if rl.CheckCollisionBoxes(
                rl.BoundingBox{
                    rl.Vector3{ db_ctx.liveGame.player.position.x - playerCubeSize.x/2, db_ctx.liveGame.player.position.y - playerCubeSize.y/2, db_ctx.liveGame.player.position.z - playerCubeSize.z/2 },
                    rl.Vector3{ db_ctx.liveGame.player.position.x + playerCubeSize.x/2, db_ctx.liveGame.player.position.y + playerCubeSize.y/2, db_ctx.liveGame.player.position.z + playerCubeSize.z/2 }
                },
                rl.BoundingBox{
                    rl.Vector3{ item.position.x - pickupDetectSize.x/2, item.position.y - pickupDetectSize.y/2, item.position.z - pickupDetectSize.z/2 },
                    rl.Vector3{ item.position.x + pickupDetectSize.x/2, item.position.y + pickupDetectSize.y/2, item.position.z + pickupDetectSize.z/2 }
                })
            {
                if item.item_type == 0 { // if true then health boost else attack boost
                    add_health(&db_ctx.liveGame.player)
                    unordered_remove(&db_ctx.liveGame.item_list, idx)
                } else {
                    add_attack(&db_ctx.liveGame.player)
                    unordered_remove(&db_ctx.liveGame.item_list, idx)
                }
            }
        }

        // win goal collision check
        if rl.CheckCollisionBoxes(
            rl.BoundingBox{
                rl.Vector3{ db_ctx.liveGame.player.position.x - playerCubeSize.x/2, db_ctx.liveGame.player.position.y - playerCubeSize.y/2, db_ctx.liveGame.player.position.z - playerCubeSize.z/2 },
                rl.Vector3{ db_ctx.liveGame.player.position.x + playerCubeSize.x/2, db_ctx.liveGame.player.position.y + playerCubeSize.y/2, db_ctx.liveGame.player.position.z + playerCubeSize.z/2 }
            },
            rl.BoundingBox{
                rl.Vector3{ db_ctx.liveGame.win_location.x - pickupDetectSize.x/2, db_ctx.liveGame.win_location.y - pickupDetectSize.y/2, db_ctx.liveGame.win_location.z - pickupDetectSize.z/2 },
                rl.Vector3{ db_ctx.liveGame.win_location.x + pickupDetectSize.x/2, db_ctx.liveGame.win_location.y + pickupDetectSize.y/2, db_ctx.liveGame.win_location.z + pickupDetectSize.z/2 }
            })
        {
            isWin = true
            isGameOver = true
        }



        //--------------------------------------------------------------------------------------------------------------


    // Draw
        //--------------------------------------------------------------------------------------------------------------
        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)

        rl.BeginMode3D(camera)

        // draw the map
        rl.DrawModel(model, rl.Vector3{-16.0, 0.0, -8.0 }, 1.0, rl.WHITE)

        // draw enemies
        for enemy in db_ctx.liveGame.enemy_list {
            rl.DrawSphereEx(enemy.position, enemySphereSize, 16, 16, rl.ORANGE)
            if debug {
                rl.DrawCubeWiresV(enemy.position, enemyDetectSize, rl.GREEN)
            }
        }

        // Draw items
        for item in db_ctx.liveGame.item_list {
            rl.DrawCubeV(item.position, {0.3,0.3,0.3}, (item.item_type == 1) ? rl.RED : rl.GREEN)
            if debug {
                rl.DrawCubeWiresV(item.position, pickupDetectSize, rl.GREEN)
            }
        }

        // draw win goal
        // Update rotation and floating position
        rotationAngle = 10.0 * rl.GetFrameTime() // Rotate 90 degrees per second
        if rotationAngle >= 360.0 {
            rotationAngle -= 360.0
        }
        time += rl.GetFrameTime()
        offset: f32 = libc.sinf(time) * 0.1 // Sine wave for vertical movement

        cubeModel.transform = rl.MatrixMultiply(rl.MatrixRotateY(rotationAngle * rl.DEG2RAD), cubeModel.transform)// something like that
        rl.DrawModelEx(cubeModel, {db_ctx.liveGame.win_location.x, (db_ctx.liveGame.win_location.y+.5)+offset, db_ctx.liveGame.win_location.z}, {rotationAngle, rotationAngle, rotationAngle}, 0.0, {1.0, 1.0, 1.0}, rl.GOLD)





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
            if rl.GuiDropdownBox(rl.Rectangle{ 20, 195 + 24, 190, 28 }, "ENEMY_SPAWN_LOC;HEALTH_BOOST;ATTACK_BOOST;PLAYER_START_LOC;WIN_LOCATION", cast(^i32)&itemPlacementActive, itemPlacementEdit) {
                itemPlacementEdit = !itemPlacementEdit
            }
            // save button and logic
            if rl.GuiButton(rl.Rectangle{20, 270, 100, 24}, "Save") {
                switch itemPlacementActive {
                    case .ENEMY_SPAWN_LOC:
                        new_id: string = fmt.aprintf("%d-%d", rand.int_max(100000000), rand.int_max(100000))
                        append(&db_ctx.gameInit.enemy_list, Enemy{id = new_id, health = 100, position = camera.position})
                        append(&enemy_init, Enemy{id = new_id, health = 100, position = camera.position})
                    case .HEALTH_BOOST:
                        append(&db_ctx.gameInit.item_list, Item{position = camera.position, item_type = 0})
                    case .ATTACK_BOOST:
                        append(&db_ctx.gameInit.item_list, Item{position = camera.position, item_type = 1})
                    case .PLAYER_START_LOC:
                        db_ctx.gameInit.player.position = camera.position
                    case .WIN_LOCATION:
                        db_ctx.gameInit.win_location = camera.position
                }
                db_ctx.liveGame = db_ctx.gameInit
            }
        } else if isGameOver {
            //TODO: let user choose to restart or exit
            rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.Fade(rl.BLACK, 0.8))

            if isWin {
                rl.DrawText("You made it out!\n\t\tCongrats", rl.GetScreenWidth()/2-250, rl.GetScreenHeight()/2-175, 75, rl.GREEN)
            } else {
                rl.DrawText("Better luck escaping next time...", rl.GetScreenWidth()/2-550, rl.GetScreenHeight()/2-100, 75, rl.RED)
            }

            if rl.GuiButton(rl.Rectangle{f32(rl.GetScreenWidth())/2.0 - 200.0, f32(rl.GetScreenHeight())/2.0, 150, 50}, "Quit") {
                exitWindow = true
            }
            if rl.GuiButton(rl.Rectangle{f32(rl.GetScreenWidth())/2.0 + 50.0, f32(rl.GetScreenHeight())/2.0, 150, 50}, "Retry") {
                db_ctx.gameInit.enemy_list = enemy_init
                camera.position = player_init.position
                db_ctx.gameInit.player = player_init
                db_ctx.liveGame = db_ctx.gameInit
                isGameOver = false
                isWin = false
                if !rl.IsCursorHidden() { rl.HideCursor() }
            }


        } else { // Gameplay HUD
            rl.DrawRectangle(10, 10, 250, 100, rl.Fade(rl.DARKGRAY, 0.95))
            rl.DrawRectangleLines(10, 10, 250, 100, rl.BLACK)
            rl.DrawText(rl.TextFormat("HP: %d/100", db_ctx.liveGame.player.health), 20, 15, 30, (db_ctx.liveGame.player.health > 50) ? rl.GREEN: rl.RED)
            rl.DrawText(rl.TextFormat("Attack: %d%%", db_ctx.liveGame.player.attack), 20, 45, 30, rl.YELLOW)
        }



        //--------------------------------------------------------------------------------------------------------------
        rl.EndDrawing()
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.UnloadModel(model)         // Unload map model

    db_ctx.gameInit.enemy_list = enemy_init
    save_database_or_err(db_ctx)


    rl.CloseWindow()              // Close window and OpenGL context
}
