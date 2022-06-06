# encoding: Shift_JIS
require 'dxruby'
require 'benchmark'
require "./neural_network"
require "./genetic_algorithm"

player_list = Array.new   # プレイヤーリスト
com_num = nil   # COMの数

# ゲームモード選択
# モードに応じてプレイヤーリストにプレイヤー名追加
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

# COMの選択 (COMがプレイヤーにいる場合)
unless com_num.nil?
  com_list = Array.new
  # COM名リスト (インデックス付き)
  chara_list = G_algorithm.list(File.dirname(__FILE__)).map.with_index{|chara, index| [index, chara]}

  print("selcet COM [")
  chara_list.each{|pear| print("#{pear[0] + 1}:#{pear[1]}   ")}
  print("]\n")
  com_num.times{|index|
    print("COM #{index + 1} => ")
    # インデックスで選択
    ans = gets.chomp
    unless ans.empty?
      com_list.push(chara_list[ans.to_i - 1][1])
    else
      com_list.push(chara_list[0][1])
    end
  }
end

# フィールドの横幅の設定 整数のみ有効 無効な数値の場合10に
print("width (default:10) = ")
input_width = gets.chomp
if input_width !~ /\d+/
  input_width = 10
end

# フィールドの縦幅の設定 整数のみ有効 無効な数値の場合20に
print("height (default:20) = ")
input_height = gets.chomp
if input_height !~ /\d+/
  input_height = 20
end

# 開始時レベルの設定 0~19の整数のみ有効 無効な数値の場合0に
# "manji"の場合 卍モード有効に(mode_manjiをtrueに)
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

Fps = 60    # フレームレート
Block_size = 20   # ブロックのサイズ
Wait_block_size = 12    # NEXTブロック, HOLDブロックの表示サイズ
Start_fall_speed = Fps / 3 - input_level.to_i   # 開始時の落下速度
Field_width = input_width.to_i    # フィールドの横幅
Field_height = input_height.to_i    # フィールドの縦幅
Betwen_level = 10   # レベルアップに必要なライン消去数

Rnd = Random.new   # ミノの並びを決める乱数の種

Num_player = player_list.size   # プレイヤー数
Num_player_per_row = 3   # 一段のプレイヤー数

# フィールド, フィールド枠, ツモを扱うクラス
class Field
  attr_accessor :mino, :field, :field_color, :color, :width_px, :height_px, :delete, :comp_delete, :game_ov, :num_add_line
  Thick_wall = 4    # フィールド枠の幅
  Spawn_area = 3   # ミノ発生用のスペース
  Combo_point = 1.6   # コンボの基礎点
  Delete_line_limit = Fps / 10    # ラインが消えるのにかかる時間
  Add_line_limit = Fps / 2   # お邪魔ブロックが送られるまでの時間

  # 特徴量の最大値
  @@top_height = nil   # 最大の高さ
  @@max_sum_height = nil   # 高さの総和
  @@max_delete_line = nil   # 消去の行数
  @@max_num_hole = nil   # 穴の数
  @@max_dipth_well = nil   # 井戸の深さ
  @@max_bumpiness = nil   # なだらかさ
  @@max_dipth_hole = nil   # 穴の深さの総和
  @@max_trans = nil   # ブロック有無の切り替わり回数

  # 基礎点
  Basic_socre = {"single" => 100, "double" => 300, "triple" => 500, "tetris" => 800,
    "T-spin_single" => 200, "T-spin_double" => 1200, "T-spin_triple" => 1600}

  # お邪魔ブロックの送る数
  Num_send_line = {"single" => 0, "double" => 1, "triple" => 2, "tetris" => 4,
    "T-spin_single" => 2, "T-spin_double" => 4, "T-spin_triple" => 6}

  @@line_send = Array.new   # お邪魔ブロック

  @@player_list = Array.new   # プレイヤーリスト

  # 初期化メソッド
  # 引数 player: プレイヤー名, width: フィールドの横幅, height: フィールド(ミノを置ける空間)の縦幅
  def initialize(player, width, height)
    # プレイヤーリストに追加
    @@player_list.push(player)

    # お邪魔ブロック(の素)生成
    @@line_send = Array.new((width - 1), 1).push(0)

    @player = player   # プレイヤー名
    @width = width   # 横幅
    @height = height + Spawn_area   # 縦幅 (ミノ発生部も含む)
    @width_px = (@width + Thick_wall * 2) * Block_size   # 横幅ピクセル
    @height_px = (@height + Thick_wall * 2) * Block_size   # 縦幅ピクセル

    @center_x = @width_px / 2   # 中心x座標
    @center_y = @height_px / 2   # 中心y座標

    @color = C_WHITE    # 枠の色
    @delete = false   # オブジェクト消去フラグ (false: 生存, true: 消去)
    @delete_line_count = Delete_line_limit    # ラインが消えるまでのカウント

    @num_add_line = 0   # 受け取るお邪魔ブロックのライン数
    @add_line_count = 0   # お邪魔ブロック受け取りまでのタイムリミット

    @combo = 0    # コンボ数
    @comp_delete = nil    # 消去処理の進捗状況 (nil: 消去処理なし, true: 消去処理完了, false: 消去処理実行中)
    @game_ov = false    # ゲームオーバーフラグ (true: ゲームオーバー, false: ゲーム続行)
    @go_count = 0     # フラグが立ってからゲームオーバーするまでのカウント (この間に画面白化)

    # 特徴量 (説明済)
    @@max_top_height = height.to_f
    @@max_sum_height = (width * height).to_f
    @@max_delete_line = 4.0
    @@max_num_hole = ((width / 2.0).ceil * height).to_f
    @@max_dipth_well = height.to_f
    @@max_bumpiness = (height * (width - 1)).to_f
    @@max_dipth_hole = ((width / 2.0).ceil * (height - 1) + (width / 2.0).floor * (height - 2)).to_f
    @@max_trans = ((width - 1) * height).to_f

    # ブロックの有無(ビット情報)を保存する二次元配列 (1: ブロックあり, 0: ブロックなし)
    @field = Array.new(@height + Thick_wall * 2).map{Array.new(Thick_wall, 1) + Array.new(@width, 0) + Array.new(Thick_wall, 1)}
    # ブロックの色を保存する二次元配列 (1: フィールド枠等@colorで塗る, 0: 描画無し, それ以外(カラーコード): ツモ)
    @field_color = Array.new(@height + Thick_wall * 2).map{Array.new(Thick_wall, 1) + Array.new(@width, 0) + Array.new(Thick_wall, 1)}
    # フィールド枠のビット情報を書き込み
    Thick_wall.times{|index|
      @field[index].fill(1)
      @field[-(index + 1)].fill(1)

      @field_color[index].fill(1)
      @field_color[-(index + 1)].fill(1)
    }

    # ミノの発生スペースはフィールド枠として描画
    @field_color[Thick_wall].fill(1)
    @field_color[Thick_wall + 1].fill(1)
    @field_color[Thick_wall + 2].fill(1)

    @delete_line_list = Array.new   # 消去すべきラインの列番号を格納する配列

    @font = Font.new(32)   # ゲームオーバー後のスコア表示用フォント
    @image_wall = Image.new(Block_size, Block_size, @color)   # @field_colorで1が立っている箇所の描画用image (フィールド枠のテクスチャ)
    @image_go = Image.new(@width_px, @height_px, @color)   # 背景画像
    @image_dead_block = Image.new(Block_size, Block_size, [189, 189, 189])   # 白化したブロックのテクスチャ

    @width_full = @field[0].size   # フィールド枠も含めた横幅のブロック数

    # ライン消去サウンド
    @se_delete = Sound.new("#{File.dirname(__FILE__)}/sound/se_6.wav")
    # お邪魔ブロックサウンド
    @se_add = Sound.new("#{File.dirname(__FILE__)}/sound/se_7.wav")
    # @wall_row = (0..(Thick_wall + 1)).to_a + ((@field_color.size - 3)..(@field_color.size - 1)).to_a
    # @wall_clm = (0..(Thick_wall - 1)).to_a + ((@field_color[0].size - 3)..(@field_color[0].size - 1)).to_a
  end

  # 井戸の深さを測るメソッド
  # 引数 row: 行番号, field: フィールド
  # 返り値 井戸の深さ
  def Field.measure_dipth(row, field)
    # 深さ1以上確定からスタート
    dipth = 1
    # row行目とビット情報が一致し続ける間、深さ加算
    while !(field[row + dipth].nil?) && field[row + dipth] == field[row]
      dipth += 1
    end

    return dipth
  end

  # 指定列のツモの高さを測るメソッド
  # 引数 clm: フィールドの指定列の配列 (fieldをtranspose) (0番目が最上段)
  # 返り値 ツモの高さ
  def Field.height(clm)
    # ブロックが存在するインデックスを取得
    value = clm.index(1)
    if value.nil?
      # ブロックが存在しない場合は高さ0
      return 0
    else
      # 高さ取得
      return clm.size - value
    end
  end

  # フィールド上(枠, ミノ発生部を除く)のブロックの密度を計算するメソッド
  # 返り値 密度
  def density
    return @field[(Thick_wall + Spawn_area)..-(Thick_wall + 1)].map{|row| row[Thick_wall..-(Thick_wall + 1)]}.flatten.count(1) / (@width * @height).to_f
  end

  # お邪魔ブロックを送るメソッド
  # 引数 player: 送り主のプレイヤー名, num_send_line: 送るライン数
  def Field.send_line(player, num_send_line)
    # 他プレイヤーごとに繰り返し
    (@@player_list - [player]).each{|player|
      # 他プレイヤーの@num_add_lineに加算
      $player_hash[player]["obj_list"][0].num_add_line += num_send_line
    }
  end

  # お邪魔ブロックを受け取るメソッド
  def add_line
    # 受け取るライン数繰り返し
    @num_add_line.times{
      # お邪魔ブロック生成
      add_line = @@line_send.shuffle
      # ミノ発生部の最上段を消去
      @field.delete_at(Thick_wall)
      # お邪魔ブロック1ラインを追加
      @field.insert(
        -(Thick_wall + 1), Array.new(Thick_wall, 1) + add_line + Array.new(Thick_wall, 1)
      )

      # フィールドの色空間も同様に処理
      #ただしお邪魔ブロックは1でなくimageオブジェクトであることに注意
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

  # フィールドから特徴量を抽出するメソッド
  # 引数 field: フィールド
  # 返り値 特徴量を格納したハッシュ
  def Field.feature_value(field)
    # フィールド (枠1ブロック, ミノ発生部あり)
    field_1 = field[(Thick_wall - 1)..-Thick_wall].map!{|row| row[(Thick_wall - 1)..-Thick_wall]}
    # フィールド (枠なし, ミノ発生部あり)
    field_2 = field_1[1..-2].map{|row| row[1..-2]}
    # 縦横入れ替え (枠なし, ミノ発生部あり)
    field_2_transpose = field_2.transpose

    # 各列のツモの高さリスト
    height_list = field_2_transpose.map{|clm| Field.height(clm)}

    # ツモの高さ (最大値に対する割合)
    top_height = (height_list.max / @@max_top_height.to_f) * 10

    # 穴の数変数
    num_hole = 0
    # 穴の深さ変数
    dipth_hole = 0
    # フィールド(枠なし, ミノ発生部あり)の段ごとに繰り返し (field_2を使わないのは、端の穴の検知に枠が必要なため)
    field_1[1..-2].each_with_index{|line, row|
      row += 1
      # 上段のビット情報
      line_up = field_1[row - 1]
      # 下段のビット情報
      line_low = field_1[row + 1]

      # 列ごとに繰り返し
      line[1..-2].each_with_index{|bit, clm|
        clm += 1
        # 近傍のセルのビット情報
        bit_neight = [line_up[clm], line[clm - 1], line[clm + 1], line_low[clm]]

        # 中央が0で, 近傍が全て1なら穴
        if bit == 0 && bit_neight.count(1) == 4
          # 穴の数加算
          num_hole += 1
          # 穴の深さ加算
          dipth_hole += field_2_transpose[clm - 1][0..(row - 1)].count(1)
        end
      }
    }
    # 最大値に対する割合を計算
    num_hole = (num_hole / @@max_num_hole) * 10
    dipth_hole = (dipth_hole / @@max_dipth_hole) * 10

    # 井戸の深さ変数
    dipth_well = 0
    # 行番号
    row = 0
    # 全ての行を走査
    until field_2[row].nil?
      # 一か所のみ空いている行(=井戸)を見つける
      if field_2[row].count(0) == 1 && field_2_transpose[field_2[row].index(0)][0..row - 1].all?{|bit| bit == 0}
        # 井戸の深さを計測
        dipth = Field.measure_dipth(row, field_2)
        # 測り終えたら、井戸の下段から井戸探し再開
        row += dipth
        dipth_well += dipth
      else
        row += 1
      end
    end
    # dipth_well = (dipth_well / @@max_dipth_well) * 10 - 5

    # ツモの各列の高さの総和を求め、最大値に対する割合を求める
    sum_height = (height_list.inject(:+) / @@max_sum_height) * 10

    # ビット情報の切り替わり回数 (横向き) 変数
    row_trans = 0
    # 行ごとに繰り返し
    field_2.each{|row|
      (row.size - 1).times{|clm|
        # 隣り合うセルが異なるビットのとき変数に加算
        if row[clm] != row[clm + 1]
          row_trans += 1
        end
      }
    }
    # 最大値に対するry
    row_trans = (row_trans / @@max_trans) * 10

    # ビット情報の切り替わり回数 (縦向き) 変数
    # 横向きのときと同様
    clm_trans = 0
    field_2_transpose.each{|clm|
      (clm.size - 1).times{|row|
        # print clm[row], " ", clm[row + 1], "\n"
        if clm[row] != clm[row + 1]
          clm_trans += 1
        end
      }
    }
    # 最大値に対するry
    clm_trans = (clm_trans / @@max_trans) * 10

    # 消去ライン数を最大値に対するryで計算
    delete_line = (field_2.count{|row| row.all?{|bit| bit == 1}} / 4.0) * 10

    # 各列の高さの差の絶対値を保存する配列
    diff_list = Array.new
    # 列ごと繰り返し
    (height_list.size - 1).times{|index|
      diff_list.push((height_list[index] - height_list[index + 1]).abs)
    }
    # diff_listの総和を、最大値に対するryで計算
    bumpiness = (diff_list.inject(:+) / @@max_bumpiness) * 10

    # 返り値は小数点3位まで
    return {
      "top_height" => top_height.round(3), "sum_height" => sum_height.round(3), "delete_line" => delete_line.round(3),
      "num_hole" => num_hole.round(3), "dipth_well" => dipth_well.round(3), "bumpiness" => bumpiness.round(3),
      "dipth_hole" => dipth_hole.round(3), "row_trans" => row_trans.round(3), "clm_trans" => clm_trans.round(3)
    }
  end

  # 地形編集メソッド
  # 引数 point_list: [[x座標, y座標(枠を除く)]]
  def gene_terra(point_list)
    point_list.each{|point|
      # 枠の厚さ分補正
      row = point[1] + Thick_wall + 3
      clm = point[0] + Thick_wall
      @field[row][clm] = 1
      @field_color[row][clm] = @image_dead_block
    }
  end

  # 描画メソッド
  def draw
    # @field_colorで0以外が立ってる箇所を描画
    @field_color.size.times{|row|
      @field_color[row].size.times{|clm|
        if @field_color[row][clm] == 1    # 枠部分
          Window.draw($player_hash[@player]["location_x"] + clm * Block_size, $player_hash[@player]["location_y"] + row * Block_size, @image_wall)
        elsif @field_color[row][clm] != 0   # ツモ
          Window.draw($player_hash[@player]["location_x"] + clm * Block_size, $player_hash[@player]["location_y"] + row * Block_size, @field_color[row][clm])
        end
      }
    }
  end

  # 消したラインの得点計算 & お邪魔ブロックの受け取り、送信メソッド
  # 引数 num_delete_line: 消したライン数, level: レベル
  # 返り値 得点
  def cal_score(num_delete_line, level)
    # 固定されたミノを取得
    tetrimino_copy = $player_hash[@player]["obj_list"][1]
    # T-spin判定 nil: T-spinでない, true: T-spinである
    t_spin = nil
    if tetrimino_copy.type == "T" && Tetrimino.last_act(@player) == "rote"
      tetrimino_mino = tetrimino_copy.mino.map{|cell| cell[0]}
      # 固定ミノの中心座標取得 (四隅のビットの判定のため)
      center_x = tetrimino_mino[12][0]
      center_y = tetrimino_mino[12][1]
      corner_bit = [@field[center_y - 1][center_x - 1], @field[center_y - 1][center_x + 1], @field[center_y + 1][center_x - 1], @field[center_y + 1][center_x + 1]]
      # 四隅の3か所以上がブロックあるとき
      if corner_bit.count(1) >= 3
        t_spin = true
      end
    end

    # 基礎点計算 (T-spinであるかどうか&消したライン数)
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

    # 得点計算 (基礎点 * (レベル+1) * コンボ基礎点 ** (コンボ数-1))
    score = Basic_socre[judge] * (level + 1) * Combo_point ** (@combo - 1)

    # 消したライン数だけ、受け取るお邪魔ブロック相殺
    @num_add_line -= num_delete_line
    # 受け取るお邪魔ブロックがなくなると、カウントリセット (<= 0 のほうがいい?)
    if @num_add_line < 0
      @num_add_line = 0
      @add_line_count = 0
    end

    # 送るお邪魔ブロックの計算
    num_send_line = Num_send_line[judge] - @num_add_line
    num_send_line = 0 if num_send_line < 0

    # お邪魔ブロックを送る
    Field.send_line(@player, num_send_line)

    return score.to_i
  end

  # ライン消去メソッド
  def delete_line
    # 消去ライン探す (消去処理実行前に一回だけ)
    if @comp_delete == nil
      Thick_wall.upto(@field.size - Thick_wall - 1){|row|
        if @field[row].all?{|clm| clm == 1}
          @delete_line_list.push(row)
        end
      }
    end

    # 消去すべきラインがあるときのみ実行
    unless @delete_line_list.empty?

      # 消去処理開始
      if @delete_line_count == Delete_line_limit
        # 消去ラインを白くする
        @delete_line_list.each{|row|
          @field_color[row].fill(1)
        }

        @combo += 1
        $player_hash[@player]["score"] += cal_score(@delete_line_list.size, $player_hash[@player]["level"])   # ここでしないと(消去完了時だと)固定ミノが消去される
        @delete_line_count -= 1
        @comp_delete = false

      # 消去処理完了
      elsif @delete_line_count == 0
        $player_hash[@player]["delete_line_sum"] += @delete_line_list.size
        $player_hash[@player]["count_delete_line"] += @delete_line_list.size
        # 消去処理
        @delete_line_list.each{|row|
          @field[row] = Array.new(Thick_wall, 1) + Array.new(@width, 0) + Array.new(Thick_wall, 1)
          @field[Thick_wall..row] = [@field[row]] + @field[Thick_wall..(row - 1)]

          # ミノ発生部の処理に注意
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

      # 消去処理実行中
      else
        @delete_line_count -= 1
      end
    else
      # 消すべきラインがないとき
      @combo = 0
    end
  end

  # ゲームオーバーを判定するメソッド
  def check_game?
    # 出現ミノの底辺の座標取得
    mino_floor = $player_hash[@player]["obj_list"][1].mino.select{|cell| cell[1] == 1}.map{|cell| cell[0]}[-1][1]
    # レッドゾーン越えてたらゲームオーバー
    if mino_floor <= Thick_wall + 2
      @game_ov = true
    end
  end

  # ゲームを終了させるメソッド
  def game_over
    # best_score = best_score("guest", $score)

    # ループ毎にフィールドを下から塗りつぶす
    unless @go_count == @field_color.size
      @field_color[- @go_count - 1].map!{|clm|
        # ツモを白化
        if clm != 1 && clm != 0
          @image_dead_block
        else
          clm
        end
      }
      @go_count += 1
    else
      # 得点等表示
      # Window.draw($player_hash[@player]["location_x"], $player_hash[@player]["location_y"], @image_go)
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 85, $player_hash[@player]["location_y"] + @center_y - 120, "GAME OVER", @font, :color => [46, 154, 254])
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 80, $player_hash[@player]["location_y"] + @center_y - 60, "SCORE #{$player_hash[@player]["score"]}", @font, :color => [46, 154, 254])
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 50, $player_hash[@player]["location_y"] + @center_y - 20, "LEVEL #{$player_hash[@player]["level"]}", @font, :color => [46, 154, 254])
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 50, $player_hash[@player]["location_y"] + @center_y + 20, "MINO #{$player_hash[@player]["num_drop_mino"]}", @font, :color => [46, 154, 254])
      Window.draw_font($player_hash[@player]["location_x"] + @center_x - 50, $player_hash[@player]["location_y"] + @center_y + 60, "LINE #{$player_hash[@player]["delete_line_sum"]}", @font, :color => [46, 154, 254])
      # Window.draw_font(center_x - 60, center_y + 140, "BEST SCORE #{best_score}", font_2, :color => C_BLACK)
    end

  end

  # アップデートメソッド
  def update
    # hold時もミノの@deleteがtrueになるがこの場合は除外
    unless Tetrimino.last_act(@player) == "hold"
      # @comp_deleteも条件に入れないと消去処理が継続されない
      if $player_hash[@player]["obj_list"].any?{|obj| obj.delete} || @comp_delete == false
        delete_line
      end

      if $player_hash[@player]["obj_list"].any?{|obj| obj.delete}
        check_game?
        # p Field.feature_value($player_hash[@player]["obj_list"][0].field)
      end
    end

    # 受け取るお邪魔ブロックがあるときのみ実行
    if @num_add_line != 0
      # お邪魔ブロック受け取る
      if @add_line_count == Add_line_limit
        add_line
        @add_line_count = 0
      else
        # カウント増加
        @add_line_count += 1
      end
    end
  end

end



# テトリミノ (落下ミノ, NEXTミノ(3つ), HOLDミノ)を扱うクラス
class Tetrimino
  attr_accessor :mino, :type, :color, :image, :image_wait, :delete
  # ミノの表現方法
  # 座標ハッシュ{キー名: 座標[x, y], 値: ビット(1: ブロックあり, 0: ブロックなし)}で表現

  # フィールド枠の厚さ, ミノ発生部の厚さ
  Thick_wall = Field::Thick_wall
  Spawn_area = Field::Spawn_area

  # フィールドの右端(右側の枠の左端)の座標 (NEXTブロックの描画に必要)
  R_end = (Field_width + Thick_wall) * Block_size
  # 初期x座標
  Spawn_x = (Field_width + Thick_wall * 2) / 2 - 1
  # 初期y座標
  Spawn_y =Thick_wall + 2

  # ミノ生成のひな型作成 {キー名: 座標[x, y], 値: ビット0}
  Tetrimino_cell = Hash.new
  -2.upto(2){|index_1|
    -2.upto(2){|index_2|
      Tetrimino_cell.store([Spawn_x + index_2, Spawn_y + index_1], 0)
    }
  }

  Min_fall_speed = Fps / 3    # 初期落下速度
  Soft_drop_speed = Fps / 30    # ソフトドロップの落下速度
  Fix_limit = Fps / 2   # 固定時間
  Hard_drop_point = 5   # ハードドロップの基礎点
  Soft_drop_point = 2   # ソフトドロップの基礎点

  Item_list = Hash.new

  Item_list["move_list"] = Array.new
  Item_list["next_mino"] = nil   # 次に落下するミノ
  Item_list["mino_hold"] = nil   # HOLDミノ
  Item_list["last_act"] = nil    # 最後の操作 (shift or rote or hold)
  Item_list["hold_count"] = 1    # HOLD実行回数 (落下毎に1回まで)
  Item_list["fall_speed"] = Start_fall_speed   # 落下速度
  Item_list["under_block_bit"] = Array.new   # ミノの底辺から1ブロック下のマスのビット情報
  Item_list["mode_manji"] = false    # 卍モード
  Item_list["AI_type"] = nil   # AIのタイプ
  Item_list["AI_option"] = Array.new   # AIのオプション (hold使うか等)
  Item_list["N_NW"] = nil   # AIのニューラルネットワーク

  # ミノのカラーコード
  Mino_color_list = {
    "I" => [88, 250, 244],
    "J" => [88, 88, 250],
    "L" => [254, 154, 46],
    "S" => [46, 254, 46],
    "Z" => [250, 88, 88],
    "T" => [250, 88, 244],
    "O" => [255, 255, 0]
  }

  # ミノのブロックのテクスチャ
  Image_list = {}
  # NEXT, HOLDミノのテクスチャ
  Image_wait_list = {}

  Mino_color_list.each{|type, color|
    Image_list[type] = Image.new(Block_size, Block_size, color)
    Image_wait_list[type] = Image.new(Wait_block_size, Wait_block_size, color)
  }

  # プレイヤー名のリスト
  @@player_list = Array.new
  # 各プレイヤーのゲーム情報
  @@player_hash = Hash.new

  @@se_hold = Sound.new("#{File.dirname(__FILE__)}/sound/se_3.wav")
  @@se_fix = Sound.new("#{File.dirname(__FILE__)}/sound/se_1.wav")

  # 初期化メソッド
  # 引数　player: プレイヤー名, type: ミノの型 (番号, アルファベットで指定)
  def initialize(player, type)
    unless @@player_list.include?(player)
      # プレイヤーリスト、ハッシュに追加
      @@player_list.push(player)
      @@player_hash[player] = Marshal.load(Marshal.dump(Item_list))
    end

    @player = player

    # 初期座標をひな型からコピー
    @mino = Marshal.load(Marshal.dump(Tetrimino_cell))
    # ミノの角度 (1: 上向き, 2: 右90°, 3: 下向き, 4: 左90°)
    @angle = 1
    # ミノ消滅判定
    @delete = false
    # ミノ固定までのカウント
    @fit_count = 0
    # 落下可能かどうかの判定 (false: 落下可能, true: 落下不可)
    @unable_fall = false

    # 引数に指定されてたミノの方に応じてオブジェクトの初期化
    case type
    when 1, "I"
      @type = "I"   # ミノの型
      @image = Image_list[@type]    # 落下ミノのテクスチャ
      @image_wait = Image_wait_list[@type]   # NEXTミノ, HOLDミノのテクスチャ
      # ブロックのある箇所に1を立てる
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
      # 卍モードがfalseなら通常処理, trueなら卍ミノ作成
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

  # プレイヤー情報をリセットするメソッド (AIの学習に必要)
  def Tetrimino.reset_player
    @@player_list.clear
    @@player_hash.clear
  end

  # AIを生成するメソッド
  # 引数 player: プレイヤー名, name: AIの名前
  def Tetrimino.gene_nnw(player, name)
    # AIの個体情報読み込み
    load_data = G_algorithm.load(name)
    # AIのタイプ
    @@player_hash[player]["AI_type"] = load_data["ai_type"]

    # オプション
    unless load_data["ai_option"].nil?
      @@player_hash[player]["AI_option"] = load_data["ai_option"]
    end

    # 使用する特徴量
    @@player_hash[player]["keep_feature_value"] = load_data["feature_value"]

    # ニューラルネットワークの生成
    nnw = N_network.new(load_data["nnw_size"], load_data["genome"])
    @@player_hash[player]["N_NW"] = nnw

=begin
    @@player_hash[player]["AI_type"] = "B"
    nnw_size = {"num_input" => 330, "num_hidden" => 100, "thick_hidden" => 8, "num_output" => 6}
    nnw = N_network.new(nnw_size)
    @@player_hash[player]["N_NW"] = nnw
=end
  end

  # ミノのビット情報をフィールドに投射するメソッド
  # 引数 field: フィールド, mino: ミノのビット情報
  # 引数 投射したフィールド
  def Tetrimino.project(field, mino)
    # フィールドのビット情報をコピー
    field_copy = Marshal.load(Marshal.dump(field))
    # ミノの座標に対応するフィールド上の座標のビットに1を加算
    mino.each{|cell|
      field_copy[cell[0][1]][cell[0][0]] += cell[1]
    }
    return field_copy
  end

  # 動かしたミノが有効かどうか判定 (他のブロック, 壁にめり込んでないか)
  # 引数 tetrimino_copy: @minoのコピー
  # 返り値 true: 有効, false: 無効
  def Tetrimino.check?(field, tetrimino_copy)
    # フィールドのビット情報をコピー (ミノが存在する段のみ)
    field_copy = Marshal.load(Marshal.dump(field))[tetrimino_copy[0][0][1], 5]

    # ミノの座標に対応するフィールド上の座標のビットに1を加算
    tetrimino_copy.each_with_index{|cell, index|
      field_copy[index / 5][cell[0][0]] += cell[1]
    }
    # field_copy.each{|row| p row}

    field_copy.flatten!

    # フィールドに2以上の数値が現れればその移動は無効
    if field_copy.none?{|cell| cell > 1}
      return true
    else
      return false
    end
  end

  # ミノの発生位置に、ブロックがあるかどうかを判定するメソッド
  # 引数 field: フィールド, tetrimino_copy: ミノ
  # 返り値 true: ゲームオーバー, false: 続行
  def Tetrimino.check_game?(field, tetrimino_copy)
    # フィールドのビット情報をコピー
    field_copy = Marshal.load(Marshal.dump(field))

    # ミノの座標に対応するフィールド上の座標のビットに1を加算
    tetrimino_copy.each{|cell|
      field_copy[cell[0][1]][cell[0][0]] += cell[1]
    }
    field_copy = field_copy[Thick_wall, Spawn_area]
    field_copy.flatten!

    # フィールドに2以上の数値が現れればその移動は無効
    if field_copy.none?{|cell| cell > 1}
      return true
    else
      return false
    end
  end

  # 卍モードをオンにするためのメソッド
  def Tetrimino.mode_manji(player)
    @@player_hash[player]["mode_manji"] = true
  end

  # オブジェクトリストに新ミノを追加するメソッド
  def Tetrimino.push_mino(player)
    # 新ミノの出現位置に既にブロックがあればゲームオーバー
    if Tetrimino.check_game?($player_hash[player]["obj_list"][0].field, @@player_hash[player]["next_mino"].mino) == false
      $player_hash[player]["obj_list"][0].game_ov = true
    end

    $player_hash[player]["obj_list"].push(@@player_hash[player]["next_mino"])
    @@player_hash[player]["next_mino"] = nil

    # hold使用時は初期化ダメ
    unless Tetrimino.last_act(player) == "hold"
      @@player_hash[player]["move_list"].clear
      $player_hash[player]["time"] = 0
    end
  end

  # 落下速度を参照するメソッド
  def Tetrimino.fall_speed(player)
    return @@player_hash[player]["fall_speed"]
  end

  # 落下速度を変更するメソッド
  # 引数　rate: 増加量
  def Tetrimino.mody_fall_speed(player, rate)
    # rate分だけ落下速度上昇 (落下間隔を狭める)
    @@player_hash[player]["fall_speed"] -= rate
  end

  # ミノに対する最後の操作を参照するメソッド
  def Tetrimino.last_act(player)
    return @@player_hash[player]["last_act"]
  end

  # 最後の操作をリセットするメソッド (落下ミノ交代時にクラス外部からリセットするため)
  def Tetrimino.reset_last_act(player)
    @@player_hash[player]["last_act"] = nil
  end

  # 落下ミノ描画メソッド
  def draw
    @mino.each{|cell|
      # 1が立っている座標に描画
      if cell[1] == 1
        Window.draw($player_hash[@player]["location_x"] + cell[0][0] * Block_size, $player_hash[@player]["location_y"] + cell[0][1] * Block_size, @image)
      end
    }
  end

  # NEXTミノ, HOLDミノの描画メソッド
  def Tetrimino.draw_other_mino(player)
    # NEXTミノの描画 (フィールド枠の右端)
    $player_hash[player]["next_mino_list"].each_with_index{|mino, index|
      position = 0
      mino.mino.each{|cell|
        if cell[1] == 1
          Window.draw($player_hash[player]["location_x"] + R_end + (position % 5) * Wait_block_size, $player_hash[player]["location_y"] + (cell[0][1] + index * 5) * Wait_block_size, mino.image_wait)
        end
        position += 1
      }
    }

    # HOLDミノの描画 (フィールド枠左上)
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

  # ミノ固定の処理をするメソッド
  def vanish
    @delete = true
    @@se_fix.play
    @@player_hash[@player]["hold_count"] = 1

    $player_hash[@player]["num_drop_mino"] += 1

    # フィールドにビット情報書き込み
    @mino.each{|cell|
      if cell[1] == 1
        $player_hash[@player]["obj_list"][0].field[cell[0][1]][cell[0][0]] = cell[1]
        $player_hash[@player]["obj_list"][0].field_color[cell[0][1]][cell[0][0]] = @image
      end
    }

    # 次のミノを取得
    @@player_hash[@player]["next_mino"] = $player_hash[@player]["next_mino_list"].slice!(0)
    # ミノボックスが空なら補充
    unless $player_hash[@player]["mino_box"].empty?
      $player_hash[@player]["next_mino_list"].push($player_hash[@player]["mino_box"].slice!(0))
    else
      $player_hash[@player]["mino_box"] = Array.new(7){|index| Tetrimino.new(@player, index + 1)}
      $player_hash[@player]["mino_box"].shuffle!(random: Rnd.dup)
      $player_hash[@player]["next_mino_list"].push($player_hash[@player]["mino_box"].slice!(0))
    end
  end

  # 落下メソッド
  def fall
    # コピーしたミノのy座標を1増加
    tetrimino_copy = @mino.map{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
      # チェックメソッドにかけて, 有効なら反映
      if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
        @mino = tetrimino_copy
        # 固定時間カウントリセット
        @fit_count = 0
        # 落下可能
        @unable_fall = false
      else
        @unable_fall = true
      end
  end

  # 右移動メソッド
  def shift_R
    # コピーしたミノのx座標を1増加
    tetrimino_copy = @mino.map{|cell| [[cell[0][0] + 1, cell[0][1]], cell[1]]}
    # チェックメソッドにかけて, 有効なら反映
    if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
      @mino = tetrimino_copy
      @@player_hash[@player]["last_act"] = "shift"
    end
  end

  # 左移動メソッド
  def shift_L
    tetrimino_copy = @mino.map{|cell| [[cell[0][0] - 1, cell[0][1]], cell[1]]}
    if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
      @mino = tetrimino_copy
      @@player_hash[@player]["last_act"] = "shift"
    end
  end

  # ソフトドロップメソッド
  def soft_drop
    # コピーしたミノのy座標を1増加
    tetrimino_copy = @mino.map{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
    # チェックメソッドにかけて, 有効なら反映
    if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
      @mino = tetrimino_copy
      # 得点加算 (基礎点 * (レベル+1))
      $player_hash[@player]["score"] += Soft_drop_point * ($player_hash[@player]["level"] + 1)
    end
  end

  # ハードドロップメソッド
  def hard_drop
    tetrimino_copy = @mino # Marshal.load(Marshal.dump(@mino))
    drop_dis = 0    # 落下距離測定

    # チェックメソッドで無効判定が出るまでy座標を増加し続ける
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

  # 回転メソッド
  def rote_R
    # o型は回転不可
    unless @type == "O"
      # 角度情報更新
      unless @angle == 4
        @angle += 1
      else
        @angle = 1
      end
      # @minoのコピー, ビットを0にする
      tetrimino_copy = @mino.map{|cell| [cell[0], 0]}.to_h
      tetrimino_copy_origin = @mino.to_h

      # ミノの座標情報だけ抽出
      tetrimino_point = tetrimino_copy.keys
      # 中心座標取得
      rote_cent_x = tetrimino_point[12][0]
      rote_cent_y = tetrimino_point[12][1]

      # 回転第一段階
      tetrimino_copy.size.times{|index|
        rote_point_x = - tetrimino_point[index][1] + rote_cent_x + rote_cent_y
        rote_point_y = tetrimino_point[index][0] - rote_cent_x + rote_cent_y

        tetrimino_copy[[rote_point_x, rote_point_y]] = tetrimino_copy_origin[tetrimino_point[index]]
      }
      tetrimino_copy = tetrimino_copy.to_a

      # チェックメソッドにかけて有効なら実ミノへ反映、無効なら回転第二段階へ
      # 以下回転第四段階まで繰り返し
      if Tetrimino.check?($player_hash[@player]["obj_list"][0].field, tetrimino_copy) == true
        @mino = tetrimino_copy
        @@player_hash[@player]["last_act"] = "rote"
      else
        # I型以外
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

        # I型
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

# 左回転メソッド (rote_Rと同様)
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

  # HOLDメソッド
  def hold
    # ターン毎に一回だけHOLD可
    unless @@player_hash[@player]["hold_count"] == 0
      @@player_hash[@player]["last_act"] = "hold"
      @@player_hash[@player]["hold_count"] -= 1
      # 初回HOLD
      if @@player_hash[@player]["mino_hold"].nil?
        @delete = true
        # 次の落下ミノ取得
        @@player_hash[@player]["next_mino"] = $player_hash[@player]["next_mino_list"].slice!(0)
        # 現在の落下ミノをholdミノへ
        @@player_hash[@player]["mino_hold"] = Tetrimino.new(@player, @type)
        # ミノボックスが空なら補充
        unless $player_hash[@player]["mino_box"].empty?   # $player_hash[@player]["next_mino_list"].push(Tetrimino.new(rand(1..7))) から変更
          $player_hash[@player]["next_mino_list"].push($player_hash[@player]["mino_box"].slice!(0))
        else
          $player_hash[@player]["mino_box"] = Array.new(7){|index| Tetrimino.new(@player, index + 1)}
          $player_hash[@player]["mino_box"].shuffle!(random: Rnd.dup)
          $player_hash[@player]["next_mino_list"].push($player_hash[@player]["mino_box"].slice!(0))
          $player_hash[@player]["num_drop_mino"] += 1
        end

      # 初回以降HOLD
      else
        @delete = true
        @@player_hash[@player]["next_mino"] = @@player_hash[@player]["mino_hold"] # Marshal.load(Marshal.dump(@@player_hash[@player]["mino_hold"]))
        @@player_hash[@player]["mino_hold"] = Tetrimino.new(@player, @type)
      end
      @@se_hold.play
    end

    # @@player_hash.each_key{|player| p @@player_hash[player]}
  end

  # AIのフィールド探索用の簡易的回転メソッド
  # 引数 mino: ミノのビット情報
  # 返り値 回転したミノのビット情報
  def Tetrimino.rote_R_easy(mino)
    # @minoのコピー, ビットを0にする
    tetrimino_copy = mino.map{|cell| [cell[0], 0]}.to_h
    tetrimino_copy_origin = mino.to_h

    # ミノの座標情報だけ抽出
    tetrimino_point = tetrimino_copy.keys
    # 中心座標取得
    rote_cent_x = tetrimino_point[12][0]
    rote_cent_y = tetrimino_point[12][1]

    # 回転
    tetrimino_copy.size.times{|index|
      rote_point_x = - tetrimino_point[index][1] + rote_cent_x + rote_cent_y
      rote_point_y = tetrimino_point[index][0] - rote_cent_x + rote_cent_y

      tetrimino_copy[[rote_point_x, rote_point_y]] = tetrimino_copy_origin[tetrimino_point[index]]
    }
    return tetrimino_copy.to_a
  end

  # フィールドの探索メソッド
  # 引数 field: フィールド, mino: ミノオブジェクト
  # 返り値 root_list: [探索経路, フィールド]の二次元配列
  def Tetrimino.root(field, mino)
    # [探索経路, フィールド]の二次元配列
    root_list = Array.new
    # ミノのビット情報
    mino_copy = mino.mino
    # ミノの型
    type = mino.type

    # 回転
    4.times{|index|
      # 探索経路の二次元配列
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
      # 左右移動orそのまま
      [-1, 0, 1].each{|dx_1|
        mino_copy_2 = Marshal.load(Marshal.dump(mino_copy))
        move_list = move_list.take(num_move_1)

        num_move_2 = move_list.size
        # 左右への移動回数
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
          # 落下
          while Tetrimino.check?(field, mino_copy_3) == true
            mino_copy_3.map!{|cell| [[cell[0][0], cell[0][1] + 1], cell[1]]}
          end
          mino_copy_3.map!{|cell| [[cell[0][0], cell[0][1] - 1], cell[1]]}
          move_list.push("hard_drop")
          root_list.push([move_list, Tetrimino.project(field, mino_copy_3)])

          num_move_3 = move_list.size
          # 左右移動 (落下後)
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

    # 同じ盤面は削除
    root_list.uniq!{|root| root[1]}
    # root_list.each{|pear| p pear[0]}
    return root_list
  end

  # 手動操作 (キーボード)
  def update_human_1
    # 落下不可能時
    if @unable_fall == true
      # ミノの一ブロック下のビット情報取得
      @mino.each{|cell, bit|
        if bit == 1
          @@player_hash[@player]["under_block_bit"].push($player_hash[@player]["obj_list"][0].field[cell[1] + 1][cell[0]])
        end
      }
      # ミノの下セルがすべて空いていない限り、固定処理続行
      unless @@player_hash[@player]["under_block_bit"].all?{|bit| bit == 0}
        if @fit_count > Fix_limit
          vanish
        else
          @fit_count += 1
        end
      # セルが空いていたら、落下可能へ変数を変更
      else
        @unable_fall = false
      end
      @@player_hash[@player]["under_block_bit"].clear
    end

    # ハードドロップ
    if Input.key_push?(K_W)
      drop_dis = hard_drop
      # 得点加算 (基礎点 * 落下距離 * (レベル+1))
      $player_hash[@player]["score"] += Hard_drop_point * drop_dis * ($player_hash[@player]["level"] + 1)

      vanish
    end

    # 右移動
    if Input.key_push?(K_D)
      shift_R
    # 左移動
    elsif Input.key_push?(K_A)
      shift_L
    end

    # ソフトドロップ
    if Input.key_down?(K_S) && $player_hash[@player]["time"] % 2 == 0
      soft_drop
    end

    # 右回転
    if Input.key_push?(K_G)
      rote_R
    # 左回転
    elsif Input.key_push?(K_F)
      rote_L
    end

    # ホールド
    if Input.key_push?(K_T)
      hold
    end

    # 一定間隔で落下
    if $player_hash[@player]["time"] %  @@player_hash[@player]["fall_speed"] == 0
      fall
    end
  end

  # 手動操作 (テンキー)
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
      # 得点加算 (基礎点 * 落下距離 * (レベル+1))
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


  # AI操作 (タイプA)
  def update_com_A
    # 初回or前回の操作が完了したとき
    if $player_hash[@player]["time"] == 1 && @@player_hash[@player]["move_list"].empty? or $player_hash[@player]["time"] == 0

      # フィールド探索
      root_list = Tetrimino.root($player_hash[@player]["obj_list"][0].field, $player_hash[@player]["obj_list"][-1])
      # 盤面取得
      field_list = root_list.map{|root| root[1]}

# =begin
      # hold有効時のみ、holdミノも用いて探索
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

      # 盤面の得点リスト
      score_list = Array.new
      # 各盤面をニューラルネットワークを用いて採点
      field_list.each_with_index{|field, index|
        # 特徴量抽出
        input_value_list = Field.feature_value(field)
        # 不要な特徴量削除
        input_value_list.keep_if{|feature_value| @@player_hash[@player]["keep_feature_value"].include?(feature_value)}
        # 採点
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

      # 最善の操作を選択
      index_best = score_list.sort_by{|pear| pear[1]}.reverse[0][0]
      move_list = root_list[index_best][0]
      take_while_drop = move_list.take_while{|move| move != "hard_drop"}

      # 回転と移動の順番変更
      # ハードドロップより前の操作が回転のみでない、かつハードドロップより前の操作が回転1回でないとき (回転以外に何かしらの操作があるとき)
      if !((take_while_drop - ["hold"]).all?{|move| move =~ /rote/}) && (take_while_drop.count("rote_R") != 1 && take_while_drop.count("rote_L") != 1)
        # holdは最初である必要があるから、holdがある場合はelseで処理
        unless take_while_drop[0] == "hold"
          take_while_drop.shuffle!
          # 最後の操作が回転でなくなるまでシャッフル
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
      # 操作が確定
      @@player_hash[@player]["move_list"] = move_list
    end

    # 操作開始
    if $player_hash[@player]["time"] >= 1

      # 落下可能か判定 (手動操作時と同様)
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

      # 毎フレーム操作
      if $player_hash[@player]["time"] % 1 == 0
        # ホールド
        if @@player_hash[@player]["move_list"][0] == "hold"
          @@player_hash[@player]["move_list"].shift
          hold
        # 右回転
        elsif @@player_hash[@player]["move_list"][0] == "rote_R"
          @@player_hash[@player]["move_list"].shift
          rote_R
        # 左回転
        elsif @@player_hash[@player]["move_list"][0] == "rote_L"
            @@player_hash[@player]["move_list"].shift
            rote_L
        # 右移動
        elsif @@player_hash[@player]["move_list"][0] == "shift_1"
          @@player_hash[@player]["move_list"].shift
          shift_R
        # 左移動
        elsif @@player_hash[@player]["move_list"][0] == "shift_-1"
          @@player_hash[@player]["move_list"].shift
          shift_L

        # 操作終了or操作リストに指示あれば、ハードドロップ
        elsif @@player_hash[@player]["move_list"].empty? || @@player_hash[@player]["move_list"][0] == "hard_drop"
          # ハードドロップ
          if @@player_hash[@player]["move_list"].empty? || @@player_hash[@player]["move_list"].size == 1
            @@player_hash[@player]["move_list"].clear
            drop_dis = hard_drop
            # 得点加算 (基礎点 * 落下距離 * (レベル+1))
            $player_hash[@player]["score"] += Hard_drop_point * drop_dis * ($player_hash[@player]["level"] + 1)
            vanish
          # ソフトドロップ
          else
            @@player_hash[@player]["move_list"].shift
            hard_drop
          end
        end
      end

      # 一定間隔で落下
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
            # 得点加算 (基礎点 * 落下距離 * (レベル+1))
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

  # アップデートメソッド
  def update
    # COMでないなら
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

# 一時停止メソッド
def pause
  # フォントオブジェクト
  font = Font.new(12)

  # 一時停止(updateなし)ループ
  Window.loop do
    # プレイヤーごとにループ
    $player_hash.each_key{|player|
      # オブジェクト描写
      $player_hash[player]["obj_list"].each{|obj|
        obj.draw
      }
      # HOLDミノ, NEXTミノの描画
      Tetrimino.draw_other_mino(player)

      # 情報色々表示
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 100, "SCORE #{$player_hash[player]["score"]}", font, :color => C_BLACK)
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 150, "Lv #{$player_hash[player]["level"]}", font, :color => C_BLACK)
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 170, "MINO #{$player_hash[player]["num_drop_mino"]}", font, :color => C_BLACK)
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 190, "LINE #{$player_hash[player]["delete_line_sum"]}", font, :color => C_BLACK)
      Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 210, "FPS #{Window.fps}", font, :color => C_BLACK)

      # 「PAUSE」
      Window.draw_font($player_hash[player]["location_x"] + $player_hash[player]["obj_list"][0].width_px / 2 - 20, $player_hash[player]["location_y"] + $player_hash[player]["obj_list"][0].height_px / 2 - 20, "PAUSE", font, :color => C_WHITE)
      Window.draw_font($player_hash[player]["location_x"] + $player_hash[player]["obj_list"][0].width_px / 2 - 75, $player_hash[player]["location_y"] + $player_hash[player]["obj_list"][0].height_px / 2, "PRESS ESCAPE TO RESTART", font, :color => C_WHITE)
    }

    # エスケープキーでループ抜ける
    if Input.key_push?(K_ESCAPE)
      break
    end
  end
end

=begin
# 過去の最高得点を返し, 今回の得点をデータベースに書き込むメソッド (未使用)
# 引数 user: ユーザー名, score: 今回の得点
def best_score(user, score)
  # 入出力用オブジェクト
  in_out_put = File.open("#{File.dirname(__FILE__)}/score_list/score_list.txt", "a+")
  # データベースから全文取得
  text = in_out_put.read
  best_score = ""
  # データベースが空でない限り, データベース分析
  unless text.empty?
    score_list = text.chomp.split("\n").map{|line| line.split(":")}
    best_score = score_list.sort_by{|user_score| user_score[1].to_i}.reverse[0]
  end
  # 今回の得点を書き込む
  in_out_put.print(user, ":", score, "\n")
  in_out_put.close
  return best_score[1].to_i
end
=end

# 各プレイヤーのゲーム情報作成
# player_hash: {プレイヤー名 => {各情報}}の二次元ハッシュ
$player_hash = Hash.new
player_list.each{|player|
  $player_hash[player] = Hash.new

  # フィールド作成
  field = Field.new(player, Field_width, Field_height)
  # field.gene_terra([[0, 12], [1, 12], [2, 12], [3, 12], [8, 12], [9, 12], [0, 13], [1, 13], [2, 13], [6, 13], [7, 13], [8, 13], [9, 13], [0, 14], [1, 14], [2, 14], [3, 14], [5, 14], [6, 14], [7, 14], [8, 14], [9, 14], [0, 15], [1, 15], [5, 15], [6, 15], [7, 15], [8, 15], [9, 15], [0, 16], [1, 16], [6, 16], [7, 16], [8, 16], [9, 16], [0, 17], [1, 17], [2, 17], [3, 17], [4, 17], [6, 17], [7, 17], [8, 17], [9, 17], [0, 18], [1, 18], [2, 18], [3, 18], [6, 18], [7, 18], [8, 18], [9, 18], [0, 19], [1, 19], [2, 19], [3, 19], [4, 19], [6, 19], [7, 19], [8, 19], [9, 19]])

  # field.gene_terra([[3, 4], [4, 4], [5, 4], [5, 5], [5, 6], [5, 7], [5, 8], [6, 8], [5, 9], [6, 9], [3, 10], [4, 10], [2, 11], [4, 11], [2, 12], [4, 12], [5, 12], [2, 13], [4, 13], [5, 13], [1, 14], [4, 14], [5, 14], [1, 15], [2, 16], [3, 16], [4, 16], [5, 16], [7, 16], [8, 16], [6, 17], [7, 17]])
  # field.gene_terra([[0, 16], [1, 16], [2, 16], [3, 16], [4, 16], [5, 16], [6, 16], [7, 16], [8, 16], [0, 17], [1, 17], [2, 17], [3, 17], [4, 17], [5, 17], [6, 17], [7, 17], [8, 17], [0, 18], [1, 18], [2, 18], [3, 18], [4, 18], [5, 18], [6, 18], [7, 18], [8, 18], [0, 19], [1, 19], [2, 19], [3, 19], [4, 19], [5, 19], [6, 19], [7, 19], [8, 19]])

  # ミノボックス (ミノ各種1個ずつ入った配列)作成
  mino_box = Array.new(7){|index| Tetrimino.new(player, index + 1)}
  # ミノボックスをシャッフル
  mino_box.shuffle!(random: Rnd.dup)

  # オブジェクトリスト (メインループ内で扱うオブジェクト(通常, フィールドと落下ミノ))作成
  obj_list = Array.new
  # オブジェクトリストにオブジェクト追加
  obj_list.push(field, mino_box.slice!(0))

  # NEXTミノ配列作成
  next_mino_list = Array.new
  3.times{
    next_mino_list.push(mino_box.slice!(0))
  }

  # 卍モードの起動判定
  if mode_manji == true
    Tetrimino.mode_manji(player)
  end

  # AIの作成
  if !(com_num.nil?) && player =~ /com/
    Tetrimino.gene_nnw(player, com_list.slice!(0))
  end

  # ループ数カウント
  time = 0

  # 得点
  score = 0
  # レベル
  level = Tetrimino::Min_fall_speed - Tetrimino.fall_speed(player)
  # 消去したラインの総数
  delete_line_sum = 0
  # 落としたミノの総数
  num_drop_mino = 0

  # 排除すべきオブジェクトを格納する配列
  delete_obj_list = Array.new
  # 各レベル間のライン消去数
  count_delete_line = 0

  # 各プレイヤーの描画開始位置
  location_x = player_list.index(player) % Num_player_per_row * field.width_px
  location_y = (player_list.index(player) / Num_player_per_row.to_f).floor * field.height_px

  # キー名
  item_list = ["obj_list", "next_mino_list", "mino_box", "time", "score", "level",
    "delete_line_sum", "num_drop_mino", "delete_obj_list", "count_delete_line", "location_x", "location_y"]

  # ゲームデータ作成
  [obj_list, next_mino_list, mino_box, time, score, level,
    delete_line_sum, num_drop_mino, delete_obj_list, count_delete_line, location_x, location_y].each_with_index{|item, index|
      $player_hash[player].store(item_list[index], item)
    }
}

# フォントオブジェクト
font = Font.new(12)

# ウィンドウのキャプション, サイズ, フレームレート
Window.caption = "TETRIS"

# 横幅の決定
# 一段のみで描画
if Num_player >= Num_player_per_row
  Window.width = ((Field_width + Field::Thick_wall * 2) * Block_size ) * Num_player_per_row
# 数段で描画
else
  Window.width = ((Field_width + Field::Thick_wall * 2) * Block_size ) * Num_player
end
# 縦幅
Window.height = (Field_height + Field::Thick_wall * 2 + Field::Spawn_area) * Block_size * (Num_player / Num_player_per_row.to_f).ceil
Window.fps = Fps

# play_time = Benchmark.realtime do
# スタート画面
Window.loop do
  # フィールドのみ描画
  $player_hash.each_key{|player|
    $player_hash[player]["obj_list"][0].draw

  # 開始を促す文字
  Window.draw_font($player_hash[player]["location_x"] + $player_hash[player]["obj_list"][0].width_px / 2 - 70, $player_hash[player]["location_y"] + $player_hash[player]["obj_list"][0].height_px / 2, "PRESS ENTER TO START", font, :color => C_WHITE)
}

  # エンターキーでループ抜ける
  if Input.key_push?(K_RETURN)
    break
  end
end

# ×ボタンでウィンドウ閉じられたらプログラム終了
if Window.closed?
  exit
end

# BGM (未使用)
bgm = Sound.new("#{File.dirname(__FILE__)}/sound/bgm_main.wav")
bgm.loop_count = -1
# bgm.play

# メインループ開始
Window.loop do

  # プレイヤーごとに繰り返し
  $player_hash.each_key{|player|
    # 完全にゲームオーバーしていない限り
    unless $player_hash[player]["obj_list"][0].game_ov == true
      # アップデート
      $player_hash[player]["obj_list"].reverse.each{|obj| obj.update}
    end
    $player_hash[player]["obj_list"].each_with_index{|obj, index|
      # ゲームオーバー演出中はミノ描画しない(であってる?)
      unless index == 1 && $player_hash[player]["obj_list"][0].game_ov == true
        obj.draw
      end

      # 消去すべきオブジェクト探す
      if obj.delete == true
        $player_hash[player]["delete_obj_list"].push(obj)
      end
    }
    # HOLDミノ, NEXTミノの描画
    Tetrimino.draw_other_mino(player) if $player_hash[player]["obj_list"][0].game_ov != true

    # 消去すべきオブジェクトがあれば消去
    unless $player_hash[player]["delete_obj_list"].empty?
      $player_hash[player]["obj_list"] -= $player_hash[player]["delete_obj_list"]
      # ライン消去が完了したらdelete_obj_listを空に
      if $player_hash[player]["obj_list"][0].comp_delete == true
        $player_hash[player]["delete_obj_list"].clear
        $player_hash[player]["obj_list"][0].comp_delete = nil
        Tetrimino.push_mino(player)
        # ライン消去が実行されていないとき
      elsif $player_hash[player]["obj_list"][0].comp_delete == nil
        $player_hash[player]["delete_obj_list"].clear
        Tetrimino.push_mino(player)
        # (ライン消去中は何もしない)
      end
      Tetrimino.reset_last_act(player)
    end


    # 情報色々表示
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 100, "SCORE #{$player_hash[player]["score"]}", font, :color => C_BLACK)
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 150, "Lv #{$player_hash[player]["level"]}", font, :color => C_BLACK)
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 170, "MINO #{$player_hash[player]["num_drop_mino"]}", font, :color => C_BLACK)
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 190, "LINE #{$player_hash[player]["delete_line_sum"]}", font, :color => C_BLACK)
    Window.draw_font($player_hash[player]["location_x"] + 7, $player_hash[player]["location_y"] + 210, "FPS #{Window.fps}", font, :color => C_BLACK)

    # 消去ライン数が一定数越えたらレベルアップ
    if $player_hash[player]["count_delete_line"] >= Betwen_level && Tetrimino.fall_speed(player) > 1
      $player_hash[player]["count_delete_line"] -= Betwen_level
      Tetrimino.mody_fall_speed(player, 1)
      $player_hash[player]["level"] += 1
    end

    # ゲームオーバー判定が出たらゲーム終了
    if $player_hash[player]["obj_list"][0].game_ov == true
      $player_hash[player]["obj_list"][0].game_over
    end

    $player_hash[player]["time"] += 1
  }

  # エスケープキー押されたら一時停止
  if Input.key_push?(K_ESCAPE)
    pause
  end

end
# end
