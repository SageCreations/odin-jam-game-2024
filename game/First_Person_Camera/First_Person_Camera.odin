package game

//
///*******************************************************************************************
//*
//*   raylib [models] example - first person maze
//*
//*   Example originally created with raylib 2.5, last time updated with raylib 3.5
//*
//*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
//*   BSD-like license that allows static linking with closed source software
//*
//*   Copyright (c) 2019-2024 Ramon Santamaria (@raysan5)
//*
//********************************************************************************************/
////------------------------------------------------------------------------------------

import rl "vendor:raylib"
import "core:fmt"
import "core:c"
import "core:mem"

//// Program main entry point
////------------------------------------------------------------------------------------

// get a map generated from the passed image type. the mode atlas path will be used to texture the model mesh
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

main:: proc(){
    WINDOW_SIZE :: 1000
    rl.InitWindow(WINDOW_SIZE,WINDOW_SIZE,"First_Person_Camera")

    image : rl.Image = rl.LoadImage("../../resources/cubicmap.png")               // Load cubicmap image (RAM)
    cubicmap : rl.Texture2D = rl.LoadTextureFromImage(image)     // Convert image to texture to display (VRAM)
    map_Pixels : [^]rl.Color = rl.LoadImageColors(image) //This is a dynamic array ptrs

    camera : rl.Camera3D = {}
    camera.position = rl.Vector3{0.2,0.4,0.2}
    camera.target = rl.Vector3{0.185,0.4,0.0}
    camera.up = rl.Vector3{0.0,1.0,0.0}
    camera.fovy = 45.0
    camera.projection = .PERSPECTIVE


    model := generate_map("../../resources/cubicmap.png","../../resources/cubicmap_atlas.png")

    map_Position : rl.Vector3 = {-16.0,0.0,-8.0}

    rl.DisableCursor()
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose(){
        old_Cam_Pos: rl.Vector3 = camera.position
        rl.UpdateCamera(&camera , .FIRST_PERSON)

        player_Position : rl.Vector2 = {camera.position.x, camera.position.z}
        player_Radius : c.float = 0.1

        player_Cell_X:= cast(c.int)(player_Position.x - map_Position.x + 0.5)
        player_Cell_Y:= cast(c.int)(player_Position.y - map_Position.z + 0.5)

        //Out of Bounds Checker
       if player_Cell_X < 0 {
           player_Cell_X = 0
       }
       else if player_Cell_X >= cubicmap.width{
        player_Cell_X = cubicmap.width - 1}
        if player_Cell_Y < 0 {
            player_Cell_Y = 0
        }
        else if player_Cell_Y >= cubicmap.height{
            player_Cell_Y = cubicmap.height - 1
        }
        for y: c.int = 0 ; y < cubicmap.height; y+=1 {
            for x: c.int = 0; x < cubicmap.width; x+=1 {
            if (map_Pixels[y*cubicmap.width+ x].r == 255) && (rl.CheckCollisionCircleRec(player_Position,player_Radius,
            rl.Rectangle{map_Position.x - 0.5 + cast(c.float)x*1.0, map_Position.z - 0.5 + cast(c.float)y*1.0, 1.0, 1.0})) //This is still part of the if statement
            {
                camera.position = old_Cam_Pos
            }
        }
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)
        rl.DrawModel(model,map_Position,1.0,rl.WHITE)
        rl.EndMode3D()

        rl.DrawTextureEx(cubicmap, rl.Vector2{cast(c.float)rl.GetScreenWidth() - cast(c.float)cubicmap.width*4.0 - 20, 20.0}, 0.0, 4.0, rl.WHITE )
        rl.DrawRectangleLines(rl.GetScreenWidth() - cubicmap.width*4 - 20, 20 , cubicmap.width*4, cubicmap.height*4, rl.GREEN)

        rl.DrawRectangle(rl.GetScreenWidth() - cubicmap.width*4 - 20 + player_Cell_X*4 , 20 + player_Cell_Y*4, 4, 4, rl.RED)
        rl.DrawFPS(10,10)

        rl.EndDrawing()

    }

    rl.UnloadImageColors(map_Pixels)
    rl.UnloadTexture(cubicmap)
    rl.UnloadModel(model)
    rl.CloseWindow()
} //end

//// Draw player position radar
//DrawRectangle(GetScreenWidth() - cubicmap.width*4 - 20 + playerCellX*4, 20 + playerCellY*4, 4, 4, RED);
//
//DrawFPS(10, 10);
//
//EndDrawing();
////----------------------------------------------------------------------------------
//}
//


//// De-Initialization
////--------------------------------------------------------------------------------------
//UnloadImageColors(mapPixels);   // Unload color array
//
//UnloadTexture(cubicmap);        // Unload cubicmap texture
//UnloadTexture(texture);         // Unload map texture
//UnloadModel(model);             // Unload map model
//
//CloseWindow();                  // Close window and OpenGL context
////--------------------------------------------------------------------------------------
//
//return 0;
//}
