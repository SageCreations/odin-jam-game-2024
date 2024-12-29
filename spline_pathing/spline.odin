package spline_pathing

import rl "vendor:raylib"
import "core:c"


MAX_SPLINE_POINTS: i32 : 32

ControlPoint :: struct {
    start: rl.Vector2,
    end:   rl.Vector2,
}




create_path_data :: proc() -> [dynamic]rl.Vector2 {
    points: [dynamic]rl.Vector2 = {}
    append(&points, rl.Vector2{ 50.0, 400.0 })
    append(&points, rl.Vector2{ 160.0, 220.0 })
    append(&points, rl.Vector2{ 340.0, 380.0 })
    append(&points, rl.Vector2{ 520.0, 60.0 })
    append(&points, rl.Vector2{ 710.0, 260.0 })
    return points
}

PlayerPathing :: struct {
    points: [dynamic]rl.Vector2,
    control: [dynamic]ControlPoint,


}

get_control_points :: proc(points: [dynamic]rl.Vector2) -> [dynamic]ControlPoint {
    control: [dynamic]ControlPoint = {}
    for i := 0; i < len(points)-1; i+=1 {
        control[i].start = rl.Vector2{ points[i].x + 50, points[i].y }
        control[i].end = rl.Vector2{ points[i + 1].x - 50, points[i + 1].y }
    }
    return control
}







//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
    // Initialization
    //--------------------------------------------------------------------------------------
    screenWidth :: 800
    screenHeight :: 450

    rl.SetConfigFlags({rl.ConfigFlag.MSAA_4X_HINT})
    rl.InitWindow(screenWidth, screenHeight, "raylib [shapes] example - splines drawing")

    points: [dynamic]rl.Vector2 = {}
    append(&points, rl.Vector2{ 50.0, 400.0 })
    append(&points, rl.Vector2{ 160.0, 220.0 })
    append(&points, rl.Vector2{ 340.0, 380.0 })
    append(&points, rl.Vector2{ 520.0, 60.0 })
    append(&points, rl.Vector2{ 710.0, 260.0 })


    pointCount: c.int = 5
    selectedPoint: c.int = -1
    focusedPoint: c.int = -1

    control: [MAX_SPLINE_POINTS-1]ControlPoint = {}
    for i: c.int = 0; i < pointCount - 1; i+=1
    {
        control[i].start = rl.Vector2{ points[i].x + 50, points[i].y }
        control[i].end = rl.Vector2{ points[i + 1].x - 50, points[i + 1].y }
    }


    // Spline config variables
    splineThickness: c.float = 8.0
    splineTypeEditMode: c.bool = false
    splineHelpersActive: c.bool = true

    rl.SetTargetFPS(60)              // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    for !rl.WindowShouldClose()  {   // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // Spline points creation logic (at the end of spline)
        if rl.IsMouseButtonPressed(.RIGHT) && (pointCount < MAX_SPLINE_POINTS) {
            append(&points, rl.GetMousePosition())
            i: c.int = pointCount - 1
            control[i].start = rl.Vector2{ points[i].x + 50, points[i].y }
            control[i].end = rl.Vector2{ points[i + 1].x - 50, points[i + 1].y }
            pointCount+=1
        }

        // Spline point focus and selection logic
        for i :c.int= 0; i < pointCount; i += 1 {
            if rl.CheckCollisionPointCircle(rl.GetMousePosition(), points[i], 8.0)
            {
                focusedPoint = i
                if rl.IsMouseButtonDown(.LEFT) {
                    selectedPoint = i
                }
                break
            } else {
                focusedPoint = -1
            }
        }

        // Spline point movement logic
        if selectedPoint >= 0 {
            points[selectedPoint] = rl.GetMousePosition()
            if rl.IsMouseButtonReleased(.LEFT) {
                selectedPoint = -1
            }
        }


        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()

        rl.ClearBackground(rl.RAYWHITE)


        // Draw spline: linear
        rl.DrawSplineLinear(raw_data(points), pointCount, splineThickness, rl.RED)

        if splineHelpersActive == true {
            // Draw spline point helpers
            for i: c.int = 0; i < pointCount; i+=1 {
                rl.DrawCircleLinesV(points[i], (focusedPoint == i)? 12.0 : 8.0, (focusedPoint == i)? rl.BLUE: rl.DARKBLUE)
                rl.DrawText(rl.TextFormat("[%.0f, %.0f]", points[i].x, points[i].y), cast(c.int)points[i].x, cast(c.int)points[i].y + 10, 10, rl.BLACK)
            }
        }


        // Check all possible UI states that require controls lock
        if splineTypeEditMode == true {
            rl.GuiLock()
        }

        // Draw spline config
        rl.GuiLabel(rl.Rectangle{ 12, 62, 140, 24 }, rl.TextFormat("Spline thickness: %i", cast(c.int)splineThickness))
        rl.GuiSliderBar(rl.Rectangle{ 12, 60 + 24, 140, 16 }, nil, nil, &splineThickness, 1.0, 40.0)

        rl.GuiCheckBox(rl.Rectangle{ 12, 110, 20, 20 }, "Show point helpers", &splineHelpersActive)

        rl.GuiUnlock()


        rl.EndDrawing()
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.CloseWindow()        // Close window and OpenGL context
    //--------------------------------------------------------------------------------------


}
