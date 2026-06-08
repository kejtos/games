package snake


import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

extra_rows :: 2

window_width :: 1000
window_height :: 1000
cell_size :: 16

grid_width :: 20
grid_height :: grid_width - (extra_rows * 2)

canvas_width :: grid_width * cell_size
canvas_height :: grid_height * cell_size

zoom :: f32(window_height) / canvas_width

background_color: rl.Color : {67, 15, 77, 255}
top_menu_color: rl.Color : {0, 167, 255, 255}
bot_menu_color: rl.Color : {0, 167, 255, 255}
score_color_init: rl.Color : {56, 58, 89, 255}

max_snake_length :: grid_width * grid_height
initial_snake_length :: 3
shake_intensity :: 8
game_over_font_size :: 25
press_enter_font_size :: 10
fps_choices :: "60;120;144;240"
difficulty_choices :: "EASIEST;EASY;MEDIUM;HARD;HARDEST"
fps_str :: "FPS"
volume_str :: "VOLUME"
difficulty_str :: "DIFFICULTY"
game_over_str :: "Game over!"
start_str :: "Hello gamer!"
press_to_start_str :: "Press an arrow to start"
press_to_restart_str :: "Press an arrow to restart"
init_fps :: 60
margin :: 22
x_gap :: 40
y_gap :: x_gap / 8
regular_fontsize :: 20

Vec2i :: [2]int

colors :: [Screen_parts]rl.Color {
    .top_menu = top_menu_color,
    .bot_menu = bot_menu_color,
    .main_map = background_color,
}

Movement :: enum {
    left,
    right,
    up,
    down,
}

move :: [Movement]Vec2i {
    .left  = {-1, 0},
    .right = {1, 0},
    .up    = {0, -1},
    .down  = {0, 1},
}

move_direction_queue: queue.Queue(Vec2i)
snake_length: int

move_direction: Vec2i
game_over: bool
food: Vec2i
high_score: int
score_color := score_color_init
camera_offset: [2]f32
shake_timer: f32
shake_interval: f32
current_shake: [2]f32
offset_final: [2]f32
pop_later: bool
slider_value: f32 = 50
fps_values := [4]i32{60, 120, 144, 240}

UI_element :: enum {
    fps,
    volume,
    difficulty,
}

Sprite_Type :: enum {
    food,
    head,
    body,
    tail,
}

sprites: [Sprite_Type]rl.Texture2D

fps_dropdown_box :: rl.Rectangle{window_width - margin - 80, f32(margin + regular_fontsize + y_gap), 80, 30}
volume_slider_box :: rl.Rectangle{window_width / 2 - 100, f32(margin + regular_fontsize + y_gap), 200, 30}
difficulty_slider_box :: rl.Rectangle{margin, f32(margin + regular_fontsize + y_gap), 200, 30}

top_menu :: rl.Rectangle{0, 0, window_width, (window_width / grid_width) * extra_rows}
game_map :: rl.Rectangle{0, extra_rows * cell_size, canvas_width, canvas_height}
bot_menu :: rl.Rectangle{0, game_map.y + game_map.height, canvas_width, extra_rows * cell_size}

Screen_parts :: enum {
    top_menu,
    bot_menu,
    main_map,
}

screen :: [Screen_parts]rl.Rectangle {
    .top_menu = top_menu,
    .bot_menu = bot_menu,
    .main_map = game_map,
}

boxes :: [UI_element]rl.Rectangle {
    .fps        = fps_dropdown_box,
    .volume     = volume_slider_box,
    .difficulty = difficulty_slider_box,
}


head_hit_border :: proc(head_pos: Vec2i, game_map: rl.Rectangle) -> (it_is_in_map: bool) {
    x := head_pos.x
    y := head_pos.y
    it_is_in_map = x < 0 || x >= grid_width || y < extra_rows || y >= grid_width - extra_rows
    return
}


place_food :: proc(snake: [max_snake_length]Vec2i, snake_length: int) -> Vec2i {
    occupied: [grid_width][grid_height]bool

    for i in 0 ..< snake_length {
        occupied[snake[i].x][snake[i].y] = true
    }

    free_cells := make([dynamic]Vec2i, context.temp_allocator)

    for x in 0 ..< grid_width {
        for y in extra_rows ..< grid_height - extra_rows {
            if !occupied[x][y] {
                append(&free_cells, Vec2i{x, y})
            }
        }
    }

    if len(free_cells) > 0 {
        random_cell_index := rl.GetRandomValue(0, i32(len(free_cells) - 1))
        food = free_cells[random_cell_index]
    }

    return food
}


set_initial_state :: proc(
) -> (
    snake: [max_snake_length]Vec2i,
    snake_length: int,
    move_direction: Vec2i,
    food: Vec2i,
    game_over: bool,
) {
    start_head_pos := Vec2i{grid_width / 2, grid_height / 2}
    snake[0] = start_head_pos
    snake[1] = start_head_pos + {0, 1}
    snake[2] = start_head_pos + {0, 2}
    move_direction = {0, 0}
    snake_length = initial_snake_length
    food = place_food(snake, snake_length)
    // current_shake = {0, 0}
    game_over = false

    return
}


queue_up_arrow_key_press :: proc(q: ^queue.Queue(Vec2i)) {
    if queue.len(q^) < 3 {
        last_dir := queue.back(q)

        if rl.IsKeyPressed(.UP) && last_dir != move[.down] && last_dir != move[.up] {
            queue.append(q, move[.up])
        } else if rl.IsKeyPressed(.DOWN) && last_dir != move[.up] && last_dir != move[.down] && last_dir != {0, 0} {
            queue.append(q, move[.down])
        }

        if rl.IsKeyPressed(.LEFT) && last_dir != move[.right] && last_dir != move[.left] {
            queue.append(q, move[.left])
        } else if rl.IsKeyPressed(.RIGHT) && last_dir != move[.left] && last_dir != move[.right] {
            queue.append(q, move[.right])
        }

        if pop_later && queue.len(move_direction_queue) > 1 {
            queue.consume_front(q, 1)
            pop_later = false
        }
    }
}


draw_start_screen :: proc() {
    str := strings.clone_to_cstring(start_str)
    rl.DrawText(
        str,
        (canvas_width - rl.MeasureText(str, game_over_font_size)) / 2,
        (canvas_width - game_over_font_size) / 2,
        game_over_font_size,
        rl.RED,
    )

    str = strings.clone_to_cstring(press_to_start_str)
    rl.DrawText(
        str,
        (canvas_width - rl.MeasureText(str, press_enter_font_size)) / 2,
        (canvas_width - press_enter_font_size) / 2 + game_over_font_size / 2 + 10,
        press_enter_font_size,
        rl.BLACK,
    )
}


draw_game_ending_screen :: proc() {
    str := strings.clone_to_cstring(game_over_str)
    rl.DrawText(
        str,
        (canvas_width - rl.MeasureText(str, game_over_font_size)) / 2,
        (canvas_width - game_over_font_size) / 2,
        game_over_font_size,
        rl.RED,
    )

    str = strings.clone_to_cstring(press_to_restart_str)
    rl.DrawText(
        str,
        (canvas_width - rl.MeasureText(str, press_enter_font_size)) / 2,
        (canvas_width - press_enter_font_size) / 2 + game_over_font_size / 2 + 10,
        press_enter_font_size,
        rl.BLACK,
    )
}


draw_high_score :: proc(snake_length: int) {
    score_counter := snake_length - 3
    score_str := fmt.ctprintf("Score: %v", score_counter)

    if score_counter >= high_score {
        high_score = score_counter
        score_color = rl.GOLD
    } else {
        score_color = score_color_init
    }

    high_score_str := fmt.ctprintf("Best score: %v", high_score)

    rl.DrawText(high_score_str, 6, canvas_width - 13, 10, rl.GOLD)
    rl.DrawText(score_str, 6, canvas_width - 28, 10, score_color)
}

draw_stopwatch :: proc(elapsed_time: f32) {
    secs := i32(elapsed_time)
    timer_str := fmt.ctprintf("%02d:%02d", secs / 60, secs % 60)
    fps_text_width := rl.MeasureText(timer_str, regular_fontsize)
    rl.DrawText(
        timer_str,
        canvas_width - 10 - fps_text_width,
        canvas_width - regular_fontsize - 5,
        regular_fontsize,
        rl.GOLD,
    )
}


main :: proc() {
    // rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(window_width, window_height, "Snake")
    rl.SetTargetFPS(init_fps)
    rl.InitAudioDevice()

    snake, snake_length, move_direction, food, game_over := set_initial_state()

    queue.init(&move_direction_queue, capacity = 3)
    queue.append(&move_direction_queue, move_direction)
    defer queue.destroy(&move_direction_queue)

    sprites[.food] = rl.LoadTexture("food.png")
    sprites[.head] = rl.LoadTexture("head.png")
    sprites[.body] = rl.LoadTexture("body.png")
    sprites[.tail] = rl.LoadTexture("tail.png")

    eat_sound := rl.LoadSound("eat.wav")
    crash_sound := rl.LoadSound("crash.wav")

    music := rl.LoadMusicStream("music.mp3")

    rl.PlayMusicStream(music)

    elapsed_time: f32
    set_fps: i32
    set_volume: f32 = 50
    set_difficulty: i32 = 1
    dropdown_active: bool
    dropdown_active2: bool
    tick_timers := [5]f32{0.16, 0.13, 0.10, 0.07, 0.04}
    tick_rate: f32 = tick_timers[i32(set_difficulty)]
    tick_timer: f32 = tick_rate
    fps_text_width := rl.MeasureText(fps_str, regular_fontsize)
    volume_text_width := rl.MeasureText(volume_str, regular_fontsize)
    difficulty_text_width := rl.MeasureText(difficulty_str, regular_fontsize)
    snake_is_moving := true
    start_menu := true
    pressed_key: rl.KeyboardKey

    for rl.GetKeyPressed() != .KEY_NULL {}
    for !rl.WindowShouldClose() {
        queue_up_arrow_key_press(&move_direction_queue)

        pressed_key = rl.GetKeyPressed()
        if game_over || start_menu {
            if slice.contains([]rl.KeyboardKey{.UP, .DOWN, .LEFT, .RIGHT}, pressed_key) {
                snake, snake_length, move_direction, food, game_over = set_initial_state()
                snake_is_moving = true
                queue.clear(&move_direction_queue)
                queue.append(&move_direction_queue, move_direction)
                tick_timer = 0
                elapsed_time = 0

                if start_menu {
                    start_menu = false
                }
            }
        } else {
            tick_timer -= rl.GetFrameTime()
            elapsed_time += rl.GetFrameTime()
        }

        tick_loop: if tick_timer <= 0 {
            switch queue.len(move_direction_queue) {
                case 2 ..= 3:
                    move_direction = queue.pop_front(&move_direction_queue)
                case 1:
                    move_direction = queue.front(&move_direction_queue)
                    pop_later = true
            }

            next_part_pos := snake[0]
            snake[0] += move_direction
            head_pos := snake[0]

            if head_hit_border(head_pos, game_map) & snake_is_moving {
                game_over = true
                snake_is_moving = false
                shake_timer = 0.3
                snake[0] -= move_direction
                head_pos := snake[0]
                rl.PlaySound(crash_sound)

                break tick_loop
            } else if head_hit_border(head_pos, game_map) & ~snake_is_moving {
                snake[0] -= move_direction
                head_pos := snake[0]

                break tick_loop
            }

            if queue.front(&move_direction_queue) != {0, 0} {
                for i in 1 ..< snake_length {
                    cur_pos := snake[i]
                    if head_pos == cur_pos {
                        game_over = true
                        shake_timer = 0.3
                        rl.PlaySound(crash_sound)
                    }
                    snake[i] = next_part_pos
                    next_part_pos = cur_pos
                }
            }

            if snake[0].x == food.x && snake[0].y == food.y {
                snake[snake_length] = next_part_pos
                snake_length += 1
                food = place_food(snake, snake_length)
                rl.PlaySound(eat_sound)
            }
            tick_timer += tick_rate
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.DrawRectangleRec(screen[.top_menu], colors[.top_menu])
        rl.DrawRectangleLinesEx(screen[.top_menu], zoom, rl.BLUE)

        if shake_timer > 0 {
            shake_timer -= rl.GetFrameTime()
            shake_interval -= rl.GetFrameTime()

            if shake_interval <= 0 {
                current_shake.x = f32(rl.GetRandomValue(-shake_intensity, shake_intensity))
                current_shake.y = f32(rl.GetRandomValue(-shake_intensity, shake_intensity))
                shake_interval = 0.05
            }

        } else {
            current_shake = {0, 0}
        }

        camera_offset = current_shake
        camera := rl.Camera2D {
            offset = camera_offset,
            zoom   = f32(window_height) / canvas_width,
        }


        tick_rate = tick_timers[i32(set_difficulty)]
        rl.SetMusicVolume(music, set_volume / 100 + 0.02 if set_volume > 0 else 0)
        rl.SetSoundVolume(eat_sound, set_volume / 100)
        rl.SetSoundVolume(crash_sound, set_volume / 100)

        rl.DrawText(
            text = fps_str,
            posX = i32(boxes[.fps].x + f32(boxes[.fps].width / 2) - f32(fps_text_width / 2)),
            posY = margin,
            fontSize = regular_fontsize,
            color = rl.BLACK,
        )

        rl.DrawText(
            text = volume_str,
            posX = i32(boxes[.volume].x + f32(boxes[.volume].width / 2) - f32(volume_text_width / 2)),
            posY = margin,
            fontSize = regular_fontsize,
            color = rl.BLACK,
        )

        rl.DrawText(
            text = difficulty_str,
            posX = i32(boxes[.difficulty].x + f32(boxes[.difficulty].width / 2) - f32(difficulty_text_width / 2)),
            posY = margin,
            fontSize = regular_fontsize,
            color = rl.BLACK,
        )

        rl.BeginMode2D(camera)
        rl.DrawRectangleRec(screen[.bot_menu], colors[.bot_menu])
        rl.DrawRectangleRec(screen[.main_map], colors[.main_map])
        rl.DrawRectangleLinesEx(screen[.main_map], 1, rl.BLUE)
        rl.DrawRectangleLinesEx(screen[.bot_menu], 1, rl.BLUE)

        source: rl.Rectangle
        dest: rl.Rectangle
        sprite: rl.Texture2D
        dir: Vec2i

        if start_menu {
            draw_start_screen()
        } else {
            rl.DrawTextureV(sprites[.food], {f32(food.x), f32(food.y)} * cell_size, rl.WHITE)
            for body_part in 0 ..< snake_length {

                switch body_part {
                    case 0:
                        sprite = sprites[.head]
                        dir = snake[body_part] - snake[body_part + 1]
                    case snake_length - 1:
                        sprite = sprites[.tail]
                        dir = snake[body_part - 1] - snake[body_part]
                    case:
                        sprite = sprites[.body]
                        dir = snake[body_part - 1] - snake[body_part]
                }

                rot := math.atan2(f32(dir.y), f32(dir.x)) * math.DEG_PER_RAD

                if (body_part == 0 || body_part == snake_length - 1) && (dir.y == 0) && (dir.x == -1) {
                    source = rl.Rectangle{0, 0, f32(sprite.width), -f32(sprite.height)}
                } else {
                    source = rl.Rectangle{0, 0, f32(sprite.width), f32(sprite.height)}
                }

                dest = {
                    (f32(snake[body_part].x) + 0.5) * cell_size,
                    (f32(snake[body_part].y) + 0.5) * cell_size,
                    cell_size,
                    cell_size,
                }

                rl.DrawTexturePro(sprite, source, dest, {cell_size, cell_size} * 0.5, rot, rl.WHITE)
            }
        }

        if game_over do draw_game_ending_screen()

        draw_high_score(snake_length)
        draw_stopwatch(elapsed_time)

        rl.EndMode2D()

        if rl.GuiDropdownBox(fps_dropdown_box, fps_choices, &set_fps, dropdown_active) {
            dropdown_active = !dropdown_active
        }
        rl.SetTargetFPS(fps_values[set_fps])

        rl.GuiSlider(volume_slider_box, "0", "100", &set_volume, minValue = 0, maxValue = 100)

        if rl.GuiDropdownBox(difficulty_slider_box, difficulty_choices, &set_difficulty, dropdown_active2) {
            dropdown_active2 = !dropdown_active2
        }
        rl.EndDrawing()
        rl.UpdateMusicStream(music)

        free_all(context.temp_allocator)
    }

    for sprite in sprites {
        rl.UnloadTexture(sprite)
    }

    rl.StopMusicStream(music)
    rl.UnloadMusicStream(music)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}
