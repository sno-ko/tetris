# encoding: Shift_JIS
require 'dxruby'
require 'benchmark'
require "./neural_network"
require "./genetic_algorithm"

player_list = Array.new   # �v���C���[���X�g
com_num = nil   # COM�̐�

# �Q�[�����[�h�I��
# ���[�h�ɉ����ăv���C���[���X�g�Ƀv���C���[���ǉ�
print("mode(1:solo, 2:PvP, 3:vsCOM, 4:COMvsCOM) => ")
input_mode = gets.chomp
if input_mode == "2"
  player_list.push("human_1", "human_2")
elsif input_mode == "3"
  player_list.push("human_1", "com")
  com_num = 1
elsif input_mode == "4"
  player_list.push("com_1", "com_2")
  com_num = 2
else
  print("controller (1:Player, 2:COM) => ")
  input_ctrl = gets.chomp
  if input_ctrl == "2"
    player_list.push("com")
    com_num = 1
  else
    player_list.push("human_1")
  end
end

# COM�̑I�� (COM���v���C���[�ɂ���ꍇ)
unless com_num.nil?
  com_list = Array.new
  # COM�����X�g (�C���f�b�N�X�t��)
  chara_list = G_algorithm.list(File.dirname(__FILE__)).map.with_index{|chara, index| [index, chara]}

  print("selcet COM [")
  chara_list.each{|pear| print("#{pear[0] + 1}:#{pear[1]}   ")}
  print("]\n")
  com_num.times{|index|
    print("COM #{index + 1} => ")
    # �C���f�b�N�X�őI��
    ans = gets.chomp
    unless ans.empty?
      com_list.push(chara_list[ans.to_i - 1][1])
    else
      com_list.push(chara_list[0][1])
    end
  }
end

# �t�B�[���h�̉����̐ݒ� �����̂ݗL�� �����Ȑ��l�̏ꍇ10��
print("width (default:10) = ")
input_width = gets.chomp
if input_width !~ /\d+/
  input_width = 10
end

# �t�B�[���h�̏c���̐ݒ� �����̂ݗL�� �����Ȑ��l�̏ꍇ20��
print("height (default:20) = ")
input_height = gets.chomp
if input_height !~ /\d+/
  input_height = 20
end

# �J�n�����x���̐ݒ� 0~19�̐����̂ݗL�� �����Ȑ��l�̏ꍇ0��
# "manji"�̏ꍇ ���[�h�L����(mode_manji��true��)
print("start level (0~19) = ")
input_level = gets.chomp
mode_manji = false
if input_level !~ /\d+/
  if input_level == "manji"
    mode_manji = true
  else
    input_level = 0
  end
elsif input_level.to_i < 0 || input_level.to_i > 19
  input_level = 0
end

Fps = 60    # �t���[�����[�g
Block_size = 20   # �u���b�N�̃T�C�Y
Wait_block_size = 12    # NEXT�u���b�N, HOLD�u���b�N�̕\���T�C�Y
Start_fall_speed = Fps / 3 - input_level.to_i   # �J�n���̗������x
Field_width = input_width.to_i    # �t�B�[���h�̉���
Field_height = input_height.to_i    # �t�B�[���h�̏c��
Betwen_level = 10   # ���x���A�b�v�ɕK�v�ȃ��C��������

Rnd = Random.new   # �~�m�̕��т����߂闐���̎�

Num_player = player_list.size   # �v���C���[��
Num_player_per_row = 3   # ��i�̃v���C���[��

# �t�B�[���h, �t�B�[���h�g, �c���������N���X
class Field
  attr_accessor :mino, :field, :field_color, :color, :width_px, :height_px, :delete, :comp_delete, :game_ov, :num_add_line
  Thick_wall = 4    # �t�B�[���h�g�̕�
  Spawn_area = 3   # �~�m�����p�̃X�y�[�X
  Combo_point = 1.6   # �R���{�̊�b�_
  Delete_line_limit = Fps / 10    # ���C����������̂ɂ����鎞��
  Add_line_limit = Fps / 2   # ���ז��u���b�N��������܂ł̎���

  # �����ʂ̍ő�l
  @@top_height = nil   # �ő�̍���
  @@max_sum_height = nil   # �����̑��a
  @@max_delete_line = nil   # �����̍s��
  @@max_num_hole = nil   # ���̐�
  @@max_dipth_well = nil   # ��˂̐[��
  @@max_bumpiness = nil   # �Ȃ��炩��
  @@max_dipth_hole = nil   # ���̐[���̑��a
  @@max_trans = nil   # �u���b�N�L���̐؂�ւ���

  # ��b�_
  Basic_socre = {"single" => 100, "double" => 300, "triple" => 500, "tetris" => 800,
    "T-spin_single" => 200, "T-spin_double" => 1200, "T-spin_triple" => 1600}

  # ���ז��u���b�N�̑��鐔
  Num_send_line = {"single" => 0, "double" => 1, "triple" => 2, "tetris" => 4,
    "T-spin_single" => 2, "T-spin_double" => 4, "T-spin_triple" => 6}

  @@line_send = Array.new   # ���ז��u���b�N

  @@player_list = Array.new   # �v���C���[���X�g

  # ���������\�b�h
  # ���� player: �v���C���[��, width: �t�B�[���h�̉���, height: �t�B�[���h(�~�m��u������)�̏c��
  def initialize(player, width, height)
    # �v���C���[���X�g�ɒǉ�
    @@player_list.push(player)

    # ���ז��u���b�N(�̑f)����
    @@line_send = Array.new((width - 1), 1).push(0)

    @player = player   # �v���C���[��
    @width = width   # ����
    @height = height + Spawn_area   # �c�� (�~�m���������܂�)
    @width_px = (@width + Thick_wall * 2) * Block_size   # �����s�N�Z��
    @height_px = (@height + Thick_wall * 2) * Block_size   # �c���s�N�Z��

    @center_x = @width_px / 2   # ���Sx���W
    @center_y = @height_px / 2   # ���Sy���W

    @color = C_WHITE    # �g�̐F
    @delete = false   # �I�u�W�F�N�g�����t���O (false: ����, true: ����)
    @delete_line_count = Delete_line_limit    # ���C����������܂ł̃J�E���g

    @num_add_line = 0   # �󂯎�邨�ז��u���b�N�̃��C����
    @add_line_count = 0   # ���ז��u���b�N�󂯎��܂ł̃^�C�����~�b�g

    @combo = 0    # �R���{��
    @comp_delete = nil    # ���������̐i���� (nil: ���������Ȃ�, true: ������������, false: �����������s��)
    @game_ov = false    # �Q�[���I�[�o�[�t���O (true: �Q�[���I�[�o�[, false: �Q�[�����s)
    @go_count = 0     # �t���O�������Ă���Q�[���I�[�o�[����܂ł̃J�E���g (���̊Ԃɉ�ʔ���)

    # ������ (������)
    @@max_top_height = height.to_f
    @@max_sum_height = (width * height).to_f
    @@max_delete_line = 4.0
    @@max_num_hole = ((width / 2.0).ceil * height).to_f
    @@max_dipth_well = height.to_f
    @@max_bumpiness = (height * (width - 1)).to_f
    @@max_dipth_hole = ((width / 2.0).ceil * (height - 1) + (width / 2.0).floor * (height - 2)).to_f
    @@max_trans = ((width - 1) * height).to_f

    # �u���b�N�̗L��(�r�b�g���)��ۑ�����񎟌��z�� (1: �u���b�N����, 0: �u���b�N�Ȃ�)
    @field = Array.new(@height + Thick_wall * 2).map{Array.new(Thick_wall, 1) + Array.new(@width, 0) + Array.new(Thick_wall, 1)}
    # �u���b�N�̐F��ۑ�����񎟌��z�� (1: �t�B�[���h�g��@color�œh��, 0: �`�斳��, ����ȊO(�J���[�R�[�h): �c��)
    @field_color = Array.new(@height + Thick_wall * 2).map{Array.new(Thick_wall, 1) + Array.new(@width, 0) + Array.new(Thick_wall, 1)}
    # �t�B�[���h�g�̃r�b�g������������
    Thick_wall.times{|index|
      @field[index].fill(1)
      @field[-(index + 1)].fill(1)

      @field_color[index].fill(1)
      @field_color[-(index + 1)].fill(1)
    }

    # �~�m�̔����X�y�[�X�̓t�B�[���h�g�Ƃ��ĕ`��
    @field_color[Thick_wall].fill(1)
    @field_color[Thick_wall + 1].fill(1)
    @field_color[Thick_wall + 2].fill(1)

    @delete_line_list = Array.new   # �������ׂ����C���̗�ԍ����i�[����z��

    @font = Font.new(32)   # �Q�[���I�[�o�[��̃X�R�A�\���p�t�H���g
    @image_wall = Image.new(Block_size, Block_size, @color)   # @field_color��1�������Ă���ӏ��̕`��pimage (�t�B�[���h�g�̃e�N�X�`��)
    @image_go = Image.new(@width_px, @height_px, @color)   # �w�i�摜
    @image_dead_block = Image.new(Block_size, Block_size, [189, 189, 189])   # ���������u���b�N�̃e�N�X�`��

    @width_full = @field[0].size   # �t�B�[���h�g���܂߂������̃u���b�N��

    # ���C�������T�E���h
    @se_delete = Sound.new("#{File.dirname(__FILE__)}/sound/se_6.wav")
    # ���ז��u���b�N�T�E���h
    @se_add = Sound.new("#{File.dirname(__FILE__)}/sound/se_7.wav")
    # @wall_row = (0..(Thick_wall + 1)).to_a + ((@field_color.size - 3)..(@field_color.size - 1)).to_a
    # @wall_clm = (0..(Thick_wall - 1)).to_a + ((@field_color[0].size - 3)..(@field_color[0].size - 1)).to_a
  end

  # ��˂̐[���𑪂郁�\�b�h
  # ���� row: �s�ԍ�, field: �t�B�[���h
  # �Ԃ�l ��˂̐[��
  def Field.measure_dipth(row, field)
    # �[��1�ȏ�m�肩��X�^�[�g
    dipth = 1
    # row�s�ڂƃr�b�g��񂪈�v��������ԁA�[�����Z
    while !(field[row + dipth].nil?) && field[row + dipth] == field[row]
      dipth += 1
    end

    return dipth
  end

  # �w���̃c���̍����𑪂郁�\�b�h
  # ���� clm: �t�B�[���h�̎w���̔z�� (field��transpose) (0�Ԗڂ��ŏ�i)
  # �Ԃ�l �c���̍���
  def Field.height(clm)
    # �u���b�N�����݂���C���f�b�N�X���擾
    value = clm.index(1)
    if value.nil?
      # �u���b�N�����݂��Ȃ��ꍇ�͍���0
      return 0
    else
      # �����擾
      return clm.size - value
    end
  end

  # �t�B�[���h��(�g, �~�m������������)�̃u���b�N�̖��x���v�Z���郁�\�b�h
  # �Ԃ�l ���x
  def density
    return @field[(Thick_wall + Spawn_area)..-(Thick_wall + 1)].map{|row| row[Thick_wall..-(Thick_wall + 1)]}.flatten.count(1) / (@width * @height).to_f
  end

  # ���ז��u���b�N�𑗂郁�\�b�h
  # ���� player: �����̃v���C���[��, num_send_line: ���郉�C����
  def Field.send_line(player, num_send_line)
    # ���v���C���[���ƂɌJ��Ԃ�
    (@@player_list - [player]).each{|player|
      # ���v���C���[��@num_add_line�ɉ��Z
      $player_hash[player]["obj_list"][0].num_add_line += num_send_line
    }
  end

  # ���ז��u���b�N���󂯎�郁�\�b�h
  def add_line
    # �󂯎�郉�C�����J��Ԃ�
    @num_add_line.times{
      # ���ז��u���b�N����
      add_line = @@line_send.shuffle
      # �~�m�������̍ŏ�i������
      @field.delete_at(Thick_wall)
      # ���ז��u���b�N1���C����ǉ�
      @field.insert(
        -(Thick_wall + 1), Array.new(Thick_wall, 1) + add_line + Array.new(Thick_wall, 1)
      )

      # �t�B�[���h�̐F��Ԃ����l�ɏ���
      #���������ז��u���b�N��1�łȂ�image�I�u�W�F�N�g�ł��邱�Ƃɒ���
      @field_color.delete_at(Thick_wall)
      @field_color.insert(-(Thick_wall + 1), Array.new(Thick_wall, 1) + add_line.map{|clm|
          if clm == 1
            @image_dead_block
          else
            clm
          end
          } + Array.new(Thick_wall, 1))
      @field_color[Thick_wall + Spawn_area - 1].map!{|clm|
        if clm == 0
          1
        else
          clm
        end
      }
    }

    @num_add_line = 0
    @se_add.play
  end

  # �t�B�[���h��������ʂ𒊏o���郁�\�b�h
  # ���� field: �t�B�[���h
  # �Ԃ�l �����ʂ��i�[�����n�b�V��
  def Field.feature_value(field)
    # �t�B�[���h (�g1�u���b�N, �~�m����������)
    field_1 = field[(Thick_wall - 1)..-Thick_wall].map!{|row| row[(Thick_wall - 1)..-Thick_wall]}
    # �t�B�[���h (�g�Ȃ�, �~�m����������)
    field_2 = field_1[1..-2].map{|row| row[1..-2]}
    # �c������ւ� (�g�Ȃ�, �~�m����������)
    field_2_transpose = field_2.transpose

    # �e��̃c���̍������X�g
    height_list = field_2_transpose.map{|clm| Field.height(clm)}

    # �c���̍��� (�ő�l�ɑ΂��銄��)
    top_height = (height_list.max / @@max_top_height.to_f) * 10

    # ���̐��ϐ�
    num_hole = 0
    # ���̐[���ϐ�
    dipth_hole = 0
    # �t�B�[���h(�g�Ȃ�, �~�m����������)�̒i���ƂɌJ��Ԃ� (field_2���g��Ȃ��̂́A�[�̌��̌��m�ɘg���K�v�Ȃ���)
    field_1[1..-2].each_with_index{|line, row|
      row += 1
      # ��i�̃r�b�g���
      line_up = field_1[row - 1]
      # ���i�̃r�b�g���
      line_low = field_1[row + 1]

      # �񂲂ƂɌJ��Ԃ�
      line[1..-2].each_with_index{|bit, clm|
        clm += 1
        # �ߖT�̃Z���̃r�b�g���
        bit_neight = [line_up[clm], line[clm - 1], line[clm + 1], line_low[clm]]

        # ������0��, �ߖT���S��1�Ȃ猊
        if bit == 0 && bit_neight.count(1) == 4
          # ���̐����Z
          num_hole += 1
          # ���̐[�����Z
          dipth_hole += field_2_transpose[clm - 1][0..(row - 1)].count(1)
        end
      }
    }
    # �ő�l�ɑ΂��銄�����v�Z
    num_hole = (num_hole / @@max_num_hole) * 10
    dipth_hole = (dipth_hole / @@max_dipth_hole) * 10

    # ��˂̐[���ϐ�
    dipth_well = 0
    # �s�ԍ�
    row = 0
    # �S�Ă̍s�𑖍�
    until field_2[row].nil?
      # �ꂩ���̂݋󂢂Ă���s(=���)��������
      if field_2[row].count(0) == 1 && field_2_transpose[field_2[row].index(0)][0..row - 1].all?{|bit| bit == 0}
        # ��˂̐[�����v��
        dipth = Field.measure_dipth(row, field_2)
        # ����I������A��˂̉��i�����˒T���ĊJ
        row += dipth
        dipth_well += dipth
      else
        row += 1
      end
    end
    # dipth_well = (dipth_well / @@max_dipth_well) * 10 - 5

    # �c���̊e��̍����̑��a�����߁A�ő�l�ɑ΂��銄�������߂�
    sum_height = (height_list.inject(:+) / @@max_sum_height) * 10

    # �r�b�g���̐؂�ւ��� (������) �ϐ�
    row_trans = 0
    # �s���ƂɌJ��Ԃ�
    field_2.each{|row|
      (row.size - 1).times{|clm|
        # �ׂ荇���Z�����قȂ�r�b�g�̂Ƃ��ϐ��ɉ��Z
        if row[clm] != row[clm + 1]
          row_trans += 1
        end
      }
    }
    # �ő�l�ɑ΂���ry
    row_trans = (row_trans / @@max_trans) * 10

    # �r�b�g���̐؂�ւ��� (�c����) �ϐ�
    # �������̂Ƃ��Ɠ��l
    clm_trans = 0
    field_2_transpose.each{|clm|
      (clm.size - 1).times{|row|
        # print clm[row], " ", clm[row + 1], "\n"
        if clm[row] != clm[row + 1]
          clm_trans += 1
        end
      }
    }
    # �ő�l�ɑ΂���ry
    clm_trans = (clm_trans / @@max_trans) * 10

    # �������C�������ő�l�ɑ΂���ry�Ōv�Z
    delete_line = (field_2.count{|row| row.all?{|bit| bit == 1}} / 4.0) * 10

    # �e��̍����̍��̐�Βl��ۑ�����z��
    diff_list = Array.new
    # �񂲂ƌJ��Ԃ�
    (height_list.size - 1).times{|index|
      diff_list.push((height_list[index] - height_list[index + 1]).abs)
    }
    # diff_list�̑��a���A�ő�l�ɑ΂���ry�Ōv�Z
    bumpiness = (diff_list.inject(:+) / @@max_bumpiness) * 10

    # �Ԃ�l�͏����_3�ʂ܂�
    return {
      "top_height" => top_height.round(3), "sum_height" => sum_height.round(3), "delete_line" => delete_line.round(3),
      "num_hole" => num_hole.round(3), "dipth_well" => dipth_well.round(3), "bumpiness" => bumpiness.round(3),
      "dipth_hole" => dipth_hole.round(3), "row_trans" => row_trans.round(3), "clm_trans" => clm_trans.round(3)
    }
  end

  # �n�`�ҏW���\�b�h
  # ���� point_list: [[x���W, y���W(�g������)]]
  def gene_terra(point_list)
    point_list.each{|point|
      # �g�̌������␳
      row = point[1] + Thick_wall + 3
      clm = point[0] + Thick_wall
      @field[row][clm] = 1
      @field_color[row][clm] = @image_dead_block
    }
  end

  # �`�惁�\�b�h
  def draw
    # @field_color��0�ȊO�������Ă�ӏ���`��
    @field_color.size.times{|row|
      @field_color[row].size.times{|clm|
        if @field_color[row][clm] == 1    # �g����
          Window.draw($player_hash[@player]["location_x"] + clm * Block_size, $player_hash[@player]["location_y"] + row * Block_size, @image_wall)
        elsif @field_color[row][clm] != 0   # �c��
          Window.draw($player_hash[@player]["location_x"] + clm * Block_size, $player_hash[@player]["location_y"] + row * Block_size, @field_color[row][clm])
        end
      }
    }
  end

  # ���������C���̓��_�v�Z & ���ז��u���b�N�̎󂯎��A���M���\�b�h
  # ���� num_delete_line: ���������C����, level: ���x��
  # �Ԃ�l ���_
  def cal_score(num_delete_line, level)
    # �Œ肳�ꂽ�~�m���擾
    tetrimino_copy = $player_hash[@player]["obj_list"][1]
    # T-spin���� nil: T-spin�łȂ�, true: T-spin�ł���
    t_spin = nil
    if tetrimino_copy.type == "T" && Tetrimino.last_act(@player) == "rote"
      tetrimino_mino = tetrimino_copy.mino.map{|cell| cell[0]}
      # �Œ�~�m�̒��S���W�擾 (�l���̃r�b�g�̔���̂���)
      center_x = tetrimino_mino[12][0]
      center_y = tetrimino_mino[12][1]
      corner_bit = [@field[center_y - 1][center_x - 1], @field[center_y - 1][center_x + 1], @field[center_y + 1][center_x - 1], @field[center_y + 1][center_x + 1]]
      # �l����3�����ȏオ�u���b�N����Ƃ�
      if corner_bit.count(1) >= 3
        t_spin = true
      end
    end

    # ��b�_�v�Z (T-spin�ł��邩�ǂ���&���������C����)
    if t_spin == true
      case num_delete_line
      when 1
        judge = "T-spin_single"
      when 2
        judge = "T-spin_double"
      when 3
        judge = "T-spin_triple"
      end
    else
      case num_delete_line
      when 1
        judge = "single"
      when 2
        judge = "double"
      when 3
        judge = "triple"
      when 4
        judge = "tetris"
      end
    end

    # ���_�v�Z (��b�_ * (���x��+1) * �R���{��b�_ ** (�R���{��-1))
    score = Basic_socre[judge] * (level + 1) * Combo_point ** (@combo - 1)

    # ���������C���������A�󂯎�邨�ז��u���b�N���E
    @num_add_line -= num_delete_line
    # �󂯎�邨�ז��u���b�N���Ȃ��Ȃ�ƁA�J�E���g���Z�b�g (<= 0 �̂ق�������?)
    if @num_add_line < 0
      @num_add_line = 0
      @add_line_count = 0
    end

    # ���邨�ז��u���b�N�̌v�Z
    num_send_line = Num_send_line[judge] - @num_add_line
    num_send_line = 0 if num_send_line < 0

    # ���ז��u���b�N�𑗂�
    Field.send_line(@player, num_send_line)

    return score.to_i
  end

  # ���C���������\�b�h
  def delete_line
    # �������C���T�� (�����������s�O�Ɉ�񂾂�)
    if @comp_delete == nil
      Thick_wall.upto(@field.size - Thick_wall - 1){|row|
        if @field[row].all?{|clm| clm == 1}
          @delete_line_list.push(row)
        end
      }
    end

    # �������ׂ����C��������Ƃ��̂ݎ��s
    unless @delete_line_list.empty?

      # ���������J�n
      if @delete_line_count == Delete_line_limit
        # �������C���𔒂�����
        @delete_line_list.each{|row|
          @field_color[row].fill(1)
        }

        @combo += 1
        $player_hash[@player]["score"] += cal_score(@delete_line_list.size, $player_hash[@player]["level"])   # �����ł��Ȃ���(��������������)�Œ�~�m�����������
        @delete_line_count -= 1
        @comp_delete = false

      # ������������
      elsif @delete_line_count == 0
        $player_hash[@player]["delete_line_sum"] += @delete_line_list.size
        $player_hash[@player]["count_delete_line"] += @delete_line_list.size
        # ��������
        @delete_line_list.each{|row|
          @field[row] = Array.new(Thick_wall, 1) + Array.new(@width, 0) + Array.new(Thick_wall, 1)
          @field[Thick_wall..row] = [@field[row]] + @field[Thick_wall..(row - 1)]

          # �~�m�������̏����ɒ���
          @field_color[row] = Array.new(Thick_wall, 1) + Array.new(@width, 1) + Array.new(Thick_wall, 1)
          @field_color[Thick_wall..row] = [@field_color[row]] + @field_color[Thick_wall, (Spawn_area - 1)] +
            [@field_color[Thick_wall + Spawn_area - 1].map.with_index{|color, clm|
              if clm.between?(Thick_wall, (@width_full - Thick_wall - 1)) && color == 1
                0
              else
                color
              end
            }] + @field_color[(Thick_wall + Spawn_area)..(row - 1)]
        }

        @delete_line_list.clear
        @delete_line_count = Delete_line_limit
        @comp_delete = true

        @se_delete.play

      # �����������s��
      else
        @delete_line_count -= 1
      end
    else
      # �����ׂ����C�����Ȃ��Ƃ�
      @combo = 0
    end
  end

  # �Q�[���I�[�o�[�𔻒肷�郁�\�b�h
  def check_game?
    # �o���~�m�̒�ӂ̍��W�擾
    mino_floor = $player_hash[@player]["obj_list"][1].mino.select{|cell| cell[1] == 1}.map{|cell| cell[0]}[-1][1]
    # ���b�h�]�[���z���Ă���Q�[���I�[�o�[
    if mino_floor <= Thick_wall + 2
      @game_ov = true
    end
  end

  # �Q�[�����I�������郁�\�b�h
  def game_over
    # best_score = best_score("guest", $score)

    # ���[�v���Ƀt�B�[���h��������h��Ԃ�
    unless @go_count == @field_color.size
      @field_color[- @go_count - 1].map!{|clm|
        # �c���𔒉�
        if clm != 1 && clm != 0
          @image_dead_block
        else
          clm
        end
      }
      @go_count += 1
    else
      # ���_���\��
      # Window.draw($player_hash[@player]["location_x"], $player_hash[@player]["location_y"], @image_go)
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 85, $player_hash[@player]["location_y"] + @center_y - 120, "GAME OVER", @font, :color => [46, 154, 254])
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 80, $player_hash[@player]["location_y"] + @center_y - 60, "SCORE #{$player_hash[@player]["score"]}", @font, :color => [46, 154, 254])
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 50, $player_hash[@player]["location_y"] + @center_y - 20, "LEVEL #{$player_hash[@player]["level"]}", @font, :color => [46, 154, 254])
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 50, $player_hash[@player]["location_y"] + @center_y + 20, "MINO #{$player_hash[@player]["num_drop_mino"]}", @font, :color => [46, 154, 254])
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 50, $player_hash[@player]["location_y"] + @center_y + 60, "LINE #{$player_hash[@player]["delete_line_sum"]}", @font, :color => [46, 154, 254])
      # Window.draw_font(center_x - 60, center_y + 140, "BEST SCORE #{best_score}", font_2, :color => C_BLACK)
    end

  end

  # �A�b�v�f�[�g���\�b�h
  def update
    # hold�����~�m��@delete��true�ɂȂ邪���̏ꍇ�͏��O
    unless Tetrimino.last_act(@player) == "hold"
      # @comp_delete�������ɓ���Ȃ��Ə����������p������Ȃ�
      if $player_hash[@player]["obj_list"].any?{|obj| obj.delete} || @comp_delete == false
        delete_line
      end

      if $player_hash[@player]["obj_list"].any?{|obj| obj.delete}
        check_game?
        # p Field.feature_value($player_hash[@player]["obj_list"][0].field)
      end
    end

    # �󂯎�邨�ז��u���b�N������Ƃ��̂ݎ��s
    if @num_add_line != 0
      # ���ז��u���b�N�󂯎��
      if @add_line_count == Add_line_limit
        add_line
        @add_line_count = 0
      else
        # �J�E���g����
        @add_line_count += 1
      end
    end
  end

end



# �e�g���~�m (�����~�m, NEXT�~�m(3��), HOLD�~�m)�������N���X
class Tetrimino
  attr_accessor :mino, :type, :color, :image, :image_wait, :delete
  # �~�m�̕\�����@
  # ���W�n�b�V��{�L�[��: ���W[x, y], �l: �r�b�g(1: �u���b�N����, 0: �u���b�N�Ȃ�)}�ŕ\��

  # �t�B�[���h�g�̌���, �~�m�������̌���
  Thick_wall = Field::Thick_wall
  Spawn_area = Field::Spawn_area

  # �t�B�[���h�̉E�[(�E���̘g�̍��[)�̍��W (NEXT�u���b�N�̕`��ɕK�v)
  R_end = (Field_width + Thick_wall) * Block_size
  # ����x���W
  Spawn_x = (Field_width + Thick_wall * 2) / 2 - 1
  # ����y���W
  Spawn_y =Thick_wall + 2

  # �~�m�����̂ЂȌ^�쐬 {�L�[��: ���W[x, y], �l: �r�b�g0}
  Tetrimino_cell = Hash.new
  -2.upto(2){|index_1|
    -2.upto(2){|index_2|
      Tetrimino_cell.store([Spawn_x + index_2, Spawn_y + index_1], 0)
    }
  }

  Min_fall_speed = Fps / 3    # �����������x
  Soft_drop_speed = Fps / 30    # �\�t�g�h���b�v�̗������x
  Fix_limit = Fps / 2   # �Œ莞��
  Hard_drop_point = 5   # �n�[�h�h���b�v�̊�b�_
  Soft_drop_point = 2   # �\�t�g�h���b�v�̊�b�_

  Item_list = Hash.new

  Item_list["move_list"] = Array.new
  Item_list["next_mino"] = nil   # ���ɗ�������~�m
  Item_list["mino_hold"] = nil   # HOLD�~�m
  Item_list["last_act"] = nil    # �Ō�̑��� (shift or rote or hold)
  Item_list["hold_count"] = 1    # HOLD���s�� (��������1��܂�)
  Item_list["fall_speed"] = Start_fall_speed   # �������x
  Item_list["under_block_bit"] = Array.new   # �~�m�̒�ӂ���1�u���b�N���̃}�X�̃r�b�g���
  Item_list["mode_manji"] = false    # ���[�h
  Item_list["AI_type"] = nil   # AI�̃^�C�v
  Item_list["AI_option"] = Array.new   # AI�̃I�v�V���� (hold�g������)
  Item_list["N_NW"] = nil   # AI�̃j���[�����l�b�g���[�N

  # �~�m�̃J���[�R�[�h
  Mino_color_list = {
    "I" => [88, 250, 244],
    "J" => [88, 88, 250],
    "L" => [254, 154, 46],
    "S" => [46, 254, 46],
    "Z" => [250, 88, 88],
    "T" => [250, 88, 244],
    "O" => [255, 255, 0]
  }

  # �~�m�̃u���b�N�̃e�N�X�`��
  Image_list = {}
  # NEXT, HOLD�~�m�̃e�N�X�`��
  Image_wait_list = {}

  Mino_color_list.each{|type, color|
    Image_list[type] = Image.new(Block_size, Block_size, color)
    Image_wait_list[type] = Image.new(Wait_block_size, Wait_block_size, color)
  }

  # �v���C���[���̃��X�g
  @@player_list = Array.new
  # �e�v���C���[�̃Q�[�����
  @@player_hash = Hash.new

  @@se_hold = Sound.new("#{File.dirname(__FILE__)}/sound/se_3.wav")
  @@se_fix = Sound.new("#{File.dirname(__FILE__)}/sound/se_1.wav")

  # ���������\�b�h
  # �����@player: �v���C���[��, type: �~�m�̌^ (�ԍ�, �A���t�@�x�b�g�Ŏw��)
  def initialize(player, type)
    unless @@player_list.include?(player)
      # �v���C���[���X�g�A�n�b�V���ɒǉ�
      @@player_list.push(player)
      @@player_hash[player] = Marshal.load(Marshal.dump(Item_list))
    end

    @player = player

    # �������W���ЂȌ^����R�s�[
    @mino = Marshal.load(Marshal.dump(Tetrimino_cell))
    # �~�m�̊p�x (1: �����, 2: �E90��, 3: ������, 4: ��90��)
    @angle = 1
    # �~�m���Ŕ���
    @delete = false
    # �~�m�Œ�܂ł̃J�E���g
    @fit_count = 0
    # �����\���ǂ����̔��� (false: �����\, true: �����s��)
    @unable_fall = false

    # �����Ɏw�肳��Ă��~�m�̕��ɉ����ăI�u�W�F�N�g�̏�����
    case type
    when 1, "I"
      @type = "I"   # �~�m�̌^
      @image = Image_list[@type]    # �����~�m�̃e�N�X�`��
      @image_wait = Image_wait_list[@type]   # NEXT�~�m, HOLD�~�m�̃e�N�X�`��
      # �u���b�N�̂���ӏ���1�𗧂Ă�
      @mino[[Spawn_x - 1, Spawn_y]], @mino[[Spawn_x, Spawn_y]], @mino[[Spawn_x + 1, Spawn_y]], @mino[[Spawn_x + 2, Spawn_y]] = 1, 1, 1, 1
      @mino = @mino.to_a
    when 2, "J"
      @type = "J"
      @image = Image_list[@type]
      @image_wait = Image_wait_list[@type]
      @mino[[Spawn_x - 1, Spawn_y - 1]], @mino[[Spawn_x - 1, Spawn_y]], @mino[[Spawn_x, Spawn_y]], @mino[[Spawn_x + 1, Spawn_y]] = 1, 1, 1, 1
      @mino = @mino.to_a
      # @mino[[Spawn_x + 1, Spawn_y - 2]], @mino[[Spawn_x + 2, Spawn_y - 2]], @mino[[Spawn_x - 2, Spawn_y]], @mino[[Spawn_x - 1, Spawn_y]], @mino[[Spawn_x, Spawn_y]], @mino[[Spawn_x + 1, Spawn_y]], @mino[[Spawn_x + 1, Spawn_y]], @mino[[Spawn_x - 1, Spawn_y + 1]], @mino[[Spawn_x - 2, Spawn_y + 2]] = 1, 1, 1, 1, 1, 1, 1, 1, 1
    when 3, "L"
      @type = "L"
      @image = Image_list[@type]
      @image_wait = Image_wait_list[@type]
      @mino[[Spawn_x + 1, Spawn_y - 1]], @mino[[Spawn_x - 1, Spawn_y]], @mino[[Spawn_x, Spawn_y]], @mino[[Spawn_x + 1, Spawn_y]] = 1, 1, 1, 1
      @mino = @mino.to_a
      # @mino[[Spawn_x + (-2), Spawn_y + (-2)]], @mino[[Spawn_x + (-2), Spawn_y + (-1)]], @mino[[Spawn_x + (-2), Spawn_y + (0)]], @mino[[Spawn_x + (-2), Spawn_y + (1)]], @mino[[Spawn_x + (-2), Spawn_y + (2)]], @mino[[Spawn_x + (-1), Spawn_y + (1)]], @mino[[Spawn_x + (0), Spawn_y + (0)]], @mino[[Spawn_x + (1), Spawn_y + (-1)]], @mino[[Spawn_x + (2), Spawn_y + (-2)]], @mino[[Spawn_x + (2), Spawn_y + (-1)]], @mino[[Spawn_x + (2), Spawn_y + (0)]], @mino[[Spawn_x + (2), Spawn_y + (1)]], @mino[[Spawn_x + (2), Spawn_y + (2)]] = 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    when 4, "S"
      @type = "S"
      @image = Image_list[@type]
      @image_wait = Image_wait_list[@type]
      @mino[[Spawn_x, Spawn_y - 1]], @mino[[Spawn_x + 1, Spawn_y - 1]], @mino[[Spawn_x - 1, Spawn_y]], @mino[[Spawn_x, Spawn_y]] = 1, 1, 1, 1
      @mino = @mino.to_a
      # @mino[[Spawn_x + (-2), Spawn_y + (-2)]], @mino[[Spawn_x + (-2), Spawn_y + (-1)]], @mino[[Spawn_x + (-2), Spawn_y + (0)]], @mino[[Spawn_x + (-2), Spawn_y + (2)]], @mino[[Spawn_x + (-1), Spawn_y + (0)]], @mino[[Spawn_x + (-1), Spawn_y + (2)]], @mino[[Spawn_x + (0), Spawn_y + (-2)]], @mino[[Spawn_x + (0), Spawn_y + (-1)]], @mino[[Spawn_x + (0), Spawn_y + (0)]], @mino[[Spawn_x + (0), Spawn_y + (1)]], @mino[[Spawn_x + (0), Spawn_y + (2)]], @mino[[Spawn_x + (1), Spawn_y + (-2)]], @mino[[Spawn_x + (1), Spawn_y + (0)]], @mino[[Spawn_x + (2), Spawn_y + (-2)]], @mino[[Spawn_x + (2), Spawn_y + (0)]], @mino[[Spawn_x + (2), Spawn_y + (1)]], @mino[[Spawn_x + (2), Spawn_y + (2)]] = 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    when 5, "Z"
      @type = "Z"
      @image = Image_list[@type]
      @image_wait = Image_wait_list[@type]
      # ���[�h��false�Ȃ�ʏ폈��, true�Ȃ�~�m�쐬
      unless @@player_hash[@player]["mode_manji"] == true
        @mino[[Spawn_x - 1, Spawn_y - 1]], @mino[[Spawn_x, Spawn_y - 1]], @mino[[Spawn_x, Spawn_y]], @mino[[Spawn_x + 1, Spawn_y]] = 1, 1, 1, 1
      else
        @mino[[Spawn_x + (-2), Spawn_y + (-2)]], @mino[[Spawn_x + (-1), Spawn_y + (-2)]], @mino[[Spawn_x + (0), Spawn_y + (-2)]], @mino[[Spawn_x + (2), Spawn_y + (-2)]], @mino[[Spawn_x + (0), Spawn_y + (-1)]], @mino[[Spawn_x + (2), Spawn_y + (-1)]], @mino[[Spawn_x + (-2), Spawn_y + (0)]], @mino[[Spawn_x + (-1), Spawn_y + (0)]], @mino[[Spawn_x + (0), Spawn_y + (0)]], @mino[[Spawn_x + (1), Spawn_y + (0)]], @mino[[Spawn_x + (2), Spawn_y + (0)]], @mino[[Spawn_x + (-2), Spawn_y + (1)]], @mino[[Spawn_x + (0), Spawn_y + (1)]], @mino[[Spawn_x + (-2), Spawn_y + (2)]], @mino[[Spawn_x + (0), Spawn_y + (2)]], @mino[[Spawn_x + (1), Spawn_y + (2)]], @mino[[Spawn_x + (2), Spawn_y + (2)]] = 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
      end
      @mino = @mino.to_a
    when 6, "T"
      @type = "T"
      @image = Image_list[@type]
      @image_wait = Image_wait_list[@type]
      @mino[[Spawn_x, Spawn_y - 1]], @mino[[Spawn_x - 1, Spawn_y]], @mino[[Spawn_x, Spawn_y]], @mino[[Spawn_x + 1, Spawn_y]] = 1, 1, 1, 1
      @mino = @mino.to_a
    when 7, "O"
      @type = "O"
      @image = Image_list[@type]
      @image_wait = Image_wait_list[@type]
      @mino[[Spawn_x, Spawn_y - 1]], @mino[[Spawn_x + 1, Spawn_y - 1]], @mino[[Spawn_x, Spawn_y]], @mino[[Spawn_x + 1, Spawn_y]] = 1, 1, 1, 1
      @mino = @mino.to_a
      # @mino[[Spawn_x + (-2), Spawn_y + (-2)]], @mino[[Spawn_x + (-2), Spawn_y + (-1)]], @mino[[Spawn_x + (-2), Spawn_y + (0)]], @mino[[Spawn_x + (-2), Spawn_y + (1)]], @mino[[Spawn_x + (-2), Spawn_y + (2)]], @mino[[Spawn_x + (-1), Spawn_y + (-2)]], @mino[[Spawn_x + (-1), Spawn_y + (-1)]], @mino[[Spawn_x + (-1), Spawn_y + (0)]], @mino[[Spawn_x + (-1), Spawn_y + (1)]], @mino[[Spawn_x + (-1), Spawn_y + (2)]], @mino[[Spawn_x + (0), Spawn_y + (-2)]], @mino[[Spawn_x + (0), Spawn_y + (-1)]], @mino[[Spawn_x + (0), Spawn_y + (0)]], @mino[[Spawn_x + (0), Spawn_y + (1)]], @mino[[Spawn_x + (0), Spawn_y + (2)]], @mino[[Spawn_x + (1), Spawn_y + (-2)]], @mino[[Spawn_x + (1), Spawn_y + (-1)]], @mino[[Spawn_x + (1), Spawn_y + (0)]], @mino[[Spawn_x + (1), Spawn_y + (1)]], @mino[[Spawn_x + (1), Spawn_y + (2)]], @mino[[Spawn_x + (2), Spawn_y + (-2)]], @mino[[Spawn_x + (2), Spawn_y + (-1)]], @mino[[Spawn_x + (2), Spawn_y + (0)]], @mino[[Spawn_x + (2), Spawn_y + (1)]], @mino[[Spawn_x + (2), Spawn_y + (2)]] = 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    end
  end

=begin
  def Tetrimino.set_nnw(player, chara_index)
    @@player_hash[player]["AI_type"] = G_algorithm.ai_type
    @@player_hash[player]["keep_feature_value"] = G_algorithm.feature_value

    genome = G_algorithm.select(chara_index)
    nnw = N_network.new($nnw_size, genome)
    @@player_hash[player]["N_NW"] = nnw
  end
=end

  # �v���C���[�������Z�b�g���郁�\�b�h (AI�̊w�K�ɕK�v)
  def Tetrimino.reset_player
    @@player_list.clear
    @@player_hash.clear
  end

  # AI�𐶐����郁�\�b�h
  # ���� player: �v���C���[��, name: AI�̖��O
  def Tetrimino.gene_nnw(player, name)
    # AI�̌̏��ǂݍ���
    load_data = G_algorithm.load(name)
    # AI�̃^�C�v
    @@player_hash[player]["AI_type"] = load_data["ai_type"]

    # �I�v�V����
    unless load_data["ai_option"].nil?
      @@player_hash[player]["AI_option"] = load_data["ai_option"]
    end

    # �g�p���������
    @@player_hash[player]["keep_feature_value"] = load_data["feature_value"]

    # �j���[�����l�b�g���[�N�̐���
    nnw = N_network.new(load_data["nnw_size"], load_data["genome"])
    @@player_hash[player]["N_NW"] = nnw

=begin
    @@player_hash[player]["AI_type"] = "B"
    nnw_size = {"num_input" => 330, "num_hidden" => 100, "thick_hidden" => 8, "num_output" => 6}
    nnw = N_network.new(nnw_size)
    @@player_hash[player]["N_NW"] = nnw
=end
  end

  # �~�m�̃r�b�g�����t�B�[���h�ɓ��˂��郁�\�b�h
  # ���� field: �t�B�[���h, mino: �~�m�̃r�b�g���
  # ���� ���˂����t�B�[���h
  def Tetrimino.project(field, mino)
    # �t�B�[���h�̃r�b�g�����R�s�[
    field_copy = Marshal.load(Marshal.dump(field))
    # �~�m�̍��W�ɑΉ�����t�B�[���h��̍��W�̃r�b�g��1�����Z
    mino.each{|cell|
      field_copy[cell[0][1]][cell[0][0]] += cell[1]
    }
    return field_copy
  end

  # ���������~�m���L�����ǂ������� (���̃u���b�N, �ǂɂ߂荞��łȂ���)
  # ���� tetrimino_copy: @mino�̃R�s�[
  # �Ԃ�l true: �L��, false: ����
  def Tetrimino.check?(field, tetrimino_copy)
    # �t�B�[���h�̃r�b�g�����R�s�[ (�~�m�����݂���i�̂�)
    field_copy = Marshal.load(Marshal.dump(field))[tetrimino_copy[0][0][1], 5]

    # �~�m�̍��W�ɑΉ�����t�B�[���h��̍��W�̃r�b�g��1�����Z
    tetrimino_copy.each_with_index{|cell, index|
      field_copy[index / 5][cell[0][0]] += cell[1]
    }
    # field_copy.each{|row| p row}

    field_copy.flatten!

    # �t�B�[���h��2�ȏ�̐��l�������΂��̈ړ��͖���
    if field_copy.none?{|cell| cell > 1}
      return true
    else
      return false
    end
  end

  # �~�m�̔����ʒu�ɁA�u���b�N�����邩�ǂ����𔻒肷�郁�\�b�h
  # ���� field: �t�B�[���h, tetrimino_copy: �~�m
  # �Ԃ�l true: �Q�[���I�[�o�[, false: ���s
  def Tetrimino.check_game?(field, tetrimino_copy)
    # �t�B�[���h�̃r�b�g�����R�s�[
    field_copy = Marshal.load(Marshal.dump(field))

    # �~�m�̍��W�ɑΉ�����t�B�[���h��̍��W�̃r�b�g��1�����Z
    tetrimino_copy.each{|cell|
      field_copy[cell[0][1]][cell[0][0]] += cell[1]
    }
    field_copy = field_copy[Thick_wall, Spawn_area]
    field_copy.flatten!

    # �t�B�[���h��2�ȏ�̐��l�������΂��̈ړ��͖���
    if field_copy.none?{|cell| cell > 1}
      return true
    else
      return false
    end
  end

  # ���[�h���I���ɂ��邽�߂̃��\�b�h
  def Tetrimino.mode_manji(player)
    @@player_hash[player]["mode_manji"] = true
  end

  # �I�u�W�F�N�g���X�g�ɐV�~�m��ǉ����郁�\�b�h
  def Tetrimino.push_mino(player)
    # �V�~�m�̏o���ʒu�Ɋ��Ƀu���b�N������΃Q�[���I�[�o�[
    if Tetrimino.check_game?($player_hash[player]["obj_list"][0].field, @@player_hash[player]["next_mino"].mino) == false
      $player_hash[player]["obj_list"][0].game_ov = true
    end

    $player_hash[player]["obj_list"].push(@@player_hash[player]["next_mino"])
    @@player_hash[player]["next_mino"] = nil

    # hold�g�p���͏������_��
    unless Tetrimino.last_act(player) == "hold"
      @@player_hash[player]["move_list"].clear
      $player_hash[player]["time"] = 0
    end
  end

  # �������x���Q�Ƃ��郁�\�b�h
  def Tetrimino.fall_speed(player)
    return @@player_hash[player]["fall_speed"]
  end

  # �������x��ύX���郁�\�b�h
  # �����@rate: ������
  def Tetrimino.mody_fall_speed(player, rate)
    # rate�������������x�㏸ (�����Ԋu�����߂�)
    @@player_hash[player]["fall_speed"] -= rate
  end

  # �~�m�ɑ΂���Ō�̑�����Q�Ƃ��郁�\�b�h
  def Tetrimino.last_act(player)
    return @@player_hash[player]["last_act"]
  end

  # �Ō�̑�������Z�b�g���郁�\�b�h (�����~�m��㎞�ɃN���X�O�����烊�Z�b�g���邽��)
  def Tetrimino.reset_last_act(player)
    @@player_hash[player]["last_act"] = nil
  end

  # �����~�m�`�惁�\�b�h
  def draw
    @mino.each{|cell|
      # 1�������Ă�����W�ɕ`��
      if cell[1] == 1
        Window.draw($player_hash[@player]["location_x"] + cell[0][0] * Block_size, $player_hash[@player]["location_y"] + cell[0][1] * Block_size, @image)
      end
    }
  end

  # NEXT�~�m, HOLD�~�m�̕`�惁�\�b�h
  def Tetrimino.draw_other_mino(player)
    # NEXT�~�m�̕`�� (�t�B�[���h�g�̉E�[)
    $player_hash[player]["next_mino_list"].each_with_index{|mino, index|
      position = 0
      mino.mino.each{|cell|
        if cell[1] == 1
          Window.draw($player_hash[player]["location_x"] + R_end + (position % 5) * Wait_block_size, $player_hash[player]["location_y"] + (cell[0][1] + index * 5) * Wait_block_size, mino.image_wait)
        end
        position += 1
      }
    }

    # HOLD�~�m�̕`�� (�t�B�[���h�g����)
    unless @@player_hash[player]["mino_hold"].nil?
      position = 0
      @@player_hash[player]["mino_hold"].mino.each{|cell|
        if cell[1] == 1
          Window.draw($player_hash[player]["location_x"] + (position % 5) * Wait_block_size, $player_hash[player]["location_y"] + cell[0][1] * Wait_block_size, @@player_hash[player]["mino_hold"].image_wait)
        end
        position += 1
      }
    end
  end

  # �~�m�Œ�̏��������郁�\�b�h
  def vanish
    @delete = true
    @@se_fix.play
    @@player_hash[@player]["hold_count"] = 1

    $player_hash[@player]["num_drop_mino"] += 1

    # �t�B�[���h�Ƀr�b�g��񏑂�����
    @mino.each{|cell|
      if cell[1] == 1
        $player_hash[@player]["obj_list"][0].field[cell[0][1]][cell[0][0]] = cell[1]
        $player_hash[@player]["obj_list"][0].field_color[cell[0][1]][cell[0][0]] = @image
      end
    }

    # ���̃~�m���擾
    @@player_hash[@player]["next_mino"] = $player_hash[@player]["next_mino_list"].slice!(0)
    # �~�m�{�b�N�X����Ȃ��[
    unless $player_hash[@player]["mino_box"].empty?
      $player_hash[@player]["next_mino_list"].push($player_hash[@player]["mino_box"].slice!(0))
    else
      $player_hash[@player]["mino_box"] = Array.new(7){|index| Tetrimino.new(@player, index + 1)}
      $player_hash[@player]["mino_box"].shuffle!(random: Rnd.dup)
      $player_hash[@player]["next_mino_list"].push($player_hash[@player]["mino_box"].slice!(0))
    end
  end

  # �������\�b�h
  def fall
    # �R�s�[�����~�m��y���W��1����
    tetrimino_copy = @mino.map{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
      # �`�F�b�N���\�b�h�ɂ�����, �L���Ȃ甽�f
      if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
        @mino = tetrimino_copy
        # �Œ莞�ԃJ�E���g���Z�b�g
        @fit_count = 0
        # �����\
        @unable_fall = false
      else
        @unable_fall = true
      end
  end

  # �E�ړ����\�b�h
  def shift_R
    # �R�s�[�����~�m��x���W��1����
    tetrimino_copy = @mino.map{|cell| [[cell[0][0] + 1, cell[0][1]], cell[1]]}
    # �`�F�b�N���\�b�h�ɂ�����, �L���Ȃ甽�f
    if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
      @mino = tetrimino_copy
      @@player_hash[@player]["last_act"] = "shift"
    end
  end

  # ���ړ����\�b�h
  def shift_L
    tetrimino_copy = @mino.map{|cell| [[cell[0][0] - 1, cell[0][1]], cell[1]]}
    if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
      @mino = tetrimino_copy
      @@player_hash[@player]["last_act"] = "shift"
    end
  end

  # �\�t�g�h���b�v���\�b�h
  def soft_drop
    # �R�s�[�����~�m��y���W��1����
    tetrimino_copy = @mino.map{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
    # �`�F�b�N���\�b�h�ɂ�����, �L���Ȃ甽�f
    if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
      @mino = tetrimino_copy
      # ���_���Z (��b�_ * (���x��+1))
      $player_hash[@player]["score"] += Soft_drop_point * ($player_hash[@player]["level"] + 1)
    end
  end

  # �n�[�h�h���b�v���\�b�h
  def hard_drop
    tetrimino_copy = @mino # Marshal.load(Marshal.dump(@mino))
    drop_dis = 0    # ������������

    # �`�F�b�N���\�b�h�Ŗ������肪�o��܂�y���W�𑝉���������
    while Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
      tetrimino_copy.map!{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
      drop_dis += 1
    end
    @mino = tetrimino_copy.map{|cell| [[cell[0][0], cell[0][1] - 1], cell[1]]}
    unless drop_dis == 0
      drop_dis -= 1
    end

    return drop_dis
  end

  # ��]���\�b�h
  def rote_R
    # o�^�͉�]�s��
    unless @type == "O"
      # �p�x���X�V
      unless @angle == 4
        @angle += 1
      else
        @angle = 1
      end
      # @mino�̃R�s�[, �r�b�g��0�ɂ���
      tetrimino_copy = @mino.map{|cell| [cell[0], 0]}.to_h
      tetrimino_copy_origin = @mino.to_h

      # �~�m�̍��W��񂾂����o
      tetrimino_point = tetrimino_copy.keys
      # ���S���W�擾
      rote_cent_x = tetrimino_point[12][0]
      rote_cent_y = tetrimino_point[12][1]

      # ��]���i�K
      tetrimino_copy.size.times{|index|
        rote_point_x = - tetrimino_point[index][1] + rote_cent_x + rote_cent_y
        rote_point_y = tetrimino_point[index][0] - rote_cent_x + rote_cent_y

        tetrimino_copy[[rote_point_x, rote_point_y]] = tetrimino_copy_origin[tetrimino_point[index]]
      }
      tetrimino_copy = tetrimino_copy.to_a

      # �`�F�b�N���\�b�h�ɂ����ėL���Ȃ���~�m�֔��f�A�����Ȃ��]���i�K��
      # �ȉ���]��l�i�K�܂ŌJ��Ԃ�
      if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
        @mino = tetrimino_copy
        @@player_hash[@player]["last_act"] = "rote"
      else
        # I�^�ȊO
        unless @type == "I"
          case @angle
          when 1, 2
            tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1]], cell[1]]}
          when 3, 4
            tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1]], cell[1]]}
          end

          if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
            @mino = tetrimino_copy
            @@player_hash[@player]["last_act"] = "rote"
          else
            case @angle
            when 1, 3
              tetrimino_copy.map!{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
            when 2, 4
              tetrimino_copy.map!{|cell| [[cell[0][0], cell[0][1] - 1], cell[1]]}
            end

            if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
              @mino = tetrimino_copy
              @@player_hash[@player]["last_act"] = "rote"
            else
              case @angle
              when 1
                tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1] - 3], cell[1]]}
              when 2
                tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1] + 3], cell[1]]}
              when 3
                tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1] - 3], cell[1]]}
              when 4
                tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1] + 3], cell[1]]}
              end

              if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
                @mino = tetrimino_copy
                @@player_hash[@player]["last_act"] = "rote"
              else
                case @angle
                when 1, 2
                  tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1]], cell[1]]}
                when 3, 4
                  tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1]], cell[1]]}
                end

                if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
                  @mino = tetrimino_copy
                  @@player_hash[@player]["last_act"] = "rote"
                else
                  unless @angle == 1
                    @angle -= 1
                  else
                    @angle = 4
                  end
                end
              end
            end
          end

        # I�^
        else
          case @angle
          when 1, 2
            tetrimino_copy.map!{|cell| [[cell[0][0] - 2, cell[0][1]], cell[1]]}
          when 3
            tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1]], cell[1]]}
          when 4
            tetrimino_copy.map!{|cell| [[cell[0][0] + 2, cell[0][1]], cell[1]]}
          end

          if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
            @mino = tetrimino_copy
            @@player_hash[@player]["last_act"] = "rote"
          else
            case @angle
            when 1, 2, 3
              tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1]], cell[1]]}
            when 4
              tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1]], cell[1]]}
            end

            if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
              @mino = tetrimino_copy
              @@player_hash[@player]["last_act"] = "rote"
            else
              case @angle
              when 1
                tetrimino_copy.map!{|cell| [[cell[0][0], cell[0][1] + 2], cell[1]]}
              when 2
                tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1] + 1], cell[1]]}
              when 3
                tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1] - 2], cell[1]]}
              when 4
                tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1] - 1], cell[1]]}
              end

              if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
                @mino = tetrimino_copy
                @@player_hash[@player]["last_act"] = "rote"
              else
                case @angle
                when 1
                  tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1] - 3], cell[1]]}
                when 2
                  tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1] - 3], cell[1]]}
                when 3
                  tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1] + 3], cell[1]]}
                when 4
                  tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1] + 3], cell[1]]}
                end

                if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
                  @mino = tetrimino_copy
                  @@player_hash[@player]["last_act"] = "rote"
                end

              end
            end
          end
        end
      end
    end
  end

# ����]���\�b�h (rote_R�Ɠ��l)
  def rote_L
    unless @type == "O"
      unless @angle == 1
        @angle -= 1
      else
        @angle = 4
      end
      tetrimino_copy = @mino.map{|cell| [cell[0], 0]}.to_h
      tetrimino_copy_origin = @mino.to_h

      tetrimino_point = tetrimino_copy.keys
      rote_cent_x = tetrimino_point[12][0]
      rote_cent_y = tetrimino_point[12][1]

      tetrimino_copy.size.times{|index|
        rote_point_x = tetrimino_point[index][1] + rote_cent_x - rote_cent_y
        rote_point_y = - tetrimino_point[index][0] + rote_cent_x + rote_cent_y

        tetrimino_copy[[rote_point_x, rote_point_y]] = tetrimino_copy_origin[tetrimino_point[index]]
      }
      tetrimino_copy = tetrimino_copy.to_a

      if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
        @mino = tetrimino_copy
        @@player_hash[@player]["last_act"] = "rote"
      else
        unless @type == "I"
          case @angle
          when 1, 4
            tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1]], cell[1]]}
          when 2, 3
            tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1]], cell[1]]}
          end

          if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
            @mino = tetrimino_copy
            @@player_hash[@player]["last_act"] = "rote"
          else
            case @angle
            when 1, 3
              tetrimino_copy.map!{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
            when 2, 4
              tetrimino_copy.map!{|cell| [[cell[0][0], cell[0][1] - 1], cell[1]]}
            end

            if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
              @mino = tetrimino_copy
              @@player_hash[@player]["last_act"] = "rote"
            else
              case @angle
              when 1
                tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1] - 3], cell[1]]}
              when 2
                tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1] + 3], cell[1]]}
              when 3
                tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1] - 3], cell[1]]}
              when 4
                tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1] + 3], cell[1]]}
              end

              if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
                @mino = tetrimino_copy
                @@player_hash[@player]["last_act"] = "rote"
              else
                case @angle
                when 1, 4
                  tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1]], cell[1]]}
                when 2, 3
                  tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1]], cell[1]]}
                end

                if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
                  @mino = tetrimino_copy
                  @@player_hash[@player]["last_act"] = "rote"
                else
                  unless @angle == 4
                    @angle += 1
                  else
                    @angle = 1
                  end
                end
              end
            end
          end

        else
          case @angle
          when 1
            tetrimino_copy.map!{|cell| [[cell[0][0] + 2, cell[0][1]], cell[1]]}
          when 2, 3
            tetrimino_copy.map!{|cell| [[cell[0][0] + 1, cell[0][1]], cell[1]]}
          when 4
            tetrimino_copy.map!{|cell| [[cell[0][0] - 1, cell[0][1]], cell[1]]}
          end

          if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
            @mino = tetrimino_copy
            @@player_hash[@player]["last_act"] = "rote"
          else
            case @angle
            when 1, 2, 3
              tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1]], cell[1]]}
            when 4
              tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1]], cell[1]]}
            end

            if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
              @mino = tetrimino_copy
              @@player_hash[@player]["last_act"] = "rote"
            else
              case @angle
              when 1
                tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1] - 1], cell[1]]}
              when 2
                tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1] + 2], cell[1]]}
              when 3
                tetrimino_copy.map!{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
              when 4
                tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1] - 2], cell[1]]}
              end

              if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
                @mino = tetrimino_copy
                @@player_hash[@player]["last_act"] = "rote"
              else
                case @angle
                when 1
                  tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1] + 3], cell[1]]}
                when 2
                  tetrimino_copy.map!{|cell| [[cell[0][0] - 3, cell[0][1] - 3], cell[1]]}
                when 3
                  tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1] - 3], cell[1]]}
                when 4
                  tetrimino_copy.map!{|cell| [[cell[0][0] + 3, cell[0][1] + 3], cell[1]]}
                end

                if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
                  @mino = tetrimino_copy
                  @@player_hash[@player]["last_act"] = "rote"
                end

              end
            end
          end
        end
      end
    end
  end

  # HOLD���\�b�h
  def hold
    # �^�[�����Ɉ�񂾂�HOLD��
    unless @@player_hash[@player]["hold_count"] == 0
      @@player_hash[@player]["last_act"] = "hold"
      @@player_hash[@player]["hold_count"] -= 1
      # ����HOLD
      if @@player_hash[@player]["mino_hold"].nil?
        @delete = true
        # ���̗����~�m�擾
        @@player_hash[@player]["next_mino"] = $player_hash[@player]["next_mino_list"].slice!(0)
        # ���݂̗����~�m��hold�~�m��
        @@player_hash[@player]["mino_hold"] = Tetrimino.new(@player, @type)
        # �~�m�{�b�N�X����Ȃ��[
        unless $player_hash[@player]["mino_box"].empty?   # $player_hash[@player]["next_mino_list"].push(Tetrimino.new(rand(1..7))) ����ύX
          $player_hash[@player]["next_mino_list"].push($player_hash[@player]["mino_box"].slice!(0))
        else
          $player_hash[@player]["mino_box"] = Array.new(7){|index| Tetrimino.new(@player, index + 1)}
          $player_hash[@player]["mino_box"].shuffle!(random: Rnd.dup)
          $player_hash[@player]["next_mino_list"].push($player_hash[@player]["mino_box"].slice!(0))
          $player_hash[@player]["num_drop_mino"] += 1
        end

      # ����ȍ~HOLD
      else
        @delete = true
        @@player_hash[@player]["next_mino"] = @@player_hash[@player]["mino_hold"] # Marshal.load(Marshal.dump(@@player_hash[@player]["mino_hold"]))
        @@player_hash[@player]["mino_hold"] = Tetrimino.new(@player, @type)
      end
      @@se_hold.play
    end

    # @@player_hash.each_key{|player| p @@player_hash[player]}
  end

  # AI�̃t�B�[���h�T���p�̊ȈՓI��]���\�b�h
  # ���� mino: �~�m�̃r�b�g���
  # �Ԃ�l ��]�����~�m�̃r�b�g���
  def Tetrimino.rote_R_easy(mino)
    # @mino�̃R�s�[, �r�b�g��0�ɂ���
    tetrimino_copy = mino.map{|cell| [cell[0], 0]}.to_h
    tetrimino_copy_origin = mino.to_h

    # �~�m�̍��W��񂾂����o
    tetrimino_point = tetrimino_copy.keys
    # ���S���W�擾
    rote_cent_x = tetrimino_point[12][0]
    rote_cent_y = tetrimino_point[12][1]

    # ��]
    tetrimino_copy.size.times{|index|
      rote_point_x = - tetrimino_point[index][1] + rote_cent_x + rote_cent_y
      rote_point_y = tetrimino_point[index][0] - rote_cent_x + rote_cent_y

      tetrimino_copy[[rote_point_x, rote_point_y]] = tetrimino_copy_origin[tetrimino_point[index]]
    }
    return tetrimino_copy.to_a
  end

  # �t�B�[���h�̒T�����\�b�h
  # ���� field: �t�B�[���h, mino: �~�m�I�u�W�F�N�g
  # �Ԃ�l root_list: [�T���o�H, �t�B�[���h]�̓񎟌��z��
  def Tetrimino.root(field, mino)
    # [�T���o�H, �t�B�[���h]�̓񎟌��z��
    root_list = Array.new
    # �~�m�̃r�b�g���
    mino_copy = mino.mino
    # �~�m�̌^
    type = mino.type

    # ��]
    4.times{|index|
      # �T���o�H�̓񎟌��z��
      move_list = Array.new
      if index != 0
        unless type == "o"
          mino_copy = Tetrimino.rote_R_easy(mino_copy)
          unless index == 3
            index.times{move_list.push("rote_R")}
          else
            move_list.push("rote_L")
          end
        else
          break
        end
      end

      num_move_1 = move_list.size
      # ���E�ړ�or���̂܂�
      [-1, 0, 1].each{|dx_1|
        mino_copy_2 = Marshal.load(Marshal.dump(mino_copy))
        move_list = move_list.take(num_move_1)

        num_move_2 = move_list.size
        # ���E�ւ̈ړ���
        count = 0
        loop do
          mino_copy_2.map!{|cell| [[cell[0][0] + dx_1, cell[0][1]], cell[1]]}
          if Tetrimino.check?(field, mino_copy_2) == false or dx_1 == 0 && count == 1
            break
          end

          move_list = move_list.take(num_move_2)
          if dx_1 != 0
            (count + 1).times{move_list.push("shift_#{dx_1}")}
          end

          mino_copy_3 = Marshal.load(Marshal.dump(mino_copy_2))
          # ����
          while Tetrimino.check?(field, mino_copy_3) == true
            mino_copy_3.map!{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
          end
          mino_copy_3.map!{|cell| [[cell[0][0], cell[0][1] - 1], cell[1]]}
          move_list.push("hard_drop")
          root_list.push([move_list, Tetrimino.project(field, mino_copy_3)])

          num_move_3 = move_list.size
          # ���E�ړ� (������)
          [-1, 1].each{|dx_2|
            move_list = move_list.take(num_move_3)
            mino_copy_4 = mino_copy_3.map{|cell| [[cell[0][0] + dx_2, cell[0][1]], cell[1]]}
            if Tetrimino.check?(field, mino_copy_4) == true
              move_list.push("shift_#{dx_2}")
              root_list.push([move_list, Tetrimino.project(field, mino_copy_4)])
            end
          }

          count += 1
        end
      }
    }

    # �����Ֆʂ͍폜
    root_list.uniq!{|root| root[1]}
    # root_list.each{|pear| p pear[0]}
    return root_list
  end

  # �蓮���� (�L�[�{�[�h)
  def update_human_1
    # �����s�\��
    if @unable_fall == true
      # �~�m�̈�u���b�N���̃r�b�g���擾
      @mino.each{|cell, bit|
        if bit == 1
          @@player_hash[@player]["under_block_bit"].push($player_hash[@player]["obj_list"][0].field[cell[1] + 1][cell[0]])
        end
      }
      # �~�m�̉��Z�������ׂċ󂢂Ă��Ȃ�����A�Œ菈�����s
      unless @@player_hash[@player]["under_block_bit"].all?{|bit| bit == 0}
        if @fit_count > Fix_limit
          vanish
        else
          @fit_count += 1
        end
      # �Z�����󂢂Ă�����A�����\�֕ϐ���ύX
      else
        @unable_fall = false
      end
      @@player_hash[@player]["under_block_bit"].clear
    end

    # �n�[�h�h���b�v
    if Input.key_push?(K_W)
      drop_dis = hard_drop
      # ���_���Z (��b�_ * �������� * (���x��+1))
      $player_hash[@player]["score"] += Hard_drop_point * drop_dis * ($player_hash[@player]["level"] + 1)

      vanish
    end

    # �E�ړ�
    if Input.key_push?(K_D)
      shift_R
    # ���ړ�
    elsif Input.key_push?(K_A)
      shift_L
    end

    # �\�t�g�h���b�v
    if Input.key_down?(K_S) && $player_hash[@player]["time"] % 2 == 0
      soft_drop
    end

    # �E��]
    if Input.key_push?(K_G)
      rote_R
    # ����]
    elsif Input.key_push?(K_F)
      rote_L
    end

    # �z�[���h
    if Input.key_push?(K_T)
      hold
    end

    # ���Ԋu�ŗ���
    if $player_hash[@player]["time"] %  @@player_hash[@player]["fall_speed"] == 0
      fall
    end
  end

  # �蓮���� (�e���L�[)
  def update_human_2
    if @unable_fall == true
      @mino.each{|cell, bit|
        if bit == 1
          @@player_hash[@player]["under_block_bit"].push($player_hash[@player]["obj_list"][0].field[cell[1] + 1][cell[0]])
        end
      }
      unless @@player_hash[@player]["under_block_bit"].all?{|bit| bit == 0}
        if @fit_count > Fix_limit
          vanish
        else
          @fit_count += 1
        end
      else
        @unable_fall = false
      end
      @@player_hash[@player]["under_block_bit"].clear
    end

    if Input.key_push?(K_UP)
      drop_dis = hard_drop
      # ���_���Z (��b�_ * �������� * (���x��+1))
      $player_hash[@player]["score"] += Hard_drop_point * drop_dis * ($player_hash[@player]["level"] + 1)

      vanish
    end

    if Input.key_push?(K_RIGHT)
      shift_R
    elsif Input.key_push?(K_LEFT)
      shift_L
    end

    if Input.key_down?(K_DOWN) && $player_hash[@player]["time"] % 2 == 0
      soft_drop
    end

    if Input.key_push?(K_NUMPAD2)
      rote_R
    elsif Input.key_push?(K_NUMPAD1)
      rote_L
    end

    if Input.key_push?(K_NUMPAD5)
      hold
    end

    if $player_hash[@player]["time"] %  @@player_hash[@player]["fall_speed"] == 0
      fall
    end
  end


  # AI���� (�^�C�vA)
  def update_com_A
    # ����or�O��̑��삪���������Ƃ�
    if $player_hash[@player]["time"] == 1 && @@player_hash[@player]["move_list"].empty? or $player_hash[@player]["time"] == 0

      # �t�B�[���h�T��
      root_list = Tetrimino.root($player_hash[@player]["obj_list"][0].field, $player_hash[@player]["obj_list"][-1])
      # �Ֆʎ擾
      field_list = root_list.map{|root| root[1]}

# =begin
      # hold�L�����̂݁Ahold�~�m���p���ĒT��
      if @@player_hash[@player]["AI_option"].include?("hold")
        unless @@player_hash[@player]["mino_hold"].nil?
          hold_root_list = Tetrimino.root($player_hash[@player]["obj_list"][0].field, @@player_hash[@player]["mino_hold"])
        else
          hold_root_list = Tetrimino.root($player_hash[@player]["obj_list"][0].field, $player_hash[@player]["next_mino_list"][0])
        end
        hold_root_list.map!{|root| [root[0].unshift("hold"), root[1]]}

        root_list += hold_root_list
        field_list += hold_root_list.map{|root| root[1]}
      end
# =end

      # �Ֆʂ̓��_���X�g
      score_list = Array.new
      # �e�Ֆʂ��j���[�����l�b�g���[�N��p���č̓_
      field_list.each_with_index{|field, index|
        # �����ʒ��o
        input_value_list = Field.feature_value(field)
        # �s�v�ȓ����ʍ폜
        input_value_list.keep_if{|feature_value| @@player_hash[@player]["keep_feature_value"].include?(feature_value)}
        # �̓_
        score = @@player_hash[@player]["N_NW"].input(input_value_list.values)
        score_list.push([index, score])
      }

=begin
      top_3 = score_list.sort_by{|pear| pear[1]}.reverse[0][0, 10]
      top_3.map!{|pear| pear[0]}
      top_3.flatten!

      root_2_list = []
      top_3.each{|index|
        root_2_list_each_root = Tetrimino.root(root_list[index][1], $player_hash[@player]["next_mino_list"][0])
        root_2_list += root_2_list_each_root.map!{|root| [root_list[index][0], root[1]]}
      }
      field_2_list = root_2_list.map!{|root| root[1]}

      score_list.clear
      field_list.each_with_index{|field, index|
        input_value_list = Field.feature_value(field).values
        score = @@player_hash[@player]["N_NW"].input(input_value_list)
        score_list.push([index, score])
      }
=end

      # �őP�̑����I��
      index_best = score_list.sort_by{|pear| pear[1]}.reverse[0][0]
      move_list = root_list[index_best][0]
      take_while_drop = move_list.take_while{|move| move != "hard_drop"}

      # ��]�ƈړ��̏��ԕύX
      # �n�[�h�h���b�v���O�̑��삪��]�݂̂łȂ��A���n�[�h�h���b�v���O�̑��삪��]1��łȂ��Ƃ� (��]�ȊO�ɉ�������̑��삪����Ƃ�)
      if !((take_while_drop - ["hold"]).all?{|move| move =~ /rote/}) && (take_while_drop.count("rote_R") != 1 && take_while_drop.count("rote_L") != 1)
        # hold�͍ŏ��ł���K�v�����邩��Ahold������ꍇ��else�ŏ���
        unless take_while_drop[0] == "hold"
          take_while_drop.shuffle!
          # �Ō�̑��삪��]�łȂ��Ȃ�܂ŃV���b�t��
          until take_while_drop[-1] !~ /rote/
            take_while_drop.shuffle!
          end
          move_list[0, take_while_drop.size] = take_while_drop
        else
          take_while_drop.shift
          take_while_drop.shuffle!
          until take_while_drop[-1] !~ /rote/
            take_while_drop.shuffle!
          end
          move_list[1, take_while_drop.size] = take_while_drop
        end
      end

      # root_list[index_best][1][4..-5].each{|row| p row[4, 10]}
      # p move_list
      # ���삪�m��
      @@player_hash[@player]["move_list"] = move_list
    end

    # ����J�n
    if $player_hash[@player]["time"] >= 1

      # �����\������ (�蓮���쎞�Ɠ��l)
      if @unable_fall == true
        @mino.each{|cell, bit|
          if bit == 1
            @@player_hash[@player]["under_block_bit"].push($player_hash[@player]["obj_list"][0].field[cell[1] + 1][cell[0]])
          end
        }
        unless @@player_hash[@player]["under_block_bit"].all?{|bit| bit == 0}
          if @fit_count > Fix_limit
            vanish
          else
            @fit_count += 1
          end
        else
          @unable_fall = false
        end
        @@player_hash[@player]["under_block_bit"].clear
      end

      # ���t���[������
      if $player_hash[@player]["time"] % 1 == 0
        # �z�[���h
        if @@player_hash[@player]["move_list"][0] == "hold"
          @@player_hash[@player]["move_list"].shift
          hold
        # �E��]
        elsif @@player_hash[@player]["move_list"][0] == "rote_R"
          @@player_hash[@player]["move_list"].shift
          rote_R
        # ����]
        elsif @@player_hash[@player]["move_list"][0] == "rote_L"
            @@player_hash[@player]["move_list"].shift
            rote_L
        # �E�ړ�
        elsif @@player_hash[@player]["move_list"][0] == "shift_1"
          @@player_hash[@player]["move_list"].shift
          shift_R
        # ���ړ�
        elsif @@player_hash[@player]["move_list"][0] == "shift_-1"
          @@player_hash[@player]["move_list"].shift
          shift_L

        # ����I��or���샊�X�g�Ɏw������΁A�n�[�h�h���b�v
        elsif @@player_hash[@player]["move_list"].empty? || @@player_hash[@player]["move_list"][0] == "hard_drop"
          # �n�[�h�h���b�v
          if @@player_hash[@player]["move_list"].empty? || @@player_hash[@player]["move_list"].size == 1
            @@player_hash[@player]["move_list"].clear
            drop_dis = hard_drop
            # ���_���Z (��b�_ * �������� * (���x��+1))
            $player_hash[@player]["score"] += Hard_drop_point * drop_dis * ($player_hash[@player]["level"] + 1)
            vanish
          # �\�t�g�h���b�v
          else
            @@player_hash[@player]["move_list"].shift
            hard_drop
          end
        end
      end

      # ���Ԋu�ŗ���
      if $player_hash[@player]["time"] % @@player_hash[@player]["fall_speed"] == 0
        fall
      end
    end
  end

  def update_com_B
    if $player_hash[@player]["time"] == 1 && @@player_hash[@player]["move_list"].empty? or $player_hash[@player]["time"] == 0
      input_value_list = $player_hash[@player]["obj_list"][0].field[Thick_wall..-(Thick_wall + 1)].map{|row| row[Thick_wall..-(Thick_wall + 1)]}.flatten
      input_value_list += $player_hash[@player]["obj_list"][1].mino.values
      input_value_list += $player_hash[@player]["next_mino_list"][0].mino.values
      input_value_list += $player_hash[@player]["next_mino_list"][1].mino.values

      unless @@player_hash[@player]["mino_hold"].nil?
        input_value_list += @@player_hash[@player]["mino_hold"].mino.values
      else
        input_value_list += Array.new(25, 0)
      end
      output_value_list = @@player_hash[@player]["N_NW"].input(input_value_list)

      move_list = []
      move_list.push("hold") if output_value_list[0] > 0

      case output_value_list[1].ceil
      when 1, 2
        output_value_list[1].ceil.times{move_list.push("rote_R")}
      when -1, -2
        output_value_list[1].ceil.abs.times{move_list.push("rote_L")}
      end

      case output_value_list[2].ceil
      when 1..5
        output_value_list[2].ceil.times{move_list.push("shift_R")}
      when -5..-1
        output_value_list[2].ceil.abs.times{move_list.push("shift_R")}
      end

      move_list.push("hard_drop") if output_value_list[3] > 0

      case output_value_list[4].ceil
      when 1..5
        output_value_list[4].ceil.times{move_list.push("shift_R")}
      when -5..-1
        output_value_list[4].ceil.abs.times{move_list.push("shift_R")}
      end

      case output_value_list[5].ceil
      when 1, 2
        output_value_list[5].ceil.times{move_list.push("rote_R")}
      when -1, -2
        output_value_list[5].ceil.abs.times{move_list.push("rote_L")}
      end

      @@player_hash[@player]["move_list"] = move_list
    end

    if $player_hash[@player]["time"] >= 1
      if @unable_fall == true
        @mino.each{|cell, bit|
          if bit == 1
            @@player_hash[@player]["under_block_bit"].push($player_hash[@player]["obj_list"][0].field[cell[1] + 1][cell[0]])
          end
        }
        unless @@player_hash[@player]["under_block_bit"].all?{|bit| bit == 0}
          if @fit_count > Fix_limit
            vanish
          else
            @fit_count += 1
          end
        else
          @unable_fall = false
        end
        @@player_hash[@player]["under_block_bit"].clear
      end

# =begin
      if $player_hash[@player]["time"] % 8 == 0
        if @@player_hash[@player]["move_list"].include?("hold")
          @@player_hash[@player]["move_list"].delete_at(@@player_hash[@player]["move_list"].index("hold"))
          hold
        end

        if @@player_hash[@player]["move_list"].include?("rote_R")
          @@player_hash[@player]["move_list"].delete_at(@@player_hash[@player]["move_list"].index("rote_R"))
          rote_R
        elsif @@player_hash[@player]["move_list"].include?("rote_L")
          @@player_hash[@player]["move_list"].delete_at(@@player_hash[@player]["move_list"].index("rote_L"))
          rote_L
        elsif @@player_hash[@player]["move_list"].empty? || @@player_hash[@player]["move_list"][0] == "hard_drop"
          if @@player_hash[@player]["move_list"].empty? || @@player_hash[@player]["move_list"].size == 1
            @@player_hash[@player]["move_list"].clear
            drop_dis = hard_drop
            # ���_���Z (��b�_ * �������� * (���x��+1))
            $player_hash[@player]["score"] += Hard_drop_point * drop_dis * ($player_hash[@player]["level"] + 1)
            vanish
          else
            @@player_hash[@player]["move_list"].delete_at(@@player_hash[@player]["move_list"].index("hard_drop"))
            hard_drop
          end

        elsif @@player_hash[@player]["move_list"].include?("shift_L") && @@player_hash[@player]["move_list"].include?("shift_R")
          if @@player_hash[@player]["move_list"].index("shift_L") < @@player_hash[@player]["move_list"].index("shift_R")
            @@player_hash[@player]["move_list"].delete_at(@@player_hash[@player]["move_list"].index("shift_L"))
            shift_L
          else
            @@player_hash[@player]["move_list"].delete_at(@@player_hash[@player]["move_list"].index("shift_R"))
            shift_R
          end
        elsif @@player_hash[@player]["move_list"].include?("shift_L")
          @@player_hash[@player]["move_list"].delete_at(@@player_hash[@player]["move_list"].index("shift_L"))
          shift_L
        elsif @@player_hash[@player]["move_list"].include?("shift_R")
          @@player_hash[@player]["move_list"].delete_at(@@player_hash[@player]["move_list"].index("shift_R"))
          shift_R
        end
      end
# =end

      if $player_hash[@player]["time"] % @@player_hash[@player]["fall_speed"] == 0
        fall
      end
    end
  end

  # �A�b�v�f�[�g���\�b�h
  def update
    # COM�łȂ��Ȃ�
    unless @player =~ /com/
      case @player[-1]
      when "1"
        self.update_human_1
      when "2"
        self.update_human_2
      end
    # COM
    else
      case @@player_hash[@player]["AI_type"]
      when "A"
        self.update_com_A
      when "B"
        self.update_com_B
      end
    end
  end

end

# �ꎞ��~���\�b�h
def pause
  # �t�H���g�I�u�W�F�N�g
  font = Font.new(12)

  # �ꎞ��~(update�Ȃ�)���[�v
  Window.loop do
    # �v���C���[���ƂɃ��[�v
    $player_hash.each_key{|player|
      # �I�u�W�F�N�g�`��
      $player_hash[player]["obj_list"].each{|obj|
        obj.draw
      }
      # HOLD�~�m, NEXT�~�m�̕`��
      Tetrimino.draw_other_mino(player)

      # ���F�X�\��
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 100, "SCORE #{$player_hash[player]["score"]}", font, :color => C_BLACK)
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 150, "Lv #{$player_hash[player]["level"]}", font, :color => C_BLACK)
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 170, "MINO #{$player_hash[player]["num_drop_mino"]}", font, :color => C_BLACK)
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 190, "LINE #{$player_hash[player]["delete_line_sum"]}", font, :color => C_BLACK)
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 210, "FPS #{Window.fps}", font, :color => C_BLACK)

      # �uPAUSE�v
      Window.draw_font($player_hash[player]["location_x"] + $player_hash[player]["obj_list"][0].width_px / 2 - 20, $player_hash[player]["location_y"] + $player_hash[player]["obj_list"][0].height_px / 2 - 20, "PAUSE", font, :color => C_WHITE)
      Window.draw_font($player_hash[player]["location_x"] + $player_hash[player]["obj_list"][0].width_px / 2 - 75, $player_hash[player]["location_y"] + $player_hash[player]["obj_list"][0].height_px / 2, "PRESS ESCAPE TO RESTART", font, :color => C_WHITE)
    }

    # �G�X�P�[�v�L�[�Ń��[�v������
    if Input.key_push?(K_ESCAPE)
      break
    end
  end
end

=begin
# �ߋ��̍ō����_��Ԃ�, ����̓��_���f�[�^�x�[�X�ɏ������ރ��\�b�h (���g�p)
# ���� user: ���[�U�[��, score: ����̓��_
def best_score(user, score)
  # ���o�͗p�I�u�W�F�N�g
  in_out_put = File.open("#{File.dirname(__FILE__)}/score_list/score_list.txt", "a+")
  # �f�[�^�x�[�X����S���擾
  text = in_out_put.read
  best_score = ""
  # �f�[�^�x�[�X����łȂ�����, �f�[�^�x�[�X����
  unless text.empty?
    score_list = text.chomp.split("\n").map{|line| line.split(":")}
    best_score = score_list.sort_by{|user_score| user_score[1].to_i}.reverse[0]
  end
  # ����̓��_����������
  in_out_put.print(user, ":", score, "\n")
  in_out_put.close
  return best_score[1].to_i
end
=end

# �e�v���C���[�̃Q�[�����쐬
# player_hash: {�v���C���[�� => {�e���}}�̓񎟌��n�b�V��
$player_hash = Hash.new
player_list.each{|player|
  $player_hash[player] = Hash.new

  # �t�B�[���h�쐬
  field = Field.new(player, Field_width, Field_height)
  # field.gene_terra([[0, 12], [1, 12], [2, 12], [3, 12], [8, 12], [9, 12], [0, 13], [1, 13], [2, 13], [6, 13], [7, 13], [8, 13], [9, 13], [0, 14], [1, 14], [2, 14], [3, 14], [5, 14], [6, 14], [7, 14], [8, 14], [9, 14], [0, 15], [1, 15], [5, 15], [6, 15], [7, 15], [8, 15], [9, 15], [0, 16], [1, 16], [6, 16], [7, 16], [8, 16], [9, 16], [0, 17], [1, 17], [2, 17], [3, 17], [4, 17], [6, 17], [7, 17], [8, 17], [9, 17], [0, 18], [1, 18], [2, 18], [3, 18], [6, 18], [7, 18], [8, 18], [9, 18], [0, 19], [1, 19], [2, 19], [3, 19], [4, 19], [6, 19], [7, 19], [8, 19], [9, 19]])

  # field.gene_terra([[3, 4], [4, 4], [5, 4], [5, 5], [5, 6], [5, 7], [5, 8], [6, 8], [5, 9], [6, 9], [3, 10], [4, 10], [2, 11], [4, 11], [2, 12], [4, 12], [5, 12], [2, 13], [4, 13], [5, 13], [1, 14], [4, 14], [5, 14], [1, 15], [2, 16], [3, 16], [4, 16], [5, 16], [7, 16], [8, 16], [6, 17], [7, 17]])
  # field.gene_terra([[0, 16], [1, 16], [2, 16], [3, 16], [4, 16], [5, 16], [6, 16], [7, 16], [8, 16], [0, 17], [1, 17], [2, 17], [3, 17], [4, 17], [5, 17], [6, 17], [7, 17], [8, 17], [0, 18], [1, 18], [2, 18], [3, 18], [4, 18], [5, 18], [6, 18], [7, 18], [8, 18], [0, 19], [1, 19], [2, 19], [3, 19], [4, 19], [5, 19], [6, 19], [7, 19], [8, 19]])

  # �~�m�{�b�N�X (�~�m�e��1���������z��)�쐬
  mino_box = Array.new(7){|index| Tetrimino.new(player, index + 1)}
  # �~�m�{�b�N�X���V���b�t��
  mino_box.shuffle!(random: Rnd.dup)

  # �I�u�W�F�N�g���X�g (���C�����[�v���ň����I�u�W�F�N�g(�ʏ�, �t�B�[���h�Ɨ����~�m))�쐬
  obj_list = Array.new
  # �I�u�W�F�N�g���X�g�ɃI�u�W�F�N�g�ǉ�
  obj_list.push(field, mino_box.slice!(0))

  # NEXT�~�m�z��쐬
  next_mino_list = Array.new
  3.times{
    next_mino_list.push(mino_box.slice!(0))
  }

  # ���[�h�̋N������
  if mode_manji == true
    Tetrimino.mode_manji(player)
  end

  # AI�̍쐬
  if !(com_num.nil?) && player =~ /com/
    Tetrimino.gene_nnw(player, com_list.slice!(0))
  end

  # ���[�v���J�E���g
  time = 0

  # ���_
  score = 0
  # ���x��
  level = Tetrimino::Min_fall_speed - Tetrimino.fall_speed(player)
  # �����������C���̑���
  delete_line_sum = 0
  # ���Ƃ����~�m�̑���
  num_drop_mino = 0

  # �r�����ׂ��I�u�W�F�N�g���i�[����z��
  delete_obj_list = Array.new
  # �e���x���Ԃ̃��C��������
  count_delete_line = 0

  # �e�v���C���[�̕`��J�n�ʒu
  location_x = player_list.index(player) % Num_player_per_row * field.width_px
  location_y = (player_list.index(player) / Num_player_per_row.to_f).floor * field.height_px

  # �L�[��
  item_list = ["obj_list", "next_mino_list", "mino_box", "time", "score", "level",
    "delete_line_sum", "num_drop_mino", "delete_obj_list", "count_delete_line", "location_x", "location_y"]

  # �Q�[���f�[�^�쐬
  [obj_list, next_mino_list, mino_box, time, score, level,
    delete_line_sum, num_drop_mino, delete_obj_list, count_delete_line, location_x, location_y].each_with_index{|item, index|
      $player_hash[player].store(item_list[index], item)
    }
}

# �t�H���g�I�u�W�F�N�g
font = Font.new(12)

# �E�B���h�E�̃L���v�V����, �T�C�Y, �t���[�����[�g
Window.caption = "TETRIS"

# �����̌���
# ��i�݂̂ŕ`��
if Num_player >= Num_player_per_row
  Window.width = ((Field_width + Field::Thick_wall * 2) * Block_size ) * Num_player_per_row
# ���i�ŕ`��
else
  Window.width = ((Field_width + Field::Thick_wall * 2) * Block_size ) * Num_player
end
# �c��
Window.height = (Field_height + Field::Thick_wall * 2 + Field::Spawn_area) * Block_size * (Num_player / Num_player_per_row.to_f).ceil
Window.fps = Fps

# play_time = Benchmark.realtime do
# �X�^�[�g���
Window.loop do
  # �t�B�[���h�̂ݕ`��
  $player_hash.each_key{|player|
    $player_hash[player]["obj_list"][0].draw

  # �J�n�𑣂�����
  Window.draw_font($player_hash[player]["location_x"] + $player_hash[player]["obj_list"][0].width_px / 2 - 70, $player_hash[player]["location_y"] + $player_hash[player]["obj_list"][0].height_px / 2, "PRESS ENTER TO START", font, :color => C_WHITE)
}

  # �G���^�[�L�[�Ń��[�v������
  if Input.key_push?(K_RETURN)
    break
  end
end

# �~�{�^���ŃE�B���h�E����ꂽ��v���O�����I��
if Window.closed?
  exit
end

# BGM (���g�p)
bgm = Sound.new("#{File.dirname(__FILE__)}/sound/bgm_main.wav")
bgm.loop_count = -1
# bgm.play

# ���C�����[�v�J�n
Window.loop do

  # �v���C���[���ƂɌJ��Ԃ�
  $player_hash.each_key{|player|
    # ���S�ɃQ�[���I�[�o�[���Ă��Ȃ�����
    unless $player_hash[player]["obj_list"][0].game_ov == true
      # �A�b�v�f�[�g
      $player_hash[player]["obj_list"].reverse.each{|obj| obj.update}
    end
    $player_hash[player]["obj_list"].each_with_index{|obj, index|
      # �Q�[���I�[�o�[���o���̓~�m�`�悵�Ȃ�(�ł����Ă�?)
      unless index == 1 && $player_hash[player]["obj_list"][0].game_ov == true
        obj.draw
      end

      # �������ׂ��I�u�W�F�N�g�T��
      if obj.delete == true
        $player_hash[player]["delete_obj_list"].push(obj)
      end
    }
    # HOLD�~�m, NEXT�~�m�̕`��
    Tetrimino.draw_other_mino(player) if $player_hash[player]["obj_list"][0].game_ov != true

    # �������ׂ��I�u�W�F�N�g������Ώ���
    unless $player_hash[player]["delete_obj_list"].empty?
      $player_hash[player]["obj_list"] -= $player_hash[player]["delete_obj_list"]
      # ���C������������������delete_obj_list�����
      if $player_hash[player]["obj_list"][0].comp_delete == true
        $player_hash[player]["delete_obj_list"].clear
        $player_hash[player]["obj_list"][0].comp_delete = nil
        Tetrimino.push_mino(player)
        # ���C�����������s����Ă��Ȃ��Ƃ�
      elsif $player_hash[player]["obj_list"][0].comp_delete == nil
        $player_hash[player]["delete_obj_list"].clear
        Tetrimino.push_mino(player)
        # (���C���������͉������Ȃ�)
      end
      Tetrimino.reset_last_act(player)
    end


    # ���F�X�\��
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 100, "SCORE #{$player_hash[player]["score"]}", font, :color => C_BLACK)
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 150, "Lv #{$player_hash[player]["level"]}", font, :color => C_BLACK)
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 170, "MINO #{$player_hash[player]["num_drop_mino"]}", font, :color => C_BLACK)
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 190, "LINE #{$player_hash[player]["delete_line_sum"]}", font, :color => C_BLACK)
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 210, "FPS #{Window.fps}", font, :color => C_BLACK)

    # �������C��������萔�z�����烌�x���A�b�v
    if $player_hash[player]["count_delete_line"] >= Betwen_level && Tetrimino.fall_speed(player) > 1
      $player_hash[player]["count_delete_line"] -= Betwen_level
      Tetrimino.mody_fall_speed(player, 1)
      $player_hash[player]["level"] += 1
    end

    # �Q�[���I�[�o�[���肪�o����Q�[���I��
    if $player_hash[player]["obj_list"][0].game_ov == true
      $player_hash[player]["obj_list"][0].game_over
    end

    $player_hash[player]["time"] += 1
  }

  # �G�X�P�[�v�L�[�����ꂽ��ꎞ��~
  if Input.key_push?(K_ESCAPE)
    pause
  end

end
# end
