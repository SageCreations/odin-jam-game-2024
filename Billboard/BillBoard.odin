package Billboard

import rl "vendor:raylib"
import "core:fmt"
import "core:c"

main:: proc() {

    //This is going to be the Billboard Texture for the health/weapon boost
    bill_board : rl.Texture2D = rl.LoadTexture("../resources/Health_Pick_Up.png")
    bill_Position_Static : rl.Vector3 = {0.0,2.0,0.0}

    //Entire Billboard Texture
    source : rl.Rectangle = {0.0,0.0,cast(c.float)bill_board.width,cast(c.float)bill_board.height}

    //Billboard locked on Y axis
    bill_up : rl.Vector3 = {0.0,1.0,0.0}

    //Set height for billboard
    size : rl.Vector2 = {source.width/source.height,1.0}

    distance_Static : c.float

    //This is just to know where the code is going to be placed in Main Odin for the health
    for !rl.WindowShouldClose(){
        distance_Static = rl.Vector3Distance(camera.position,bill_Position_Static)

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.DrawBillboard(camera,bill_board,bill_Position_Static,2.0,rl.WHITE)

        rl.EndMode3D()
        rl.EndDrawing()
    }

    rl.UnloadTexture(bill_board)
    rl.CloseWindow()

}