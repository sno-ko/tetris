# encoding: Shift_JIS
require "neural_network"
require "genetic_algorithm"

path_cd = File.dirname(__FILE__)

nnw_info = {"num_input" => 4, "num_hidden" => 0, "thick_hidden" => 0, "num_output" => 1}

fuga = N_network.new(nnw_info)
# p fuga.input([4, 5, 6, 7, 8, 3, 3])

G_algorithm.start_new(10, "A", nil, nnw_info.values, File.dirname(__FILE__))
# G_algorithm.start_log(File.dirname(__FILE__))
# p G_algorithm.list

# name = gets.chomp

# =begin
5.times{|index|
  print("index:", index, "\n")

  10.times{|chara|
    # print("chara: #{chara}\n")
    strength = G_algorithm.select(chara)
      # p strength
    fuga.edit(strength)
    p score = fuga.input([2, 3, 1, 3])
    G_algorithm.record(chara, score)
  }

  G_algorithm.mix
  G_algorithm.log

}

G_algorithm.save("test")
# =end
