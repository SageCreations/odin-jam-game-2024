package map_generator

import rl "vendor:raylib"

// get a image texture
get_cubicmap :: proc(path: cstring) -> rl.Texture2D {
    image: rl.Image = rl.LoadImage(path)      // Load cubicmap image (RAM)
    return rl.LoadTextureFromImage(image)     // Convert image to texture to display (VRAM)
}

// get a map generated from the passed image type. the mode atlas path will be used to texture the model mesh
get_generated_map_from_image :: proc(image_to_gen_from: rl.Image, atlas_texture_path: cstring) -> rl.Model {
    mesh: rl.Mesh = rl.GenMeshCubicmap(image_to_gen_from, rl.Vector3{ 1.0, 1.0, 1.0 })
    model: rl.Model = rl.LoadModelFromMesh(mesh)


    // NOTE: By default each cube is mapped to one part of texture atlas
    texture: rl.Texture2D = rl.LoadTexture(atlas_texture_path)    // Load map texture
    model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture    // Set map diffuse texture

    rl.UnloadImage(image_to_gen_from)     // Unload cubesmap image from RAM, already uploaded to VRAM


    return model
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

/*
main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(800, 420, "raylib [models] example - cubesmap loading and drawing")
    //rl.SetWindowPosition(200, 200)
    rl.SetTargetFPS(60)


    // Define the camera to look into our 3d world
    camera := rl.Camera {
        position = rl.Vector3{ 16.0, 14.0, 16.0 },    // Camera position
        target = rl.Vector3{ 0.0, 0.0, 0.0 },         // Camera looking at point
        up = rl.Vector3{ 0.0, 1.0, 0.0 },             // Camera up vector (rotation towards target)
        fovy = 45.0,                                   // Camera field-of-view Y
        projection = rl.CameraProjection.PERSPECTIVE,              // Camera projection type
    }

    image: rl.Image = rl.LoadImage("resources/cubicmap.png")      // Load cubicmap image (RAM)
    cubicmap: rl.Texture2D = rl.LoadTextureFromImage(image)       // Convert image to texture to display (VRAM)

    mesh: rl.Mesh = rl.GenMeshCubicmap(image, rl.Vector3{ 1.0, 1.0, 1.0 })
    model: rl.Model = rl.LoadModelFromMesh(mesh)

    // NOTE: By default each cube is mapped to one part of texture atlas
    texture: rl.Texture2D = rl.LoadTexture("resources/cubicmap_atlas.png")    // Load map texture
    model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture    // Set map diffuse texture

    mapPosition: rl.Vector3 = { -16.0, 0.0, -8.0 }        // Set model position

    rl.UnloadImage(image)     // Unload cubesmap image from RAM, already uploaded to VRAM

    pause: bool = false     // Pause camera orbital rotation (and zoom)

    rl.SetTargetFPS(60)                   // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    for !rl.WindowShouldClose() {
    // Update
    //----------------------------------------------------------------------------------
        if rl.IsKeyPressed(.P) { pause = !pause}

        if !pause { rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL) }
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()

        rl.ClearBackground(rl.RAYWHITE);

        rl.BeginMode3D(camera);

        rl.DrawModel(model, mapPosition, 1.0, rl.WHITE);

        rl.EndMode3D()

        rl.DrawTextureEx(cubicmap, rl.Vector2{ f32(rl.GetScreenWidth()) - f32(cubicmap.width)*4.0 - 20.0, 20.0 }, 0.0, 4.0, rl.WHITE)
        rl.DrawRectangleLines(rl.GetScreenWidth() - cubicmap.width*4 - 20, 20, cubicmap.width*4, cubicmap.height*4, rl.GREEN)

        rl.DrawText("cubicmap image used to", 658, 90, 10, rl.GRAY)
        rl.DrawText("generate map 3d model", 658, 104, 10, rl.GRAY)

        rl.DrawFPS(10, 10);

        rl.EndDrawing()
    //----------------------------------------------------------------------------------
    }
    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.UnloadTexture(cubicmap)    // Unload cubicmap texture
    rl.UnloadTexture(texture)     // Unload map texture
    rl.UnloadModel(model)         // Unload map model

    rl.CloseWindow()              // Close window and OpenGL context
//--------------------------------------------------------------------------------------
}
*/