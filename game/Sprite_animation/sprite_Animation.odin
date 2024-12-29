package Sprite_animation

import rl "vendor:raylib"
import "core:c"
import "core:fmt"

MAX_FRAME_SPEED :: 15
MIN_FRAME_SPEED :: 1

main :: proc() {
    WINDOW_SIZE :: 1440
    rl.InitWindow(WINDOW_SIZE,WINDOW_SIZE,"Sprite Animation")

    sword_sprite : rl.Texture2D = rl.LoadTexture("../../resources/Art_Asset_Odin.png")
    position : rl.Vector2 = {350.0,280.0}
    frame_Rect : rl.Rectangle = {0.0,0.0,cast(c.float)sword_sprite.width/4, cast(c.float)sword_sprite.height}
    current_Frame : c.int = 0

    frame_Counter : c.int = 0
    frame_Speed : c.int = 8


    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose(){
        frame_Counter += 1

        if frame_Counter >= 60/frame_Speed {
            frame_Counter = 0
            current_Frame += 1
            if current_Frame > 3{
                current_Frame = 0
            }
            frame_Rect.x = cast(c.float)current_Frame*cast(c.float)sword_sprite.width/4
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        rl.DrawTextureRec(sword_sprite,frame_Rect,position,rl.WHITE)
        rl.EndDrawing()
    }
    rl.UnloadTexture(sword_sprite)
    rl.CloseWindow()

}