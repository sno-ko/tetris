# encoding: Shift_JIS
bit_list = STDIN.read.split("\n").map{|line| line.split(",")}

bit_1_list = Array.new
bit_list.each_with_index{|line, clm|
  line.each_with_index{|bit, row|
    if bit == "1"
      bit_1_list.push([((row + 1) - 3).to_s, ((clm + 1) - 3).to_s])
    end
  }
}

bit_size = bit_1_list.size
point_list = bit_1_list.map{|point| ["@mino[[Spawn_x + (#{point[0]}), Spawn_y + (#{point[1]})]]"]}

bit_string = Array.new(bit_size, 1).join(", ")

output = point_list.join(", ") + " = " + bit_string
print output
