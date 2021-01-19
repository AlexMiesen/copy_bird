require 'gosu'
require_relative 'defstruct'
require_relative 'vector'

GRAVITY = Vector[0, 600] #this is an acceleration so pixels per second per second i.e = pixels/s^2
JUMP_VELOCITY = Vector[0, -300]
OBSTACLE_SPEED = 200 #pixels/s
OBSTACLE_SPAWN_INTERVAL = 1.3 #seconds
OBSTACLE_GAP = 140 #pixels
DEATH_VELOCITY = Vector[50,-500] # pixels per second
DEATH_ROTATIONAL_VELOCITY = 360#degrees per second
RESTART_INTERVAL = 3 #seconds

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
  player_has_crossed: false
}}

GameState = DefStruct.new {{
  score: 0,
  started: false,
  alive: true,
  scroll_x: 0,
  player_position: Vector[20, 250], # 20 moves the player slightly away from the left of the screen
  player_velocity: Vector[0, 0],
  player_rotation: 0,
  obstacles: [], # Array of obstacles
  obstacle_countdown: OBSTACLE_SPAWN_INTERVAL,
  restart_countdown: RESTART_INTERVAL
}}

class GameWindow < Gosu::Window
  SAVE_PATH = ENV['HOME'] + '/.copy_bird_save'
  p SAVE_PATH

  def initialize(*args)
    super
    @font = Gosu::Font.new(self, Gosu.default_font_name, 40)
    @images = {
      background: Gosu::Image.new(self, 'images/background.png', false),
      foreground: Gosu::Image.new(self, 'images/foreground.png', true),
      player: Gosu::Image.new(self, 'images/fruity_1.png', false),
      obstacle: Gosu::Image.new(self, 'images/obstacle.png', false)
    }
    @state = GameState.new
  end

  def button_down(button)
    case button
    when Gosu::KbEscape then close
    when Gosu::KbS then save_game
    when Gosu::KbL then load_game  
    when Gosu::KbSpace
      @state.player_velocity.set!(JUMP_VELOCITY) if @state.alive 
      @state.started = true
    end
  end

  def save_game   
    File.binwrite(SAVE_PATH, Marshal.dump(@state))
  end
  
  def load_game
    @state = Marshal.load(File.binread(SAVE_PATH))
  end  

  def update
    delta_time = update_interval / 1000.0

    @state.scroll_x += delta_time * OBSTACLE_SPEED * 0.5
      if @state.scroll_x > @images[:foreground].width
        @state.scroll_x = 0
      end

    return unless @state.started  

    @state.player_velocity += delta_time * GRAVITY
    @state.player_position += delta_time * @state.player_velocity
    
    if @state.alive
      @state.obstacle_countdown -= delta_time
      if @state.obstacle_countdown <= 0
        @state.obstacles <<  Obstacle.new(pos: Vector[width, rand(50...320)])
        @state.obstacle_countdown += OBSTACLE_SPAWN_INTERVAL
      end
    end

    @state.obstacles.each do |obst|
      obst.pos.x -= delta_time * OBSTACLE_SPEED

      if obst.pos.x < @state.player_position.x && !obst.player_has_crossed && @state.alive
        @state.score += 1
        obst.player_has_crossed = true
      end  
    end

    @state.obstacles.reject! { |obst|  obst.pos.x < -@images[:obstacle].width}

    if @state.alive && player_is_colliding?
      @state.alive = false
      @state.player_velocity.set!(DEATH_VELOCITY)
    end

    unless @state.alive
      @state.player_rotation += delta_time * DEATH_ROTATIONAL_VELOCITY
      @state.restart_countdown -= delta_time
      if @state.restart_countdown <= 0
        restart_game
      end  
    end  
  end

  def restart_game
    @state = GameState.new(scroll_x: @state.scroll_x)
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
    @images[:foreground].draw(-@state.scroll_x, 0, 0)
    @images[:foreground].draw(-@state.scroll_x + @images[:foreground].width, 0, 0)

    @state.obstacles.each do |obst|
      img_y = @images[:obstacle].height
      #top log
      @images[:obstacle].draw(obst.pos.x, obst.pos.y - img_y, 0)
      scale(1, -1) do
        #bottom log
        @images[:obstacle].draw(obst.pos.x, -height - img_y + (height - obst.pos.y - OBSTACLE_GAP), 0)
      end
    end

    @images[:player].draw_rot(
      @state.player_position.x, @state.player_position.y, 
      0, @state.player_rotation,
      0,
      0)

    #uncomment this out to turn the debugger on
    #debug_draw

    @font.draw_rel(@state.score, width/2.0, 60, 0, 0.5, 0.5)
  end

  def player_rect
    Rect.new(
      pos: @state.player_position, 
      size: Vector[@images[:player].width, @images[:player].height]
    )
  end

  def obstacle_rects
    img_y = @images[:obstacle].height
    obst_size = Vector[@images[:obstacle].width, @images[:obstacle].height]

    @state.obstacles.flat_map do |obstacle|
    top = Rect.new(pos: Vector[obstacle.pos.x, obstacle.pos.y - img_y],size: obst_size)
    bottom = Rect.new(pos: Vector[obstacle.pos.x, obstacle.pos.y + OBSTACLE_GAP],size: obst_size)
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
