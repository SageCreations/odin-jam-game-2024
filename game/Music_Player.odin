package game

import rl "vendor:raylib"
import "core:fmt"
import "core:c"

WINDOW_SIZE :: 800

typedef: struct{
speed: f32
}

main:: proc(){
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_SIZE,WINDOW_SIZE,"AUDIO_TEST")
    rl.InitAudioDevice()

    music : rl.Music = rl.LoadMusicStream("../resources/Car_Game_Music.mp3")
    pitch : c.float = 1.0
    rl.PlayMusicStream(music)

    timePlayed : c.float = 0.0
    pause : bool = false

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose(){
        rl.UpdateMusicStream(music)

        if rl.IsKeyPressed(.SPACE){
            rl.StopMusicStream(music)
            rl.PlayMusicStream(music)
            pause = false
            }
        if rl.IsKeyPressed(.P){
            pause = !pause
            if pause{
                rl.PauseMusicStream(music)
            }
            else{
                rl.ResumeMusicStream(music)
            }
        }
        if rl.IsKeyDown(.DOWN){
            pitch -= 0.01
        }
        else if rl.IsKeyDown(.UP){
            pitch += 0.01
        }
        rl.SetMusicPitch(music,pitch)

        timePlayed = rl.GetMusicTimePlayed(music)/rl.GetMusicTimeLength(music)*(WINDOW_SIZE - 40)

        rl.BeginDrawing()

        rl.ClearBackground(rl.RAYWHITE)
        rl.DrawRectangle(20,WINDOW_SIZE - 20 - 12,WINDOW_SIZE - 40, 12, rl.LIGHTGRAY)
        rl.DrawRectangle(20,WINDOW_SIZE - 20 - 12,cast(c.int)timePlayed,12, rl.MAROON)
        rl.DrawRectangle(20,WINDOW_SIZE - 20 - 12,WINDOW_SIZE - 40, 12, rl.GRAY)

       rl.DrawRectangle(20,20,425,145,rl.WHITE)
       rl.DrawRectangleLines(20,20,425,145,rl.GRAY)
        rl.DrawText("Press Space to restart Music", 40,40,20,rl.BLACK)
        rl.DrawText("Press P to pause/resume Music", 40,70,20,rl.BLACK)
        rl.DrawText("Press Up/Down to change Speed of Music", 40,100,20,rl.BLACK)
        rl.DrawText(rl.TextFormat("Speed: %f", pitch),40,130,20,rl.MAROON)

        rl.EndDrawing()
    }
    rl.UnloadMusicStream(music)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}