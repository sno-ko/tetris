# encoding: Shift_JIS

line_bit_list = STDIN.read.split("\n").map{|line| line.split(",")}

bit_1_list = Array.new

line_bit_list.each_with_index{|line, low|
  line.each_with_index{|bit, clm|
    if bit == "1"
      bit_1_list.push([clm, low])
    end
  }
}

p bit_1_list
