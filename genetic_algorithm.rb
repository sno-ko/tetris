# encoding: Shift_JIS
include Math

# ��`�I�A���S���Y�� (�j���[�����l�b�g���[�N��p)�N���X
# �j���[�����l�b�g���[�N�̊e�G�b�W�̏d�݂���`�q�Ƃ���
# �J�����g�f�B���N�g������character�t�H���_, log�t�H���_�𐶐�
class G_algorithm
  attr_reader :genome
  Per_mutate_chara = 30 # �ˑR�ψّ̂���������m��
  Per_mutate_gene = 20  # ��`�q���ˑR�ψق���m��
  Per_spawn_clone = 30  # �N���[���̂���������m��
  Per_top = 0.3 # ��ʑw�̊���
  Per_mid = 0.7 # ���ԑw�̊���
  Per_base = 0  # ��ӂ̊���
  @@ai_type = nil # AI�̃^�C�v
  @@ai_option = Array.new # AI�̃I�v�V����
  @@feature_value = nil # �g�p���������

  @@generation = nil  # ����

  @@num_top = nil # ��ʑw�̐�
  @@num_mid = nil # ���ԑw�̐�
  @@num_base = nil  # ���ʑw�̐�

  @@chara_list = Array.new  # �̃��X�g
  @@score_list = nil  # �e�̂̃X�R�A���X�g

  # �j���[�����l�b�g���[�N�̃f�[�^
  @@num_input = nil
  @@num_hidden = nil
  @@thick_hidden = nil
  @@num_output = nil

  @@path_cd = nil # �J�����g�f�B���N�g��

  @@index_mutate = [] # �ˑR�ψق����̂̃C���f�b�N�X

  @@spawn_others = false  # �O���픭��
  @@spawn_clone = false # �N���[���̔���

  # ���������\�b�h (�e�̂��C���X�^���X)
  # ���� genome: ��`��� (�Ȃ���΃����_������)
  def initialize(genome = nil)

    # �B��w������Ƃ�
    unless @@thick_hidden == 0
      # ��`���Ȃ������烉���_������
      if genome.nil?
        genome = {
          "I-H" => Array.new(@@num_input + 1).map{Array.new(@@num_hidden).map{rand(-3.0..3.0).round(2)}},
          "H-H" => Array.new(@@thick_hidden - 1).map{Array.new(@@num_hidden + 1).map{Array.new(@@num_hidden).map{rand(-3.0..3.0).round(2)}}},
          "H-O" => Array.new(@@num_hidden + 1).map{Array.new(@@num_output).map{rand(-3.0..3.0).round(2)}}
          }
      end
    else  # �B��w���Ȃ��Ƃ�
      # ��`���Ȃ������烉���_������
      if genome.nil?
        genome = {
          "I-H" => Array.new(@@num_input + 1).map{Array.new(@@num_output).map{rand(-3.0..3.0).round(2)}},
          "H-H" => Array.new,
          "H-O" => Array.new
          }
      end
    end

    @genome = genome
  end

  # �̐���Ԃ����\�b�h
  def G_algorithm.num_chara
    return @@num_chara
  end

  # �ˑR�ψق����̂̃C���f�b�N�X��Ԃ����\�b�h
  def G_algorithm.mutation
    return @@index_mutate
  end

  # �j���[�����l�b�g���[�N�̃f�[�^��Ԃ����\�b�h
  def G_algorithm.nnw_size
    return {
      "num_input" => @@num_input, "num_hidden" => @@num_hidden,
      "thick_hidden" => @@thick_hidden, "num_output" => @@num_output
    }
  end

  # AI�̃^�C�v��Ԃ����\�b�h
  def G_algorithm.ai_type
    return @@ai_type
  end

  # AI�̃I�v�V������Ԃ����\�b�h
  def G_algorithm.ai_option
    return @@ai_option
  end

  # �g�p���Ă�������ʂ�Ԃ����\�b�h
  def G_algorithm.feature_value
    return @@feature_value
  end

  # �j���[�����l�b�g���[�N�̃f�[�^���󂯎�郁�\�b�h
  # ���� nnw_size: NW�̃f�[�^�n�b�V��
  def G_algorithm.gain_nnw_size(nnw_size)
    nnw_size = nnw_size.values if nnw_size.is_a?(Hash)
    @@num_input = nnw_size[0]
    unless nnw_size[1] == 0
      @@num_hidden = nnw_size[1]
    else
      @@num_hidden = nnw_size[3]
    end
    @@thick_hidden = nnw_size[2]
    @@num_output = nnw_size[3]
  end

  # ��ʑw�̌̐������߂郁�\�b�h
  def G_algorithm.top
    @@num_top = (@@num_chara * Per_top).round

    if @@num_chara % 2 == 0
      if @@num_top % 2 == 1
        @@num_top += 1
      end
    else
      if @@num_top % 2 == 0
        @@num_top += 1
      end
    end
    @@num_mid = @@num_chara - @@num_top
  end

  # �w�K�������_����Ԃ���X�^�[�g���郁�\�b�h
  # ���� �ȗ�
  def G_algorithm.start_new(num, ai_type, ai_option, feature_value, nnw_size, path = @@path_cd)
    # �J�����g�f�B���N�g���擾
    @@path_cd = path

    # ���^�f�[�^�F�X�擾
    @@num_chara = num
    @@ai_type = ai_type
    @@ai_option = ai_option
    @@feature_value = feature_value

    # 0���ォ��X�^�[�g
    @@generation = 0

    # �j���[�����l�b�g���[�N�̃T�C�Y�擾
    G_algorithm.gain_nnw_size(nnw_size)
    # ��ʌ̐�����
    G_algorithm.top

    # �̐���
    num.times{|num|
      @@chara_list.push(G_algorithm.new)
    }

    # �X�R�A���X�g
    @@score_list = Array.new
  end

  # �̏��𕶎��񉻂��郁�\�b�h
  # ���� index: �̔ԍ�
  # �Ԃ�l ������
  def G_algorithm.write(index)
    output = ""

    # ���^�f�[�^�F�X�L�q
    output += "AI_type:#{@@ai_type}-#{@@ai_option.join("-")}\n"

    output += "NNW_size:"
    output += "#{@@num_input},#{@@num_hidden},#{@@thick_hidden},#{@@num_output}\n"

    # �����ʂ͂���Ώ���
    unless @@feature_value.nil?
      output += "feature_value:\n#{@@feature_value.join(",")}\n"
    else
      output += "feature_value:\n\n"
    end

    # ��`���
    output += "genome:\n"
    @@chara_list[index].genome.each{|item, codon_list|
      # �B��w�ȊO
      unless item == "H-H"
        output += "#{item}:#{codon_list.map{|codon| codon.join(",")}.join("+")}\n"
      else  # �B��w
        output += "#{item}:#{codon_list.map{|codon_list_2| codon_list_2.map{|codon| codon.join(",")}.join("+")}.join("|")}\n"
      end
    }

    return output
  end

  # �̏����L�q���ꂽ���������ǂ��郁�\�b�h
  # ���� data: ������
  # �Ԃ�l read_data: ��ǂ������ʂ�ۑ�����n�b�V��
  def G_algorithm.read(data)
    # �s���Ƃɋ�؂���Ĕz��ɓ����
    line_list = data.chomp.split("\n")
    read_data = {"ai_type" => nil, "ai_option" => nil, "feature_value" => nil, "nnw_size" => nil, "genome" => nil}

    # AI�̃^�C�v�ƁA����΃I�v�V����
    if line_list.any?{|line| line =~ /AI_type/}
      type_and_option = line_list[line_list.index{|line| line =~ /AI_type/}].split(":")[1].split("-")
      read_data["ai_type"] = type_and_option[0]

      unless type_and_option.size <= 1
        read_data["ai_option"] = type_and_option[1..-1]
      end

      # line_list����폜
      line_list.slice!(0..line_list.index{|line| line =~ /AI_type/})
    end

    # NW�̃T�C�Y
    if line_list.any?{|line| line =~ /NNW_size/}
      nnw_size_array = line_list[line_list.index{|line| line =~ /NNW_size/}].split(":")[1].split(",")
      line_list.slice!(0..line_list.index{|line| line =~ /NNW_size/})

      nnw_size = {"num_input" => nil, "num_hidden" => nil, "thick_hidden" => nil, "num_output" => nil}
      nnw_size.keys.zip(nnw_size_array).each{|pear|
        nnw_size[pear[0]] = pear[1].to_i
      }
      read_data["nnw_size"] = nnw_size
    end

    # ������
    if line_list.any?{|line| line =~ /feature_value/}
      # �����ʂ��Ȃ��ꍇ������
      unless line_list[line_list.index{|line| line =~ /feature_value/} + 1].empty?
        read_data["feature_value"] = line_list[line_list.index{|line| line =~ /feature_value/} + 1].split(",")
      end
      line_list.slice!(0..(line_list.index{|line| line =~ /feature_value/} + 1))
    end

    line_list.delete_if{|line| line =~ /genome/}
    line_list.map!{|line| line.split(":")}
    line_list.map!{|line|
      # �B��w�������̏ꍇ�A�󕶎��}��
      if line.size == 1
        line.push("")
      else
        line
      end
    }

    # ��`���擾
    genome = {}
    line_list.each{|line|
      unless line[0] == "H-H"
        genome[line[0]] = line[1].split("+").map{|codon| codon.split(",").map{|gene| gene.to_f}}
      else
        genome[line[0]] = line[1].split("|").map{|layer| layer.split("+").map{|codon| codon.split(/,\s*/).map{|gene| gene.to_f}}}
      end
    }
    read_data["genome"] = genome

    return read_data
  end

  # �̏����e�L�X�g�t�@�C���ɏo�͂��郁�\�b�h
  # ���� name: �̖�
  def G_algorithm.save(name)
    # �o�͐�t�H���_�Ȃ���΍��
    unless Dir::exist?("#{@@path_cd}/characters")
      Dir.mkdir("#{@@path_cd}/characters")
    end

    # ���㐔���Y����
    output = File.open("#{@@path_cd}/characters/#{name}_#{@@generation}.txt", "w")
    output.print(G_algorithm.write(0))
    output.close
  end

  # ���㐔��Ԃ����\�b�h
  def G_algorithm.generation
    return @@generation
  end

  # �̂��Ƃ̃X�R�A��Ԃ����\�b�h
  def G_algorithm.score_list
    # [[�X�R�A, �̔ԍ�]]�̓񎟌��z�� (�X�R�A�Ń\�[�g)
    return @@score_list.map.with_index{|score, index| [score, index]}.sort_by{|pear| pear[0]}.reverse
  end

  # �e�L�X�g�t�@�C������̏�����ǂ��郁�\�b�h
  # ���� name: �̖�, path: �J�����g�f�B���N�g��
  def G_algorithm.load(name, path = @@path_cd)
    input = File.read("#{path}/characters/#{name}.txt")
    return G_algorithm.read(input)
  end

  # �w�K�f�[�^���t�@�C���ɏo�͂��郁�\�b�h
  def G_algorithm.log
    # �o�͐�t�H���_�Ȃ���΍쐬
    unless Dir::exist?("#{@@path_cd}/log")
      Dir.mkdir("#{@@path_cd}/log")
    end

    # ���^�f�[�^�t�@�C���o��
    output = File.open("#{@@path_cd}/log/meta.txt", "w")
    output.print("generation:#{@@generation}\n")
    output.print("AI_type:#{@@ai_type}-#{@@ai_option.join("-")}\n")
    output.print("NNW_size:#{@@num_input},#{@@num_hidden},#{@@thick_hidden},#{@@num_output}\n")
    output.print("feature_value:\n")

    unless @@feature_value.nil?
      output.print(@@feature_value.join(","), "\n")
    else
      output.print("\n")
    end
    output.close

    # �̂��ƂɃt�@�C���쐬
    @@chara_list.size.times{|index|
      output = File.open("#{@@path_cd}/log/#{index}.txt", "w")
      output.print(G_algorithm.write(index))
      output.close
    }
  end

  # ���O����w�K���ĊJ���郁�\�b�h
  # ���� path: �J�����g�f�B���N�g��
  def G_algorithm.start_log(path = @@path_cd)
    @@path_cd = path

    # ���^�f�[�^�F�X�擾
    @@num_chara = Dir.glob("#{@@path_cd}/log/*.txt").size - 1

    meta_line_list = File.read("#{@@path_cd}/log/meta.txt").chomp.split("\n")

    @@generation = meta_line_list[meta_line_list.index{|line| line =~ /generation/}].split(":")[1].chomp.to_i

    type_and_option = meta_line_list[meta_line_list.index{|line| line =~ /AI_type/}].split(":")[1].chomp.split("-")
    @@ai_type = type_and_option[0]
    unless type_and_option.size <= 1
      @@ai_option = type_and_option[1..-1]
    end

    unless meta_line_list[meta_line_list.index{|line| line =~ /feature_value/} + 1].empty?
      @@feature_value = meta_line_list[meta_line_list.index{|line| line =~ /feature_value/} + 1].chomp.split(",")
    end

    nnw_size_read_data = meta_line_list[meta_line_list.index{|line| line =~ /NNW_size/}].split(":")[1].chomp.split(",").map{|value| value.to_i}
    G_algorithm.gain_nnw_size(nnw_size_read_data)

    G_algorithm.top

    genome_list = []

    # �̐���
    @@num_chara.times{|index|
      input = File.read("#{@@path_cd}/log/#{index}.txt")
      genome_list.push(G_algorithm.read(input)["genome"])
    }
    @@chara_list = genome_list.map{|genome| G_algorithm.new(genome)}

    @@score_list = Array.new
  end

  # �w�肵���̂̃X�R�A��ۑ����郁�\�b�h
  # ���� index: �̔ԍ�, score: �X�R�A
  def G_algorithm.record(index, score)
    @@score_list[index] = score
  end

  # �w�肵���̂̈�`����Ԃ����\�b�h
  def G_algorithm.select(index)
    return @@chara_list[index].genome
  end

  # �ۑ������̖̂��O�\��Ԃ����\�b�h
  # �Ԃ�l name_list: �̖����i�[�����z��
  def G_algorithm.list(path = @@path_cd)
    @@path_cd = path

    name_list = Dir.glob("#{path}/characters/*.txt")
    name_list.map!{|name| name.split("/")[-1][0..-5]}
    return name_list
  end

  # ��`�����΂�΂�ɂ��郁�\�b�h
  # ���� chara: @genome (�Ȃ�Ŗ��O�ς���?),
  # �@�@ level: 0 �e�w��3�����z���
  # �@�@        1 �B��w�𑼂̑w�Ɠ���������
  # �@�@        2 ���S�ɕ��R��
  def G_algorithm.expand(chara, level = 0)
    case level
    when 0
      return [chara["I-H"]] + chara["H-H"] + [chara["H-O"]]
    when 1
      return ([chara["I-H"]] + chara["H-H"] + [chara["H-O"]]).flatten(1)
    when 2
      return ([chara["I-H"]] + chara["H-H"] + [chara["H-O"]]).flatten
    end
  end

  # �΂�΂�ɂ�����`�q(expand level2)���č\�z���郁�\�b�h
  # ���� array: ����z��,
  # �@�@ level: ���i�K�߂���
  def G_algorithm.build(array, level = 0)
    case level
    when 0  # expand level0�̏�Ԃ�
      i_h = array.slice!(0..@@num_input)
      h_o = []
      unless array.empty?
        h_o = array.slice!(-(@@num_hidden + 1)..-1)
      end

      h_h = []
      unless array.empty?
        h_h = array.each_slice(@@num_hidden + 1).to_a
      end

      return {"I-H" => i_h, "H-H" => h_h, "H-O" => h_o}

    when 1  # expand level1�̏�Ԃ�
      input_gene_list = array.slice!(0, (@@num_input + 1) * @@num_hidden)
      input_gene_list = input_gene_list.each_slice(@@num_hidden).to_a

      output_gene_list = []
      unless array.empty?
        output_gene_list = array.slice!(-(@@num_hidden + 1) * @@num_output..-1)
        output_gene_list = output_gene_list.each_slice(@@num_output).to_a
      end

      hidden_gene_list = []
      unless array.empty?
        hidden_gene_list = array.each_slice(@@num_hidden).each_slice(@@thick_hidden - 1).to_a
      end

      codon_list = ([input_gene_list] + hidden_gene_list + [output_gene_list]).flatten(1)
      return G_algorithm.build(codon_list, level = 0)
    end
  end

  # ��`�q����z���郁�\�b�h
  def G_algorithm.mix
    @@generation += 1
    @@index_mutate.clear

    # ��z�O�̈�`���\��
    print("\n")
    @@chara_list.each_with_index{|chara, index|
      print(index, " ")
      p chara
    }
    print("\n")

    # �̃��X�g���X�R�A���Ƀ\�[�g
    lanking = [@@chara_list, @@score_list].transpose.sort_by{|pear| pear[1]}.reverse.map{|pear| pear[0]}
    # ��ʑw�擾
    top_list = lanking.slice!(0, @@num_top)
    # ��ʑw���m�Ńy�A���
    top_pear_list = top_list.combination(2).to_a.shuffle

    # ��`�q���R�h���܂ł΂炷
    top_pear_list_codon = top_pear_list.map{|pear| pear.map{|chara| G_algorithm.expand(chara.genome, 1)}}
    # ��`�q������܂ł΂炷
    top_pear_list_gene = top_pear_list.map{|pear| pear.map{|chara| G_algorithm.expand(chara.genome, 2)}}

    # ��z��̌̂��i�[����z��
    next_generation = []
    next_generation += top_list

    # ��z, �̐����J�n
    index = 0
    until next_generation.size >= @@num_chara
      # �󂯌p����`�q�̕��z�\ (��2�l��)
      child_codon_list = Array.new(2).map{Array.new(top_pear_list_codon[index][0].size).map{rand(0..1)}}
      child_gene_list = Array.new(2).map{Array.new(top_pear_list_gene[index][0].size).map{rand(0..1)}}

      # �q�ǂ����ƂɌJ��Ԃ�
      child_codon_list.each_with_index{|child, index_2|
        # �ˑR�ψق��Ȃ�
        unless rand(1..100).between?(1, Per_mutate_chara)
          codon_list = []
          # ���z�\�ɏ]���Ĉ�`��񐶐�
          child.each_with_index{|bit, index_3|
            codon_list.push(top_pear_list_codon[index][bit][index_3])
          }
          # �Q�m���g�ݗ���
          genome = G_algorithm.build(codon_list, 0)

        else  # �ˑR�ψ�
          @@index_mutate.push(next_generation.size)

          gene_list = []
          child_gene_list[index_2].each_with_index{|bit, index_3|
            unless rand(1..100).between?(1, Per_mutate_gene)
              gene_list.push(top_pear_list_gene[index][bit][index_3])
            else
              gene_list.push(rand(-3.0..3.0).round(2))
            end
          }
          genome = G_algorithm.build(gene_list, 1)
        end

        next_generation.push(G_algorithm.new(genome))
      }

      index += 1
    end
    next_generation = next_generation.take(@@num_chara)

    # �������������ƃN���[���̔���
    if @@spawn_clone == true && @@generation > 20 && rand(1..100).between?(1, Per_spawn_clone)
      parent_gene_list = G_algorithm.expand(next_generation[0].genome, 2)
      gene_list = []
      parent_gene_list.each{|gene|
        unless rand(1..100).between?(1, Per_mutate_gene)
          gene_list.push(gene)
        else
          gene_list.push(rand(-3.0..3.0).round(2))
        end
      }
      genome = G_algorithm.build(gene_list, 1)
      next_generation[-1] = G_algorithm.new(genome)
    elsif @@spawn_others == true
      next_generation[-1] = G_algorithm.new
    end

    # �̃��X�g�X�V
    @@chara_list = next_generation

    # ��z��̈�`���\��
    @@chara_list.each_with_index{|chara, index|
      print(index, " ")
      p chara
    }

  end

  # �̊Ԃ̗ގ��x���v�Z���郁�\�b�h
  # ���� index_1: ��, index_2: ��
  # �Ԃ�l ���[�N���b�h����
  def G_algorithm.similarity(index_1, index_2)
    gene_list = [@@chara_list[index_1].genome.values.flatten, @@chara_list[index_2].genome.values.flatten]
    sum = 0
    gene_list.transpose.each{|gene_pear|
      sum += gene_pear.inject(:-) ** 2
    }
    simity = sqrt(sum)
    return simity
  end

  # �R���j�[�̋ώ����x���v�Z���郁�\�b�h
  # �Ԃ�l {average => ���[�N���b�h�����̕���, variance => ���[�N���b�h�����̕��U}
  def G_algorithm.homogeneity
    index_list = Array.new(@@num_chara){|index| index}
    pear_list = index_list.combination(2).to_a

    similarity_list = []
    pear_list.each{|pear|
      similarity_list.push(G_algorithm.similarity(pear[0], pear[1]))
    }

    ave_similarity = similarity_list.inject(:+) / similarity_list.size.to_f
    variance = similarity_list.map{|similarity| (similarity - ave_similarity) ** 2}.inject(:+) / similarity_list.size.to_f

    return {"average" => ave_similarity.round(3), "variance" => variance.round(3)}
  end

  # �N���[���̂��ʔ��������w�K�����郁�\�b�h (�ڍח�)
  def G_algorithm.start_training(index, path = @@path_cd)
    @@spawn_others = false
    @@spawn_clone = false
    @@path_cd = path
    G_algorithm.start_log

    clone_list = []
    parent_gene_list = G_algorithm.expand(@@chara_list[index].genome, 2)
    (@@num_chara - 1).times{
      gene_list = []
      parent_gene_list.each{|gene|
        unless rand(1..100).between?(1, 6)
          gene_list.push(gene)
        else
          gene_list.push(rand(-3.0..3.0).round(2))
        end
      }
      genome = G_algorithm.build(gene_list, 1)
      clone_list.push(G_algorithm.new(genome))
    }

    @@chara_list = [@@chara_list[index]] + clone_list
  end

  # ������z���\�b�h
  def G_algorithm.mix_2
    @@generation += 1

    lanking = [@@chara_list.map{|chara| chara.genome}, @@score_list].transpose.sort_by{|pear| pear[1]}.reverse.map{|pear| pear[0]}
    top_list = lanking.slice!(0, @@num_top)
    mid_list_codon = lanking.map{|chara| G_algorithm.expand(chara, 1)}.each_slice(2).to_a
    mid_list_gene = lanking.slice!(0..-1).map{|chara| G_algorithm.expand(chara, 2)}.each_slice(2).to_a

    next_generation = []
    next_generation += top_list.map{|genome| G_algorithm.new(genome)}

    mid_list_codon.each_with_index{|parent, index|

      child_codon_list = Array.new(2).map{Array.new(parent[0].size).map{rand(0..1)}}
      child_gene_list = Array.new(2).map{Array.new(mid_list_gene[index][0].size).map{rand(0..1)}}

      child_codon_list.each_with_index{|child, index_2|
        unless rand(1..100).between?(1, Per_mutate_chara)
          codon_list = []
          child.each_with_index{|bit, index_3|
            codon_list.push(parent[bit][index_3])
          }
          genome = G_algorithm.build(codon_list, 0)

        else
          gene_list = []
          child_gene_list[index_2].each_with_index{|bit, index_3|
            unless rand(1..100).between?(1, Per_mutate_gene)
              gene_list.push(mid_list_gene[index][bit][index_3])
            else
              gene_list.push(rand(-3.0..3.0).round(2))
            end
          }
          genome = G_algorithm.build(gene_list, 1)
        end

        next_generation.push(G_algorithm.new(genome))
      }
    }

    if @@spawn_clone == true && @@generation > 20 && rand(1..100).between?(1, Per_spawn_clone)
      parent_gene_list = G_algorithm.expand(next_generation[0].genome, 2)
      gene_list = []
      parent_gene_list.each{|gene|
        unless rand(1..100).between?(1, Per_mutate_gene)
          gene_list.push(gene)
        else
          gene_list.push(rand(-3.0..3.0).round(2))
        end
      }
      genome = G_algorithm.build(gene_list, 1)
      next_generation[-1] = G_algorithm.new(genome)
    elsif @@spawn_others == true
      next_generation[-1] = G_algorithm.new
    end

    @@chara_list = next_generation
  end

end
