package arcanoid

import "base:intrinsics"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

window_width :: 1280
window_height :: 1280
screen_size :: 320

Coords :: [2]f32
Vector :: [2]f32

// different rotation for different wall?
Ball_hits :: enum {}

Ball :: struct {
    center: Coords,
    r:      f32,
    dir:    Vector,
    color:  rl.Color,
    speed:  f32,
}

Paddle :: struct {
    rect:     rl.Rectangle,
    velocity: f32,
    color:    rl.Color,
    speed:    f32,
}

paddle := Paddle {
    rect = rl.Rectangle{y = 260, width = 50, height = 6},
    color = {50, 150, 90, 255},
    speed = 200,
}

ball := Ball {
    r     = 4,
    color = {255, 80, 80, 255},
    speed = 260,
}

started: bool

// bounce_ball :: proc(ball_direction: Vector) {
//     if ball_direction.x < 0 {
//         linalg.dot()
//     }
// }

// get_coords :: proc()

sign :: proc(x: $T) -> f32 where intrinsics.type_is_float(T) {
    if x < 0 {
        return -1
    } else if x > 0 {
        return 1
    }
    return 0
}


ball_hit :: proc() {

}

reflect :: proc(vector: Vector, normal: Vector) -> Vector {
    return vector - 2 * linalg.dot(vector, normal) * normal
}


rect_center :: proc(rect: rl.Rectangle) -> Coords {
    return {rect.x + rect.width / 2, rect.y + rect.height / 2}
}

restart :: proc() {
    paddle.rect.x = (screen_size - paddle.rect.width) / 2
    ball.center = {screen_size / 2, 160}
    started = false
}

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(window_width, window_height, "s")
    rl.SetTargetFPS(240)

    game_over: bool

    restart()
    for !rl.WindowShouldClose() {
        if rl.IsKeyPressed(.UP) do restart()
        paddle.velocity = 0
        dt: f32

        if !started {
            ball.center = {screen_size / 2 * (1 + 0.9 * f32(math.cos(rl.GetTime()))), 160}

            if rl.IsKeyPressed(.SPACE) {
                paddle_mid := [2]f32{paddle.rect.x + paddle.rect.width / 2, paddle.rect.y}
                ball.dir = linalg.normalize0(paddle_mid - ball.center)
                started = true
            }
        } else {
            dt = rl.GetFrameTime()
        }


        if rl.IsKeyDown(.LEFT) {
            paddle.velocity -= paddle.speed
        }

        if rl.IsKeyDown(.RIGHT) {
            paddle.velocity += paddle.speed
        }

        paddle.rect.x += paddle.velocity * dt
        paddle.rect.x = clamp(paddle.rect.x, 0, screen_size - paddle.rect.width)

        camera := rl.Camera2D {
            zoom = f32(rl.GetScreenHeight() / screen_size),
        }

        previous_ball_center := ball.center
        ball.center += ball.dir * ball.speed * dt

        if rl.CheckCollisionCircleRec(ball.center, ball.r, paddle.rect) ||
            ball.center.x > screen_size ||
            ball.center.x < 0 ||
            ball.center.y < 0 {
            normal: Vector
            switch {
                case rl.CheckCollisionCircleRec(ball.center, ball.r, paddle.rect): normal = {0, -1}
                case ball.center.x + ball.r > screen_size: normal = {-1, 0}
                case ball.center.x - ball.r < 0: normal = {1, 0}
                case ball.center.y - ball.r < 0: normal = {0, 1}
            }
            ball.center = previous_ball_center
            ball.dir = reflect(ball.dir, normal)
        }

        rl.BeginDrawing()
        rl.ClearBackground({150, 190, 220, 255})


        rl.BeginMode2D(camera)

        rl.DrawRectangleRec(paddle.rect, paddle.color)
        rl.DrawCircleV(ball.center, ball.r, ball.color)
        rl.EndDrawing()

    }


    rl.CloseWindow()
}
