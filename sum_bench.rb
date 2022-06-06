# encoding: Shift_JIS
line_list = STDIN.read.chomp.split("\n")
item = line_list.slice!(0)
line_list.delete(item)
item = item.split(" ")

line_list.map!{|line| line.gsub(/[()]/, "").split(" ")}
# line_list.each{|line| p line}
line_list = line_list.group_by{|line| line[0]}.map{|name, value| [name, value.map{|score| score[1..-1]}]}.to_h

start = 0
fin = - 1

line_list = line_list.map{|name, score|
  [name, score.map{|score| [item, score].transpose}]
}.to_h


line_list = line_list.map{|name, score|
  [name, score.flatten(1)]
}.to_h

line_list = line_list.map{|name, score|
  [name, score.group_by{|score| score[0]}]
}.to_h

line_list = line_list.map{|name, score|
  [name, score.map{|name, score| [name, score.map{|score| score[1].to_f}]}.to_h]
}.to_h

# p line_list

name_list = line_list.keys

name_list.each{|name|
  p name
  item.each{|item|
    print("#{item}: #{line_list[name][item].sum / line_list[name][item].size} ")
  }
  print("\n")
}
