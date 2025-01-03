package main

//import "core:fmt"
import rl "vendor:raylib"
import "core:fmt"
import "core:c"
import "core:os"
import "core:math/rand"
import "core:c/libc"
import "core:strings"
import "core:encoding/json"


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

DATABASE_FILENAME :: "data/database.json"


Database :: struct {
    gameInit: GameData,
    liveGame: GameData,
}

Enemy :: struct {
    id: string,
    health: int,
    position: rl.Vector3,
    atk_counter: int,
}

Player :: struct {
    health: int,
    position: rl.Vector3,
    attack: int,
}

Item :: struct {
    position: rl.Vector3,
    item_type: int, // 0 - health boost, 1 - attack boost
    usable: bool,
}


init_data :: proc() -> Database {
    path := strings.concatenate({"./", DATABASE_FILENAME})

    default_data := Database {} // should default zero everything
    fmt.printfln("database: %v", default_data)

    json_data, err := json.marshal(default_data, {pretty = true})
    if err != nil {
        fmt.eprintfln("Unable to marshal JSON: %v", err)
        os.exit(1)
    }

    fmt.printfln("writing %s", path)
    werr := os.write_entire_file_or_err(path, json_data)
    if werr != nil {
        fmt.eprintfln("unable to write file: %v", werr)
        os.exit(1)
    }

    fmt.println("Done")
    return default_data
}

load_database_or_err :: proc() -> (Database, os.Error) {
    data, ok := os.read_entire_file_from_filename_or_err(DATABASE_FILENAME)
    if ok != nil {
        fmt.eprintfln("Failed to load the file: %v", ok)
        return Database{}, ok
    }
    fmt.println("Success in loading file!")

    db_ctx: Database
    if json.unmarshal(data, &db_ctx) == nil {
        fmt.println("Success in unmarshaling the data!")
    } else {
        fmt.eprintln("Failed to unmarshal JSON")
    }

    fmt.println("Returning db_context now...")
    return db_ctx, nil
}


save_database_or_err :: proc(ctx: Database) -> os.Error {
    json_data, err := json.marshal(ctx, {pretty = true})
    if err != nil {
        fmt.eprintfln("Unable to marshal JSON: %v", err)
        return nil
    }

    fmt.printfln("writing %s", DATABASE_FILENAME)
    werr := os.write_entire_file_or_err(DATABASE_FILENAME, json_data)
    if werr != nil {
        fmt.eprintfln("unable to write file: %v", werr)
        return werr
    }

    fmt.println("Done")
    return nil
}

add_health :: proc(player: ^Player) {
    if player.health < 100 {
        if player.health + 50 >= 100 {
            player.health = 100
        } else {
            player.health += 50
        }
    }
}

// returns true if player died, always asign isGameOver to this function to automaticaly determin if gameover in runtime
lose_health :: proc(player: ^Player) -> bool {
    player.health -= 20
    if player.health > 0 {
        return false
    } else {
        return true
    }
}

add_attack :: proc(player: ^Player) {
    player.attack += 20
}

// simple map generator, path for the image to generate map from and path for an atlas to apply textures to models
generate_map :: proc(cubicmap_path: cstring, atlas_path: cstring) -> rl.Model {
    image: rl.Image = rl.LoadImage(cubicmap_path)               // Load cubicmap image (RAM)
    //cubicmap: rl.Texture2D = rl.LoadTextureFromImage(image)     // Convert image to texture to display (VRAM)

    mesh: rl.Mesh = rl.GenMeshCubicmap(image, rl.Vector3{ 1.0, 1.0, 1.0 })
    model: rl.Model = rl.LoadModelFromMesh(mesh)

    // NOTE: By default each cube is mapped to one part of texture atlas
    texture: rl.Texture2D = rl.LoadTexture(atlas_path)    // Load map texture
    model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture    // Set map diffuse texture

    rl.UnloadImage(image)     // Unload cubesmap image from RAM, already uploaded to VRAM

    return model
}


main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    rl.InitWindow(1600, 900, "Escape")
    rl.SetTargetFPS(60)
    rl.DisableCursor()
    //rl.SetMouseCursor(.CROSSHAIR)
    debug: bool = false // TODO: turn false for final build
    exitWindow: bool = false
    rl.InitAudioDevice()

    // Load player walk sound
    //playerWalkSound: rl.Sound = rl.LoadSound("../resources/sounds/player_walk.wav") //TODO: add player walk
    gameplayMusic: rl.Music = rl.LoadMusicStream("resources/sounds/level_music.wav")
    pickUpItemSound: rl.Sound = rl.LoadSound("resources/sounds/pickup.wav") //   <-----
    DamagedSound: rl.Sound = rl.LoadSound("resources/sounds/enemy_hit.wav") // change pitch and reuse for player and enemy
    enemyDamageSound: rl.Sound = rl.LoadSound("resources/sounds/hit_sound.wav")
    winMusic: rl.Music = rl.LoadMusicStream("resources/sounds/Car_Game_Music.wav")
    loseMusic: rl.Music = rl.LoadMusicStream("resources/sounds/RocketGame_MenuMusic.wav")

    rl.PlayMusicStream(gameplayMusic)

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

    //cubicmap for wall collisions
    image : rl.Image = rl.LoadImage("resources/Odin_Test_Level.png")               // Load cubicmap image (RAM)
    cubicmap : rl.Texture2D = rl.LoadTextureFromImage(image)     // Convert image to texture to display (VRAM)
    map_Pixels : [^]rl.Color = rl.LoadImageColors(image) //This is a dynamic array ptrs

    //Adding the Billboard for the Health and Attack Boost
    bill_board_health : rl.Texture2D = rl.LoadTexture("resources/Health_Pick_Up.png")
    bill_board_attack : rl.Texture2D = rl.LoadTexture("resources/Attack_Pick_Up.png")
    bill_board_enemy : rl.Texture2D = rl.LoadTexture("resources/Enemy.png")

    //Adding the Sword_Srite
    sword_sprite : rl.Texture2D = rl.LoadTexture("resources/Art_Asset_Odin.png")
    position : rl.Vector2 = {f32(rl.GetScreenWidth()/2), f32(rl.GetScreenHeight()/4)}
    frame_Rect : rl.Rectangle = {0.0,0.0,cast(c.float)sword_sprite.width/4, cast(c.float)sword_sprite.height}
    current_Frame : c.int = 0
    //Frame Counter
    frame_Counter : c.int = 0
    frame_Speed : c.int = 8
    atk_active : bool = false
    attack_counter: int = 5


    player_init := Player{
        health = 100,
        attack = 20,
        position = {-14.555, 0.4, 52.001},
    }
    db_ctx.gameInit.player = player_init

    camera := rl.Camera3D {
        position = db_ctx.gameInit.player.position,            // Camera position
        target = rl.Vector3{0.185,0.4,0.0},
        up = rl.Vector3{0.0,1.0,0.0},                   // Camera up vector (rotation towards target)
        fovy = 90.0,                                  // Camera field-of-view Y
        projection = .PERSPECTIVE,                    // Camera projection type
    }
    cameraMode: rl.CameraMode = .FIRST_PERSON

    playerCubeSize: rl.Vector3 = { 1.0, 1.0, 1.0 }

    isPlayerInvuln: bool = false
    invulnCounter: int = 0

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
    model := generate_map("resources/Odin_Test_Level.png","resources/Dungeon_Map_Atlas.png")
    map_Position : rl.Vector3 = {-16.0,0.0,-8.0}

    // meshcube for the win goal
    cubeMesh: rl.Mesh = rl.GenMeshCube(0.6,0.6,0.6)
    cubeModel: rl.Model = rl.LoadModelFromMesh(cubeMesh)


    enemy_init: [dynamic]Enemy
    for &enemy in db_ctx.gameInit.enemy_list {
        enemy.position.y = 0.2
        append(&enemy_init, enemy)
    }

    for &item in db_ctx.gameInit.item_list {
        item.position.y = 0.2
        item.usable = true
    }

    db_ctx.liveGame = db_ctx.gameInit


    rotationAngle: f32 = 0.0                         // Rotation angle
    time: f32 = 0.0

    moveSpeed: f32 = 2.5 // player move speed

// GAME LOOP STARTS
    for !exitWindow {
        old_Cam_Pos: rl.Vector3 = camera.position
        rl.UpdateCamera(&camera, cameraMode) // update camera mode

        if rl.IsKeyPressed(.ESCAPE) || rl.WindowShouldClose() {
            exitWindow = true
        }

    // Update
        //--------------------------------------------------------------------------------------------------------------


        // Player wasd controls
        if !isEditorMode && !isGameOver {
            rl.UpdateMusicStream(gameplayMusic)   // Update music buffer with new stream data

            cameraMode = .CUSTOM

            // Mouse support
            mousePositionDelta: rl.Vector2 = rl.GetMouseDelta()
            rl.CameraYaw(&camera, -mousePositionDelta.x*rl.CAMERA_MOUSE_MOVE_SENSITIVITY, false)
            rl.CameraPitch(&camera, -mousePositionDelta.y*rl.CAMERA_MOUSE_MOVE_SENSITIVITY, true, false, false)


            forward: rl.Vector3 = rl.Vector3Subtract(camera.target, camera.position)
            forward = rl.Vector3Normalize(forward)

            right: rl.Vector3 = rl.Vector3CrossProduct(forward, camera.up)
            right = rl.Vector3Normalize(right)

            moveDirection: rl.Vector3 = { 0.0, 0.0, 0.0 }
            // WASD movement
            if (rl.IsKeyDown(.W)) {
                moveDirection = rl.Vector3Add(moveDirection, forward)
            }
            if (rl.IsKeyDown(.S)) {
                moveDirection = rl.Vector3Subtract(moveDirection, forward)
            }
            if (rl.IsKeyDown(.A)) {
                moveDirection = rl.Vector3Subtract(moveDirection, right)
            }
            if (rl.IsKeyDown(.D)) {
                moveDirection = rl.Vector3Add(moveDirection, right)
            }

            // Normalize diagonal movement
            if (rl.Vector3Length(moveDirection) > 0.0) {
                moveDirection = rl.Vector3Normalize(moveDirection)
                moveDirection.y = 0
            }
            // Apply movement
            camera.position = rl.Vector3Add(camera.position, rl.Vector3Scale(moveDirection, moveSpeed * rl.GetFrameTime()))
            camera.target = rl.Vector3Add(camera.target, rl.Vector3Scale(moveDirection, moveSpeed * rl.GetFrameTime()))
            camera.position.y = rl.Clamp(camera.position.y, 0.4, 0.4)

        }


        player_Position : rl.Vector2 = {camera.position.x, camera.position.z}
        player_Radius : c.float = 0.1
        player_Cell_X:= cast(c.int)(player_Position.x - map_Position.x + 0.5)
        player_Cell_Y:= cast(c.int)(player_Position.y - map_Position.z + 0.5)

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
            //Out of Bounds Checker for player
            if player_Cell_X < 0 {
                player_Cell_X = 0
            } else if player_Cell_X >= cubicmap.width {
                player_Cell_X = cubicmap.width - 1}
            if player_Cell_Y < 0 {
                player_Cell_Y = 0
            } else if player_Cell_Y >= cubicmap.height{
                player_Cell_Y = cubicmap.height - 1
            }
            for y: c.int = 0 ; y < cubicmap.height; y+=1 {
                for x: c.int = 0; x < cubicmap.width; x+=1 {
                    if (map_Pixels[y*cubicmap.width+ x].r == 255) && (rl.CheckCollisionCircleRec(player_Position,player_Radius,
                    rl.Rectangle{map_Position.x - 0.5 + cast(c.float)x*1.0, map_Position.z - 0.5 + cast(c.float)y*1.0, 1.0, 1.0})) {
                        camera.position = old_Cam_Pos
                    }
                }
            }

            db_ctx.liveGame.player.position = camera.position

            // attacking animation/cooldown
            //fmt.println("THis is the current Frame Counter: ", frame_Counter)
            if rl.IsMouseButtonPressed(.LEFT) && !atk_active{
                atk_active = true
                attack_counter += 1
            }
            //current_Frame += 1
            if atk_active {
                frame_Counter += 1
                if frame_Counter >= 60/frame_Speed{
                    frame_Counter = 0
                    current_Frame += 1  //// This was the original placment for it
                    // if current_Frame != 3{
                    //   current_Frame += 1
                    //
                    if current_Frame > 3 {
                        current_Frame = 0
                        atk_active = false
                    }
                    frame_Rect.x = cast(c.float)current_Frame*cast(c.float)sword_sprite.width/4
                }
            }
        }


        // enemy behavior
        for &enemy, idx in db_ctx.liveGame.enemy_list {
            // Check collisions player vs enemy detection cube
            if rl.CheckCollisionBoxes(rl.BoundingBox{ rl.Vector3{ db_ctx.liveGame.player.position.x - playerCubeSize.x/2, db_ctx.liveGame.player.position.y - playerCubeSize.y/2, db_ctx.liveGame.player.position.z - playerCubeSize.z/2 }, rl.Vector3{ db_ctx.liveGame.player.position.x + playerCubeSize.x/2, db_ctx.liveGame.player.position.y + playerCubeSize.y/2, db_ctx.liveGame.player.position.z + playerCubeSize.z/2 } }, rl.BoundingBox{ rl.Vector3{ enemy.position.x - enemyDetectSize.x/2, enemy.position.y - enemyDetectSize.y/2, enemy.position.z - enemyDetectSize.z/2 }, rl.Vector3{ enemy.position.x + enemyDetectSize.x/2, enemy.position.y + enemyDetectSize.y/2, enemy.position.z + enemyDetectSize.z/2 } }){
                if !isEditorMode && !isGameOver {
                    old_enemy_Pos: rl.Vector3 = enemy.position

                    direction: rl.Vector3 = enemy.position - camera.position
                    length: f32 = rl.Vector3Length(direction)

                    enemy_Cell_X:= cast(c.int)(enemy.position.x - map_Position.x + 0.5)
                    enemy_Cell_Y:= cast(c.int)(enemy.position.y - map_Position.z + 0.5)

                    //Out of Bounds Checker for enemy
                    if enemy_Cell_X < 0 {
                        enemy_Cell_X = 0
                    }else if enemy_Cell_X >= cubicmap.width{
                        enemy_Cell_X = cubicmap.width - 1}
                    if enemy_Cell_Y < 0 {
                        enemy_Cell_Y = 0
                    }else if enemy_Cell_Y >= cubicmap.height{
                        enemy_Cell_Y = cubicmap.height - 1
                    }
                    for y: c.int = 0 ; y < cubicmap.height; y+=1 {
                        for x: c.int = 0; x < cubicmap.width; x+=1 {
                            if (map_Pixels[y*cubicmap.width+ x].r == 255) && (rl.CheckCollisionCircleRec(rl.Vector2{enemy.position.x, enemy.position.z}, enemySphereSize, rl.Rectangle{map_Position.x - 0.5 + cast(c.float)x*1.0, map_Position.z - 0.5 + cast(c.float)y*1.0, 1.0, 1.0})) {
                                enemy.position = old_enemy_Pos
                            } else {
                                if (length > 0.7) { // Avoid division by zero
                                    direction = direction * (0.03 / length) // Normalize and scale
                                    enemy.position = enemy.position - direction
                                    enemy.position.y = rl.Clamp(enemy.position.y, 0.2, 0.2)
                                }
                            }
                        }
                    }

                    if length < 1.0 {
                        if !isPlayerInvuln {
                            chance: int = rand.int_max(100)
                            if chance >= 50 && chance <= 51 {
                                //fmt.printfln("player was hit")
                                rl.PlaySound(DamagedSound)
                                isPlayerInvuln = true
                                //fmt.printfln("player cannot be hurt now!!!!")
                                isGameOver = lose_health(&db_ctx.liveGame.player)
                                if isGameOver {
                                    rl.StopMusicStream(gameplayMusic)
                                    rl.PlayMusicStream(loseMusic)
                                }
                            }
                        } else {
                            invulnCounter += 1
                            //fmt.printfln("%d", invulnCounter)
                            if invulnCounter >= cast(int)(5000.0*rl.GetFrameTime()) {
                                isPlayerInvuln = false
                                invulnCounter = 0
                                //fmt.printfln("player can be hurt again.")
                            }
                        }

                        if atk_active == true && attack_counter != enemy.atk_counter {
                            enemy.health -= db_ctx.liveGame.player.attack
                            enemy.atk_counter = attack_counter
                            rl.PlaySound(enemyDamageSound)
                            if enemy.health <= 0 {
                                unordered_remove(&db_ctx.liveGame.enemy_list, idx)
                            }
                        }
                    }
                }
            }
        }

        // Pickup collisons
        for &item, idx in db_ctx.liveGame.item_list {
            // Check collisions player vs enemy detection cube
            if rl.CheckCollisionBoxes(rl.BoundingBox{ rl.Vector3{ db_ctx.liveGame.player.position.x - playerCubeSize.x/2, db_ctx.liveGame.player.position.y - playerCubeSize.y/2, db_ctx.liveGame.player.position.z - playerCubeSize.z/2 }, rl.Vector3{ db_ctx.liveGame.player.position.x + playerCubeSize.x/2, db_ctx.liveGame.player.position.y + playerCubeSize.y/2, db_ctx.liveGame.player.position.z + playerCubeSize.z/2 } }, rl.BoundingBox{ rl.Vector3{ item.position.x - pickupDetectSize.x/2, item.position.y - pickupDetectSize.y/2, item.position.z - pickupDetectSize.z/2 }, rl.Vector3{ item.position.x + pickupDetectSize.x/2, item.position.y + pickupDetectSize.y/2, item.position.z + pickupDetectSize.z/2 } }){
                if item.usable {
                    if item.item_type == 0 { // if true then health boost else attack boost
                        add_health(&db_ctx.liveGame.player)
                        item.usable = false
                        unordered_remove(&db_ctx.liveGame.item_list, idx)
                        rl.PlaySound(pickUpItemSound)
                    } else {
                        add_attack(&db_ctx.liveGame.player)
                        item.usable = false
                        unordered_remove(&db_ctx.liveGame.item_list, idx)
                        rl.PlaySound(pickUpItemSound)
                    }
                }
            }
        }

        // win goal collision check
        if !isWin {
            if rl.CheckCollisionBoxes(rl.BoundingBox{ rl.Vector3{ db_ctx.liveGame.player.position.x - playerCubeSize.x/2, db_ctx.liveGame.player.position.y - playerCubeSize.y/2, db_ctx.liveGame.player.position.z - playerCubeSize.z/2 }, rl.Vector3{ db_ctx.liveGame.player.position.x + playerCubeSize.x/2, db_ctx.liveGame.player.position.y + playerCubeSize.y/2, db_ctx.liveGame.player.position.z + playerCubeSize.z/2 } }, rl.BoundingBox{ rl.Vector3{ db_ctx.liveGame.win_location.x - pickupDetectSize.x/2, db_ctx.liveGame.win_location.y - pickupDetectSize.y/2, db_ctx.liveGame.win_location.z - pickupDetectSize.z/2 }, rl.Vector3{ db_ctx.liveGame.win_location.x + pickupDetectSize.x/2, db_ctx.liveGame.win_location.y + pickupDetectSize.y/2, db_ctx.liveGame.win_location.z + pickupDetectSize.z/2 } }){
                isWin = true
                isGameOver = true
                rl.StopMusicStream(gameplayMusic)
                rl.PlayMusicStream(winMusic)
            }
        }

        if isGameOver {
            if !isWin {
                rl.UpdateMusicStream(loseMusic)
            } else {
                rl.UpdateMusicStream(winMusic)
            }
        }

        //--------------------------------------------------------------------------------------------------------------


    // Draw
        //--------------------------------------------------------------------------------------------------------------
        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)

        rl.BeginMode3D(camera)

        // draw the map
        rl.DrawModel(model, map_Position, 1.0, rl.WHITE)

        // draw enemies
        for enemy in db_ctx.liveGame.enemy_list {
            //rl.DrawSphereEx(enemy.position, enemySphereSize, 16, 16, rl.ORANGE)
            rl.DrawBillboard(camera, bill_board_enemy ,enemy.position,1,rl.WHITE)
            if debug {
                rl.DrawCubeWiresV(enemy.position, enemyDetectSize, rl.GREEN)
            }
        }

        // Draw items
        for item in db_ctx.liveGame.item_list {
            //rl.DrawCubeV(item.position, {0.3,0.3,0.3}, (item.item_type == 1) ? rl.RED : rl.GREEN)
            rl.DrawBillboard(camera, (item.item_type == 0) ? bill_board_health : bill_board_attack, item.position, 0.25, rl.WHITE)
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


        if isEditorMode {
            rl.DrawFPS(rl.GetScreenWidth()/2, 10)
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
                save_database_or_err(db_ctx)
            }
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

        } else if isGameOver {
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
                db_ctx, _ = load_database_or_err()
                isGameOver = false
                isWin = false
                if !isWin {
                    rl.StopMusicStream(loseMusic)
                } else {
                    rl.StopMusicStream(winMusic)
                }
                rl.PlayMusicStream(gameplayMusic)

                if !rl.IsCursorHidden() {
                    rl.DisableCursor()
                }
            }


        } else { // Gameplay HUD
            rl.DrawRectangle(20, 20, 200, 80, rl.Fade(rl.DARKGRAY, 0.90))
            rl.DrawRectangleLines(20, 20, 200, 80, rl.BLACK)
            rl.DrawText(rl.TextFormat("HP: %d/100", db_ctx.liveGame.player.health), 30, 25, 30, (db_ctx.liveGame.player.health > 50) ? rl.GREEN: rl.RED)
            rl.DrawText(rl.TextFormat("Attack: %d%%", db_ctx.liveGame.player.attack), 30, 62, 30, rl.RED)

            // minimap
            rl.DrawTextureEx(cubicmap, rl.Vector2{cast(c.float)rl.GetScreenWidth() - cast(c.float)cubicmap.width*4.0 - 20, 20.0}, 0.0, 4.0, rl.WHITE )
            rl.DrawRectangleLines(rl.GetScreenWidth() - cubicmap.width*4 - 20, 20 , cubicmap.width*4, cubicmap.height*4, rl.GREEN)

            //Draw Sword
            rl.DrawTextureRec(sword_sprite,frame_Rect,position,rl.WHITE)

            // red dot on minimap
            rl.DrawRectangle(rl.GetScreenWidth() - cubicmap.width*4 - 20 + player_Cell_X*4 , 20 + player_Cell_Y*4, 4, 4, rl.RED)


        }


        //--------------------------------------------------------------------------------------------------------------
        rl.EndDrawing()
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.UnloadModel(model)         // Unload map model
    rl.CloseAudioDevice()         // Close audio device (music streaming is automatically stopped)

    //db_ctx.gameInit.enemy_list = enemy_init
    //save_database_or_err(db_ctx)

    rl.CloseWindow()              // Close window and OpenGL context
}
