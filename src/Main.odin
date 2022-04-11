package main

import "core:c"
import "core:os"
import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"

import SDL "vendor:sdl2"

Block :: struct {
	position:      glsl.vec2,
	color:         glsl.ivec4,
	width, height: f32,
}

Player :: struct {
	position:      glsl.vec2,
	velocity:      glsl.vec2,
	acceleration:  glsl.vec2,
	width, height: f32,
}

main :: proc() {
	SDL_CheckCode(SDL.Init(SDL.INIT_EVERYTHING))
	defer SDL.Quit()

	window := SDL_CheckPointer(
		SDL.CreateWindow(
			"Time Travel",
			SDL.WINDOWPOS_UNDEFINED,
			SDL.WINDOWPOS_UNDEFINED,
			640,
			480,
			SDL.WINDOW_SHOWN,
		),
	)
	defer SDL.DestroyWindow(window)

	renderer := SDL_CheckPointer(SDL.CreateRenderer(window, -1, SDL.RENDERER_ACCELERATED))
	defer SDL.DestroyRenderer(renderer)

	blocks: [dynamic]Block
	append(
		&blocks,
		Block{position = {320, 400}, color = {0, 255, 255, 0}, width = 600, height = 20},
	)
	append(
		&blocks,
		Block{position = {450, 365}, color = {0, 255, 255, 0}, width = 60, height = 50},
	)
	append(
		&blocks,
		Block{position = {450, 250}, color = {0, 255, 255, 0}, width = 60, height = 50},
	)

	player := Player {
		position = {100, 100},
		width = 40,
		height = 100,
	}

	left, right, jump: bool

	last_time := SDL.GetPerformanceCounter()
	fixed_time_counter: f32
	main_loop: for {
		time := SDL.GetPerformanceCounter()
		dt := f32(time - last_time) / f32(SDL.GetPerformanceFrequency())
		last_time = time

		for event: SDL.Event; SDL.PollEvent(&event) != 0; {
			#partial switch event.type {
			case .QUIT:
				break main_loop
			case .KEYDOWN, .KEYUP:
				if event.key.keysym.sym == .A {
					left = event.key.state != 0
				}
				if event.key.keysym.sym == .D {
					right = event.key.state != 0
				}
				if event.key.keysym.sym == .SPACE {
					jump = event.key.state != 0
				}
				if event.key.keysym.sym == .LSHIFT {
					if event.key.state != 0 && player.height == 100 {
						player.height = 50
						player.position.y += 25
					} else {
						player.height = 100
						player.position.y -= 25
					}
				}
				if event.key.keysym.sym == .R && event.key.state != 0 {
					player.position = {100, 100}
					player.velocity = 0
					player.acceleration = 0
				}
			}
		}

		FIXED_TIME :: 1.0 / 60.0
		fixed_time_counter += dt
		for fixed_time_counter >= FIXED_TIME {
			dt :: FIXED_TIME

			defer fixed_time_counter -= FIXED_TIME

			{
				defer {
					player.velocity += player.acceleration
					player.position += player.velocity * dt
					player.acceleration = 0
				}

				player.acceleration.y += 15.0

				touching_ground := false
				for block in blocks {
					if block.position.x - block.width * 0.5 < player.position.x + player.width * 0.5 && block.position.x +
					   block.width * 0.5 > player.position.x - player.width * 0.5 && block.position.y - block.height *
					   0.5 < player.position.y + player.height * 0.5 && block.position.y + block.height *
					   0.5 > player.position.y - player.height * 0.5 {
						rel_pos := player.position - block.position
						rel_pos /= {player.width + block.width, player.height + block.height}
						x_dist, y_dist: f32
						if abs(rel_pos.x) > abs(rel_pos.y) {
							player.position.x = block.position.x + (block.width * 0.5 + player.width * 0.5) * math.sign(
	                          rel_pos.x,
                          )
							player.velocity.x = 0
						} else {
							player.position.y = block.position.y + (block.height * 0.5 + player.height * 0.5) *
                          math.sign(rel_pos.y)
							player.acceleration.x -= min(
	                               abs(player.velocity.x),
	                               10 + abs(player.velocity.x) * 0.05,
                               ) * math.sign(player.velocity.x)
							player.velocity.y = 0
							if rel_pos.y < 0 {
								touching_ground = true
							}
						}
					}
				}

				PLAYER_SPEED :: 15.0
				PLAYER_SPEED_AIR :: 2.0
				if left {
					player.acceleration.x -= PLAYER_SPEED if touching_ground else PLAYER_SPEED_AIR
				}
				if right {
					player.acceleration.x += PLAYER_SPEED if touching_ground else PLAYER_SPEED_AIR
				}

				if jump {
					if touching_ground {
						player.acceleration.y -= 310.0 if player.height == 100 else 620.0
					}
				}
			}
		}

		Render(renderer, blocks[:], player)
	}
}

Render :: proc(renderer: ^SDL.Renderer, blocks: []Block, player: Player) {
	SDL_CheckCode(SDL.SetRenderDrawColor(renderer, 51, 51, 51, 255))
	SDL_CheckCode(SDL.RenderClear(renderer))

	for block in blocks {
		SDL_CheckCode(
			SDL.SetRenderDrawColor(
				renderer,
				u8(block.color.r),
				u8(block.color.g),
				u8(block.color.b),
				u8(block.color.a),
			),
		)
		SDL_CheckCode(
			SDL.RenderDrawRectF(
				renderer,
				&SDL.FRect{
					x = block.position.x - block.width * 0.5,
					y = block.position.y - block.height * 0.5,
					w = block.width,
					h = block.height,
				},
			),
		)
	}

	SDL_CheckCode(SDL.SetRenderDrawColor(renderer, 255, 0, 0, 255))
	SDL_CheckCode(
		SDL.RenderDrawRectF(
			renderer,
			&SDL.FRect{
				x = player.position.x - player.width * 0.5,
				y = player.position.y - player.height * 0.5,
				w = player.width,
				h = player.height,
			},
		),
	)

	SDL.RenderPresent(renderer)
}

SDL_CheckPointer :: proc(ptr: ^$T) -> ^T {
	if ptr == nil {
		fmt.eprintf("SDL Error: %s\n", SDL.GetError())
		os.exit(1)
	}
	return ptr
}

SDL_CheckCode :: proc(code: c.int) -> c.int {
	if code < 0 {
		fmt.eprintf("SDL Error: %s\n", SDL.GetError())
		os.exit(1)
	}
	return code
}
