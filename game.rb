require 'gosu'
require_relative 'defstruct'
require_relative 'vector'
require_relative 'timer'
require_relative 'animation'

GRAVITY = Vector[0, 600] #this is an acceleration so pixels per second per second i.e = pixels/s^2
JUMP_VELOCITY = Vector[0, -300]
DEATH_VELOCITY = Vector[50,-500] # pixels per second
DEATH_ROTATIONAL_VELOCITY = 360#degrees per second
RESTART_INTERVAL = 3 #seconds
PLAYER_ANIMATION_FPS = 5.0 # frames per second
PLAYER_FRAMES = [:player1, :player2, :player3, :player2] # we can remove player2 behind player 3 for a different type of animation
OBSTACLE_PADDING = 50 #pixels
DIFFICULTIES = {
	easy: {
		speed: 150, #pixels/s
		obstacle_gap: 220, #pixels
		obstacle_spawn_interval: 2.0 #seconds
	},
	medium: {
		speed: 200, # pixels/s
		obstacle_gap: 180, #pixels
		obstacle_spawn_interval: 1.3, #seconds
	},
	hard: {
		speed: 400, #pixels/s
		obstacle_gap: 160, #pixels
		obstacle_spawn_interval: 1, #second
	},
}

Rect = DefStruct.new{{
  pos: Vector[0,0],
  size: Vector[0,0]
}}.reopen do
  def min_x; pos.x; end
  def min_y; pos.y; end
  def max_x; pos.x + size.x; end
  def max_y; pos.y + size.y; end    
end 

Obstacle = DefStruct.new{{
  pos: Vector[0,0],
	player_has_crossed: false,
	gap: DIFFICULTIES[:medium][:obstacle_gap],
}}

Particle = DefStruct.new{{
	pos: Vector[0,0],
	velocity: Vector[0,0],
	rotation: 0,
	rotational_velocity: 0,
	scale: 1.0,
	tint: Gosu::Color::WHITE,
}}

GameState = DefStruct.new {{
	difficulty: :medium,
  score: 0,
  started: false,
  alive: true,
  scroll_x: 0,
  player_position: Vector[20, 250], # 20 moves the player slightly away from the left of the screen
  player_velocity: Vector[0, 0],
  player_rotation: 0,
  player_animation: Animation.new(PLAYER_ANIMATION_FPS,PLAYER_FRAMES),
	obstacles: [], # Array of obstacles
	particles: [], #Array of particiles
  obstacle_timer: Timer::Looping.new(DIFFICULTIES[:medium][:obstacle_spawn_interval]),
  restart_timer: Timer::OneShot.new(RESTART_INTERVAL)
}}

class GameWindow < Gosu::Window
  SAVE_PATH = ENV['HOME'] + '/.copy_bird_save'

  def initialize(*args)
    super
		@font = Gosu::Font.new(self, Gosu.default_font_name, 40)
		@music = Gosu::Song.new(self, 'audio/music.mp3')
		@music.play(true)
    @images = {
      background: Gosu::Image.new(self, 'images/background.png', false),
      foreground: Gosu::Image.new(self, 'images/foreground.png', true),
      player1: Gosu::Image.new(self, 'images/fruity_1.png', false),
      player2: Gosu::Image.new(self, 'images/fruity_2.png', false),
      player3: Gosu::Image.new(self, 'images/fruity_3.png', false),
			obstacle: Gosu::Image.new(self, 'images/obstacle.png', false),
			particle: Gosu::Image.new(self, 'images/particle.png', false)
		}
		@sounds = {
			flap: Gosu::Sample.new(self, 'audio/jump.wav'),
			score: Gosu::Sample.new(self, 'audio/coin.wav'),
		}

		@state = GameState.new
		
  end

  def button_down(button)
    case button
    when Gosu::KbEscape then close
    when Gosu::KbS then save_game
		when Gosu::KbL then load_game
		when Gosu::Kb1 then set_difficulty(:easy)
		when Gosu::Kb2 then set_difficulty(:medium)
		when Gosu::Kb3 then set_difficulty(:hard)
		when Gosu::Kb4 then set_aussie_theme
		when Gosu::KbSpace
			if @state.alive 	
				@state.player_velocity.set!(JUMP_VELOCITY) 
				@state.started = true
				@sounds[:flap].play(0.3, rand(0.9..1.1))
			end
		end
  end

  def set_aussie_theme
    @images = {
      background: Gosu::Image.new(self, 'images/background.png', false),
      foreground: Gosu::Image.new(self, 'images/foreground.png', true),
      player1: Gosu::Image.new(self, 'images/kook_1.png', false),
      player2: Gosu::Image.new(self, 'images/kook_2.png', false),
      player3: Gosu::Image.new(self, 'images/kook_3.png', false),
			obstacle: Gosu::Image.new(self, 'images/obstacle.png', false),
			particle: Gosu::Image.new(self, 'images/gaytime.png', false)
		}
  end

	def set_difficulty(name)
		@state.difficulty = name
		@state.obstacle_timer.interval = DIFFICULTIES[name][:obstacle_spawn_interval]

	end
  def save_game   
    File.binwrite(SAVE_PATH, Marshal.dump(@state))
  end
  
  def load_game
    @state = Marshal.load(File.binread(SAVE_PATH))
  end  

  def update
    delta_time = update_interval / 1000.0

    @state.scroll_x += delta_time * difficulty[:speed] * 0.5
      if @state.scroll_x > @images[:foreground].width
        @state.scroll_x = 0
      end

		@state.player_animation.update(delta_time)
		
		@state.particles.each do |part|
			part.velocity += delta_time * GRAVITY
			part.pos += delta_time * part.velocity
			part.rotation += delta_time * part.rotational_velocity
		end
		@state.particles.reject! {|parts| parts.pos.y >= height} #removes all particles when they fall off the screen

    return unless @state.started

    @state.player_velocity += delta_time * GRAVITY
    @state.player_position += delta_time * @state.player_velocity
    
    if @state.alive
			@state.obstacle_timer.update(delta_time) do
				gap = difficulty[:obstacle_gap]
				lower_bound = height - OBSTACLE_PADDING - gap #height is the height of the screen 
        @state.obstacles <<  Obstacle.new(
					pos: Vector[width, rand(OBSTACLE_PADDING..lower_bound)], 
					gap: gap
				)
      end
    end

    @state.obstacles.each do |obst|
      obst.pos.x -= delta_time * difficulty[:speed]
      if obst.pos.x < @state.player_position.x && !obst.player_has_crossed && @state.alive
				@state.score += 1
				@sounds[:score].play(0.5, 0.4 + @state.score * 0.05)
				obst.player_has_crossed = true
				particle_burst
      end  
    end

    @state.obstacles.reject! { |obst|  obst.pos.x < -@images[:obstacle].width}

    if @state.alive && player_is_colliding?
      @state.alive = false
      @state.player_velocity.set!(DEATH_VELOCITY)
    end

    unless @state.alive
      @state.player_rotation += delta_time * DEATH_ROTATIONAL_VELOCITY
      @state.restart_timer.update(delta_time) { restart_game }
    end  
	end
	
	def particle_burst
		30.times do
			@state.particles << Particle.new(
				pos: Vector[width/2.0, 60],
				velocity: Vector[rand(-100..100), rand(-300..-10)],
				rotation: rand(0..360),
				rotational_velocity: rand(-360..360),
				scale: rand(0.5..1.0),
				tint: Gosu::Color.new(
					255,
					rand(150..255), #change the 150 to a lower number for a darker colour
					rand(150..255),
					rand(150..255),
				),
			)
		end
	end

	def restart_game
		old_difficulty = @state.difficulty
		@state = GameState.new(scroll_x: @state.scroll_x)
		@state.difficulty = old_difficulty  # could also do set_difficulty(old_difficulty) for this line 
  end 

  def player_is_colliding?
    player_r = player_rect
    return true if obstacle_rects.find { |obst_r| rects_interct?(player_r, obst_r) }
    not rects_interct?(player_r, Rect.new(pos: Vector[0,0], size: Vector[width, height]))
  end

  def rects_interct?(r1, r2)
    return false if r1.max_x < r2.min_x
    return false if r1.min_x > r2.max_x

    return false if r1.min_y > r2.max_y
    return false if r1.max_y < r2.min_y
 
    # So if the rectange is not above, below, to the right or to the left that must mean it is intersecting
    true
  end

  def draw
		@images[:background].draw(0, 0, 0)

		@state.particles.each do |part|
			@images[:particle].draw_rot(
				part.pos.x, part.pos.y, 0,
				part.rotation,
				0.5, 0.5, 
				part.scale, part.scale,
				part.tint
			)
		end
		
		@images[:foreground].draw(-@state.scroll_x, 0, 0)
    @images[:foreground].draw(-@state.scroll_x + @images[:foreground].width, 0, 0)

    @state.obstacles.each do |obst|
      img_y = @images[:obstacle].height
      #top log
      @images[:obstacle].draw(obst.pos.x, obst.pos.y - img_y, 0)
      scale(1, -1) do
        #bottom log
        @images[:obstacle].draw(obst.pos.x, -height - img_y + (height - obst.pos.y - obst.gap), 0)
      end
    end

    player_frame.draw_rot(
      @state.player_position.x, @state.player_position.y, 
      0, @state.player_rotation,
      0,
      0)

    #uncomment this out to turn the debugger on
    #debug_draw

		@font.draw_rel(@state.score, width/2.0, 60, 0, 0.5, 0.5)
		@font.draw_rel(@state.difficulty.to_s, width - 10,  height - 10, 0, 1.0, 1.0)
	end
	
	def difficulty
		DIFFICULTIES[@state.difficulty]
	end 

  def player_frame
    @images[@state.player_animation.frame]
  end

  def player_rect
    Rect.new(
      pos: @state.player_position, 
      size: Vector[player_frame.width, player_frame.height]
    )
  end

  def obstacle_rects
    img_y = @images[:obstacle].height
    obst_size = Vector[@images[:obstacle].width, @images[:obstacle].height]

    @state.obstacles.flat_map do |obstacle|
    top = Rect.new(pos: Vector[obstacle.pos.x, obstacle.pos.y - img_y],size: obst_size)
    bottom = Rect.new(pos: Vector[obstacle.pos.x, obstacle.pos.y + obstacle.gap],size: obst_size)
    [top,bottom]
    end
  end  

    def debug_draw
      color = player_is_colliding? ? Gosu::Color::RED : Gosu::Color::GREEN
      draw_debug_rect(player_rect, color)
      obstacle_rects.each do |obst_rect|
        draw_debug_rect(obst_rect)
      end
    end
    
    def draw_debug_rect(rect, color = Gosu::Color::GREEN)
      x = rect.pos.x
      y = rect.pos.y
      w = rect.size.x
      h = rect.size.y

      points = [
        Vector[x, y],
        Vector[x + w, y],
        Vector[x + w, y + h],
        Vector[x, y + h]
      ]

      points.each_with_index do |p1,idx|
        p2 = points[(idx + 1 ) % points.size]
        draw_line(p1.x, p1.y, color, p2.x, p2.y, color)
    end
  end
end

window = GameWindow.new(320, 480, false)
window.show
