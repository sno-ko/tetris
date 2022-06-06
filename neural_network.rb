# encoding: Shift_JIS
include Math
require "matrix"

class N_network
  attr_accessor :weight
  attr_reader :num_lay, :weight_sum, :num_input, :num_hidden, :thick_hidden, :num_output

  def initialize(
      nnw_size,
      weight = nil
    )

    @num_input = nnw_size["num_input"]
    @num_hidden = nnw_size["num_hidden"]
    @thick_hidden = nnw_size["thick_hidden"]
    @num_output = nnw_size["num_output"]

    unless @thick_hidden == 0
      if weight.nil?
        weight = {
          "I-H" => Array.new(@num_input + 1).map{Array.new(@num_hidden).map{rand(-2.0..2.0).round(2)}},
          "H-H" => Array.new(@thick_hidden - 1).map{Array.new(@num_hidden + 1).map{Array.new(@num_hidden).map{rand(-2.0..2.0).round(2)}}},
          "H-O" => Array.new(@num_hidden + 1).map{Array.new(@num_output).map{rand(-2.0..2.0).round(2)}}
        }
      end
    else
      if weight.nil?
        weight = {
          "I-H" => Array.new(@num_input + 1).map{Array.new(@num_output).map{rand(-2.0..2.0).round(2)}},
          "H-H" => Array.new,
          "H-O" => Array.new
        }
      end
    end

    @weight = weight
    @weight_sum = [@weight["I-H"]] + @weight["H-H"] + [@weight["H-O"]]

    @node_list = [
      [Array.new(num_input, 0)],
      Array.new(thick_hidden).map{Array.new(num_hidden, 0)},
      [Array.new(num_output, 0)]
    ].flatten(1)
    @num_lay = @node_list.size
    @num_node_lay = @node_list.map{|lay| lay.size}
  end

  def edit(weight)
    @weight = weight
    @weight_sum = [@weight["I-H"]] + @weight["H-H"] + [@weight["H-O"]]
  end

  def input(input_value_list, lay = @num_lay - 1)
    output_value_list = Array.new(@num_node_lay[lay], 0)
    unless lay == 1
      input_value_list = input(input_value_list, lay - 1)
    end

    mat_row = Matrix.rows([input_value_list.unshift(1)])
    mat_clm = Matrix.columns(@weight_sum[lay - 1].transpose)

    output_value_list = (mat_row * mat_clm).to_a[0]
    output_value_list.map!{|value|
      unless lay == @num_lay - 1
        1 / (1 + exp(-value))
      else
        value
      end
    }

    return output_value_list
  end

end
