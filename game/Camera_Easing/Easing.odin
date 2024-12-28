package Basic_Lighting

import rl "vendor:raylib"
import "core:odin/format"
import "core:c"

////------------------------------------------------------------------------------------
//// Program main entry point
////------------------------------------------------------------------------------------
//int main(void)
//{
//// Initialization
////--------------------------------------------------------------------------------------

main:: proc() {
    WINDOW_SIZE :: 1000
    rl.InitWindow(WINDOW_SIZE,WINDOW_SIZE,"Ease_Out")

    rect : rl.Rectangle = {cast(c.float)rl.GetScreenWidth()/2.0,-100,100,100}
    rotation : c.float = 0.0
    alpha : c.float = 1.0

    state : c.int = 0

    frame_Counter : c.int = 0

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose(){
        switch i {
        case 0:
            frame_Counter += 1
            rect.height = rl.EaseBounceOut(cast(c.float)frame_Counter,100,-90,120)
            rect.width = rl.EaseBounceOut(cast(c.float)frame_Counter,cast(c.float)rl.GetScreenWidth(),120)
            if frame_Counter >= 120{
                frame_Counter = 0
                state = 1
                }
        break
        case 1:
        }
        }
    }

//switch (state)
//{
//case 0:     // Move box down to center of screen
//{
//framesCounter++;
//
//// NOTE: Remember that 3rd parameter of easing function refers to
//// desired value variation, do not confuse it with expected final value!
//rec.y = EaseElasticOut((float)framesCounter, -100, GetScreenHeight()/2.0f + 100, 120);
//
//if (framesCounter >= 120)
//{
//framesCounter = 0;
//state = 1;
//}
//} break;
//case 1:     // Scale box to an horizontal bar
//{
//framesCounter++;
//rec.height = EaseBounceOut((float)framesCounter, 100, -90, 120);
//rec.width = EaseBounceOut((float)framesCounter, 100, (float)GetScreenWidth(), 120);
//
//if (framesCounter >= 120)
//{
//framesCounter = 0;
//state = 2;
//}
//} break;
//case 2:     // Rotate horizontal bar rectangle
//{
//framesCounter++;
//rotation = EaseQuadOut((float)framesCounter, 0.0f, 270.0f, 240);
//
//if (framesCounter >= 240)
//{
//framesCounter = 0;
//state = 3;
//}
//} break;
//case 3:     // Increase bar size to fill all screen
//{
//framesCounter++;
//rec.height = EaseCircOut((float)framesCounter, 10, (float)GetScreenWidth(), 120);
//
//if (framesCounter >= 120)
//{
//framesCounter = 0;
//state = 4;
//}
//} break;
//case 4:     // Fade out animation
//{
//framesCounter++;
//alpha = EaseSineOut((float)framesCounter, 1.0f, -1.0f, 160);
//
//if (framesCounter >= 160)
//{
//framesCounter = 0;
//state = 5;
//}
//} break;
//default: break;
//}
//
//// Reset animation at any moment
//if (IsKeyPressed(KEY_SPACE))
//{
//rec = (Rectangle){ GetScreenWidth()/2.0f, -100, 100, 100 };
//rotation = 0.0f;
//alpha = 1.0f;
//state = 0;
//framesCounter = 0;
//}
////----------------------------------------------------------------------------------
//
//// Draw
////----------------------------------------------------------------------------------
//BeginDrawing();
//
//ClearBackground(RAYWHITE);
//
//DrawRectanglePro(rec, (Vector2){ rec.width/2, rec.height/2 }, rotation, Fade(BLACK, alpha));
//
//DrawText("PRESS [SPACE] TO RESET BOX ANIMATION!", 10, GetScreenHeight() - 25, 20, LIGHTGRAY);
//
//EndDrawing();
////----------------------------------------------------------------------------------
//}
//
//// De-Initialization
////--------------------------------------------------------------------------------------
//CloseWindow();        // Close window and OpenGL context
////--------------------------------------------------------------------------------------
//
//return 0;
//}