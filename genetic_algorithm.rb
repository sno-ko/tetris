# encoding: Shift_JIS
include Math

# 遺伝的アルゴリズム (ニューラルネットワーク専用)クラス
# ニューラルネットワークの各エッジの重みを遺伝子とする
# カレントディレクトリ下にcharacterフォルダ, logフォルダを生成
class G_algorithm
  attr_reader :genome
  Per_mutate_chara = 30 # 突然変異体が発生する確率
  Per_mutate_gene = 20  # 遺伝子が突然変異する確率
  Per_spawn_clone = 30  # クローン体が発生する確率
  Per_top = 0.3 # 上位層の割合
  Per_mid = 0.7 # 中間層の割合
  Per_base = 0  # 底辺の割合
  @@ai_type = nil # AIのタイプ
  @@ai_option = Array.new # AIのオプション
  @@feature_value = nil # 使用する特徴量

  @@generation = nil  # 世代

  @@num_top = nil # 上位層の数
  @@num_mid = nil # 中間層の数
  @@num_base = nil  # 下位層の数

  @@chara_list = Array.new  # 個体リスト
  @@score_list = nil  # 各個体のスコアリスト

  # ニューラルネットワークのデータ
  @@num_input = nil
  @@num_hidden = nil
  @@thick_hidden = nil
  @@num_output = nil

  @@path_cd = nil # カレントディレクトリ

  @@index_mutate = [] # 突然変異した個体のインデックス

  @@spawn_others = false  # 外来種発生
  @@spawn_clone = false # クローン体発生

  # 初期化メソッド (各個体がインスタンス)
  # 引数 genome: 遺伝情報 (なければランダム生成)
  def initialize(genome = nil)

    # 隠れ層があるとき
    unless @@thick_hidden == 0
      # 遺伝情報なかったらランダム生成
      if genome.nil?
        genome = {
          "I-H" => Array.new(@@num_input + 1).map{Array.new(@@num_hidden).map{rand(-3.0..3.0).round(2)}},
          "H-H" => Array.new(@@thick_hidden - 1).map{Array.new(@@num_hidden + 1).map{Array.new(@@num_hidden).map{rand(-3.0..3.0).round(2)}}},
          "H-O" => Array.new(@@num_hidden + 1).map{Array.new(@@num_output).map{rand(-3.0..3.0).round(2)}}
          }
      end
    else  # 隠れ層がないとき
      # 遺伝情報なかったらランダム生成
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

  # 個体数を返すメソッド
  def G_algorithm.num_chara
    return @@num_chara
  end

  # 突然変異した個体のインデックスを返すメソッド
  def G_algorithm.mutation
    return @@index_mutate
  end

  # ニューラルネットワークのデータを返すメソッド
  def G_algorithm.nnw_size
    return {
      "num_input" => @@num_input, "num_hidden" => @@num_hidden,
      "thick_hidden" => @@thick_hidden, "num_output" => @@num_output
    }
  end

  # AIのタイプを返すメソッド
  def G_algorithm.ai_type
    return @@ai_type
  end

  # AIのオプションを返すメソッド
  def G_algorithm.ai_option
    return @@ai_option
  end

  # 使用している特徴量を返すメソッド
  def G_algorithm.feature_value
    return @@feature_value
  end

  # ニューラルネットワークのデータを受け取るメソッド
  # 引数 nnw_size: NWのデータハッシュ
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

  # 上位層の個体数を決めるメソッド
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

  # 学習をランダム状態からスタートするメソッド
  # 引数 省略
  def G_algorithm.start_new(num, ai_type, ai_option, feature_value, nnw_size, path = @@path_cd)
    # カレントディレクトリ取得
    @@path_cd = path

    # メタデータ色々取得
    @@num_chara = num
    @@ai_type = ai_type
    @@ai_option = ai_option
    @@feature_value = feature_value

    # 0世代からスタート
    @@generation = 0

    # ニューラルネットワークのサイズ取得
    G_algorithm.gain_nnw_size(nnw_size)
    # 上位個体数決定
    G_algorithm.top

    # 個体生成
    num.times{|num|
      @@chara_list.push(G_algorithm.new)
    }

    # スコアリスト
    @@score_list = Array.new
  end

  # 個体情報を文字列化するメソッド
  # 引数 index: 個体番号
  # 返り値 文字列
  def G_algorithm.write(index)
    output = ""

    # メタデータ色々記述
    output += "AI_type:#{@@ai_type}-#{@@ai_option.join("-")}\n"

    output += "NNW_size:"
    output += "#{@@num_input},#{@@num_hidden},#{@@thick_hidden},#{@@num_output}\n"

    # 特徴量はあれば書く
    unless @@feature_value.nil?
      output += "feature_value:\n#{@@feature_value.join(",")}\n"
    else
      output += "feature_value:\n\n"
    end

    # 遺伝情報
    output += "genome:\n"
    @@chara_list[index].genome.each{|item, codon_list|
      # 隠れ層以外
      unless item == "H-H"
        output += "#{item}:#{codon_list.map{|codon| codon.join(",")}.join("+")}\n"
      else  # 隠れ層
        output += "#{item}:#{codon_list.map{|codon_list_2| codon_list_2.map{|codon| codon.join(",")}.join("+")}.join("|")}\n"
      end
    }

    return output
  end

  # 個体情報を記述された文字列を解読するメソッド
  # 引数 data: 文字列
  # 返り値 read_data: 解読した結果を保存するハッシュ
  def G_algorithm.read(data)
    # 行ごとに区切るって配列に入れる
    line_list = data.chomp.split("\n")
    read_data = {"ai_type" => nil, "ai_option" => nil, "feature_value" => nil, "nnw_size" => nil, "genome" => nil}

    # AIのタイプと、あればオプション
    if line_list.any?{|line| line =~ /AI_type/}
      type_and_option = line_list[line_list.index{|line| line =~ /AI_type/}].split(":")[1].split("-")
      read_data["ai_type"] = type_and_option[0]

      unless type_and_option.size <= 1
        read_data["ai_option"] = type_and_option[1..-1]
      end

      # line_listから削除
      line_list.slice!(0..line_list.index{|line| line =~ /AI_type/})
    end

    # NWのサイズ
    if line_list.any?{|line| line =~ /NNW_size/}
      nnw_size_array = line_list[line_list.index{|line| line =~ /NNW_size/}].split(":")[1].split(",")
      line_list.slice!(0..line_list.index{|line| line =~ /NNW_size/})

      nnw_size = {"num_input" => nil, "num_hidden" => nil, "thick_hidden" => nil, "num_output" => nil}
      nnw_size.keys.zip(nnw_size_array).each{|pear|
        nnw_size[pear[0]] = pear[1].to_i
      }
      read_data["nnw_size"] = nnw_size
    end

    # 特徴量
    if line_list.any?{|line| line =~ /feature_value/}
      # 特徴量がない場合もある
      unless line_list[line_list.index{|line| line =~ /feature_value/} + 1].empty?
        read_data["feature_value"] = line_list[line_list.index{|line| line =~ /feature_value/} + 1].split(",")
      end
      line_list.slice!(0..(line_list.index{|line| line =~ /feature_value/} + 1))
    end

    line_list.delete_if{|line| line =~ /genome/}
    line_list.map!{|line| line.split(":")}
    line_list.map!{|line|
      # 隠れ層が無しの場合、空文字挿入
      if line.size == 1
        line.push("")
      else
        line
      end
    }

    # 遺伝情報取得
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

  # 個体情報をテキストファイルに出力するメソッド
  # 引数 name: 個体名
  def G_algorithm.save(name)
    # 出力先フォルダなければ作る
    unless Dir::exist?("#{@@path_cd}/characters")
      Dir.mkdir("#{@@path_cd}/characters")
    end

    # 世代数も添える
    output = File.open("#{@@path_cd}/characters/#{name}_#{@@generation}.txt", "w")
    output.print(G_algorithm.write(0))
    output.close
  end

  # 世代数を返すメソッド
  def G_algorithm.generation
    return @@generation
  end

  # 個体ごとのスコアを返すメソッド
  def G_algorithm.score_list
    # [[スコア, 個体番号]]の二次元配列 (スコアでソート)
    return @@score_list.map.with_index{|score, index| [score, index]}.sort_by{|pear| pear[0]}.reverse
  end

  # テキストファイルから個体情報を解読するメソッド
  # 引数 name: 個体名, path: カレントディレクトリ
  def G_algorithm.load(name, path = @@path_cd)
    input = File.read("#{path}/characters/#{name}.txt")
    return G_algorithm.read(input)
  end

  # 学習データをファイルに出力するメソッド
  def G_algorithm.log
    # 出力先フォルダなければ作成
    unless Dir::exist?("#{@@path_cd}/log")
      Dir.mkdir("#{@@path_cd}/log")
    end

    # メタデータファイル出力
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

    # 個体ごとにファイル作成
    @@chara_list.size.times{|index|
      output = File.open("#{@@path_cd}/log/#{index}.txt", "w")
      output.print(G_algorithm.write(index))
      output.close
    }
  end

  # ログから学習を再開するメソッド
  # 引数 path: カレントディレクトリ
  def G_algorithm.start_log(path = @@path_cd)
    @@path_cd = path

    # メタデータ色々取得
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

    # 個体生成
    @@num_chara.times{|index|
      input = File.read("#{@@path_cd}/log/#{index}.txt")
      genome_list.push(G_algorithm.read(input)["genome"])
    }
    @@chara_list = genome_list.map{|genome| G_algorithm.new(genome)}

    @@score_list = Array.new
  end

  # 指定した個体のスコアを保存するメソッド
  # 引数 index: 個体番号, score: スコア
  def G_algorithm.record(index, score)
    @@score_list[index] = score
  end

  # 指定した個体の遺伝情報を返すメソッド
  def G_algorithm.select(index)
    return @@chara_list[index].genome
  end

  # 保存した個体の名前表を返すメソッド
  # 返り値 name_list: 個体名を格納した配列
  def G_algorithm.list(path = @@path_cd)
    @@path_cd = path

    name_list = Dir.glob("#{path}/characters/*.txt")
    name_list.map!{|name| name.split("/")[-1][0..-5]}
    return name_list
  end

  # 遺伝情報をばらばらにするメソッド
  # 引数 chara: @genome (なんで名前変えた?),
  # 　　 level: 0 各層を3次元配列に
  # 　　        1 隠れ層を他の層と同じ次元に
  # 　　        2 完全に平坦化
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

  # ばらばらにした遺伝子(expand level2)を再構築するメソッド
  # 引数 array: 塩基配列,
  # 　　 level: 何段階戻すか
  def G_algorithm.build(array, level = 0)
    case level
    when 0  # expand level0の状態へ
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

    when 1  # expand level1の状態へ
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

  # 遺伝子を交配するメソッド
  def G_algorithm.mix
    @@generation += 1
    @@index_mutate.clear

    # 交配前の遺伝情報表示
    print("\n")
    @@chara_list.each_with_index{|chara, index|
      print(index, " ")
      p chara
    }
    print("\n")

    # 個体リストをスコア順にソート
    lanking = [@@chara_list, @@score_list].transpose.sort_by{|pear| pear[1]}.reverse.map{|pear| pear[0]}
    # 上位層取得
    top_list = lanking.slice!(0, @@num_top)
    # 上位層同士でペア作る
    top_pear_list = top_list.combination(2).to_a.shuffle

    # 遺伝子をコドンまでばらす
    top_pear_list_codon = top_pear_list.map{|pear| pear.map{|chara| G_algorithm.expand(chara.genome, 1)}}
    # 遺伝子を塩基までばらす
    top_pear_list_gene = top_pear_list.map{|pear| pear.map{|chara| G_algorithm.expand(chara.genome, 2)}}

    # 交配後の個体を格納する配列
    next_generation = []
    next_generation += top_list

    # 交配, 個体生成開始
    index = 0
    until next_generation.size >= @@num_chara
      # 受け継ぐ遺伝子の分配表 (小2人分)
      child_codon_list = Array.new(2).map{Array.new(top_pear_list_codon[index][0].size).map{rand(0..1)}}
      child_gene_list = Array.new(2).map{Array.new(top_pear_list_gene[index][0].size).map{rand(0..1)}}

      # 子どもごとに繰り返し
      child_codon_list.each_with_index{|child, index_2|
        # 突然変異しない
        unless rand(1..100).between?(1, Per_mutate_chara)
          codon_list = []
          # 分配表に従って遺伝情報生成
          child.each_with_index{|bit, index_3|
            codon_list.push(top_pear_list_codon[index][bit][index_3])
          }
          # ゲノム組み立て
          genome = G_algorithm.build(codon_list, 0)

        else  # 突然変異
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

    # 一定条件満たすとクローン体発生
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

    # 個体リスト更新
    @@chara_list = next_generation

    # 交配後の遺伝情報表示
    @@chara_list.each_with_index{|chara, index|
      print(index, " ")
      p chara
    }

  end

  # 個体間の類似度を計算するメソッド
  # 引数 index_1: 個体, index_2: 個体
  # 返り値 ユークリッド距離
  def G_algorithm.similarity(index_1, index_2)
    gene_list = [@@chara_list[index_1].genome.values.flatten, @@chara_list[index_2].genome.values.flatten]
    sum = 0
    gene_list.transpose.each{|gene_pear|
      sum += gene_pear.inject(:-) ** 2
    }
    simity = sqrt(sum)
    return simity
  end

  # コロニーの均質化度を計算するメソッド
  # 返り値 {average => ユークリッド距離の平均, variance => ユークリッド距離の分散}
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

  # クローン体を大量発生させ学習させるメソッド (詳細略)
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

  # 旧式交配メソッド
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
