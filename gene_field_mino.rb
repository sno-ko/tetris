# encoding: Shift_JIS
require "dxruby"

class Board
  attr_accessor :cell, :width, :height
  Cell_size = 20
  Image_0 = Image.new(Cell_size, Cell_size, C_BLACK)
  Image_1 = Image.new(Cell_size, Cell_size, C_WHITE)

  def initialize(width = 40, height = 40)
    @width = width
    @height = height
    @cell = Array.new(height){Array.new(width, 0)}
  end

  def draw
    @cell.each_with_index{|line, row|

      line.each_with_index{|bit, clm|
        case bit
        when 0
          Window.draw(clm * Cell_size, row * Cell_size, Image_0)

        when 1
          Window.draw(clm * Cell_size, row * Cell_size, Image_1)
        end
      }
    }
  end
end


def input
  point_x = (Input.mousePosX / Board::Cell_size.to_f).floor
  point_y = (Input.mousePosY / Board::Cell_size.to_f).floor
  $board.cell[point_y][point_x] = 1
end

def reset
  $board.cell = Array.new($board.height){Array.new($board.width, 0)}
end

print("generate (1:field, 2:tetrimino) => ")
mode = gets.chomp.to_i
case mode
when 1
  print("width: ")
  width = gets.chomp
  if width !~ /\d+/
    width = 10
  else
    width = width.to_i
  end

  print("height: ")
  height = gets.chomp
  if height !~ /\d+/
    height = 20
  else
    height = height.to_i
  end

when 2
  width = 5
  height = 5
end

Width = width
Height = height

$board = Board.new(Width, Height)

Window.caption = "FIELD GENERATOR"
Window.width = Width * Board::Cell_size
Window.height = Height * Board::Cell_size
Window.fps = 60
time = 0

Window.loop do
  $board.draw

  if Input.mouseDown?(M_LBUTTON)
    input
  end

  if Input.key_push?(K_R)
    reset
  end

  if Input.key_push?(K_RETURN)
    break
  end

end


case mode
when 1
  bit_1_list = Array.new

  $board.cell.each_with_index{|line, low|
    p line
    line.each_with_index{|bit, clm|
      if bit == 1
        bit_1_list.push([clm, low])
      end
    }
  }

  print("\n", bit_1_list, "\n")
when 2
  bit_1_list = Array.new

  $board.cell.each_with_index{|line, clm|
    p line
    line.each_with_index{|bit, row|
      if bit == 1
        bit_1_list.push([((row + 1) - 3).to_s, ((clm + 1) - 3).to_s])
      end
    }
  }

  bit_size = bit_1_list.size
  point_list = bit_1_list.map{|point| ["@mino[[Spawn_x + (#{point[0]}), Spawn_y + (#{point[1]})]]"]}

  bit_string = Array.new(bit_size, 1).join(", ")

  output = point_list.join(", ") + " = " + bit_string
  print("\n", output, "\n")
end
