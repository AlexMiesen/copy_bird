require 'gosu'
require_relative 'defstruct'
require_relative 'vector'

GRAVITY = Vector[0, 600] #this is an acceleration so pixels per second per second i.e = pixels/s^2
JUMP_VELOCITY = Vector[0, -300]
OBSTACLE_SPEED = 200 #pixels/s
OBSTACLE_SPAWN_INTERVAL = 1.3 #seconds
OBSTACLE_GAP = 100 #pixels

GameState = DefStruct.new {{
  scroll_x: 0,
  player_position: Vector[0, 0],
  player_velocity: Vector[0, 0],
  obstacles: [], # Array of Vec
  obstacle_countdown: OBSTACLE_SPAWN_INTERVAL
}}

class GameWindow < Gosu::Window
  def initialize(*args)
    super
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
    when Gosu::KbSpace then @state.player_velocity.set!(JUMP_VELOCITY)
    end
  end

  def spawn_obstacle
    @state.obstacles << Vector[width, rand(50...320)]
  end

  def update
    delta_time = update_interval / 1000.0

    @state.scroll_x += delta_time * OBSTACLE_SPEED * 0.5
      if @state.scroll_x > @images[:foreground].width
        @state.scroll_x = 0
      end

    @state.player_velocity += delta_time * GRAVITY
    @state.player_position += delta_time * @state.player_velocity

    @state.obstacle_countdown -= delta_time
    if @state.obstacle_countdown <= 0
      spawn_obstacle
      @state.obstacle_countdown += OBSTACLE_SPAWN_INTERVAL
    end


    @state.obstacles.each do |obst|
      obst.x -= delta_time * OBSTACLE_SPEED
    end
  end

  def draw
    @images[:background].draw(0, 0, 0)
    @images[:foreground].draw(-@state.scroll_x, 0, 0)
    @images[:foreground].draw(-@state.scroll_x + @images[:foreground].width, 0, 0)

    @state.obstacles.each do |obst|
      img_y = @images[:obstacle].height
      #top log
      @images[:obstacle].draw(obst.x, obst.y - img_y, 0)
      scale(1, -1) do
        #bottom log
        @images[:obstacle].draw(obst.x, -height - img_y + (height - obst.y - OBSTACLE_GAP), 0)
      end
    end

    @images[:player].draw(20, @state.player_position.y, 0)

  end
end

window = GameWindow.new(320, 480, false)
window.show
