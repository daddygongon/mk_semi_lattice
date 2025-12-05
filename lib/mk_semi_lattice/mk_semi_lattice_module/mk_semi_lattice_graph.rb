NODE_COLOR = 'orange'
SELECT_COLOR = 'red'
FIXED_COLOR = 'green'
LINKED_COLOR = 'blue'
EDGE_COLOR = 'black'  # 標準色に戻す

# 日本語対応フォントの優先順位で選択 for win11, なければ省略
def japanese_font
  fonts = [
    '/usr/share/fonts/truetype/takao-gothic/TakaoGothic.ttf',
    '/usr/share/fonts/truetype/vlgothic/VL-Gothic-Regular.ttf',
    '/usr/share/fonts/truetype/fonts-japanese-gothic.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
  ]
  selected_font = fonts.find { |font| File.exist?(font) }
  # puts "Selected font: #{selected_font}" if selected_font
  selected_font || fonts.last
end

class Folder
  # フォルダアイコンをRuby2Dの図形で描画するクラス
    attr_accessor :x, :y, :name, :label, :fixed, :linked, :dx, :dy, :type, :file_path
  def initialize(attrs = {})
    @x = attrs[:x]
    @y = attrs[:y]
    @z = attrs[:z]
    @color = attrs[:color]
    @folder1 = Rectangle.new(x: @x-28, y: @y-10, width: 56, height: 32, color: @color, z: @z)
    @folder2 = Rectangle.new(x: @x-28, y: @y-20, width: 32, height: 16, color: @color, z: @z)
  end

  def color= c
    @folder1.color = c
    @folder2.color = c
  end
  
  def x= x
    @folder1.x = x -28
    @folder2.x = x -28
  end

  def y= y
    @folder1.y = y -10
    @folder2.y = y -10
  end
end

class Node
  attr_accessor :x, :y, :name, :label, :fixed, :linked, :color, :dx, :dy, :type, :file_path

  def initialize(attrs = {})
    @name      = attrs[:name]
    @label     = attrs[:label]
    @x         = attrs[:x] || rand(80..520)
    @y         = attrs[:y] || rand(80..520)
    @fixed     = attrs[:fixed] || false
    @linked    = attrs[:linked] || false
    @color     = attrs[:color] || NODE_COLOR
    @dx        = attrs[:dx] || 0.0
    @dy        = attrs[:dy] || 0.0
    @type      = attrs[:type]
    @file_path = attrs[:file_path]
    @circle = nil
    @text = nil
    @created = false
  end

  def update
    unless fixed
      @x += [@dx, -5, 5].sort[1]
      @y += [@dy, -5, 5].sort[1]
      
      @x = [[@x, 0].max, 600].min
      @y = [[@y, 0].max, 600].min
    end
    @dx /= 2.0
    @dy /= 2.0
  end

  def relax(nodes)
    ddx = 0
    ddy = 0

    nodes.each do |n|
      next if n == self
      
      vx = x - n.x
      vy = y - n.y
      lensq = vx * vx + vy * vy
      
      if lensq == 0
        ddx += rand(-1.0..1.0)
        ddy += rand(-1.0..1.0)
      elsif lensq < 100 * 100
        ddx += vx / lensq
        ddy += vy / lensq
      end
    end
    
    dlen = Math.sqrt(ddx * ddx + ddy * ddy) / 2
    if dlen > 0
      @dx += ddx / dlen
      @dy += ddy / dlen
    end
  end

  def create_graphics
    return if @created
    font_path = japanese_font

    @circle = if @type == 'dir'
      @text = if font_path && File.exist?(font_path)
                Text.new(label, x: x-28, y: y-10, size: 18, color: 'black', font: font_path, z: 11)
              else
                Text.new(label, x: x-28, y: y-10, size: 18, color: 'black', z: 11)
              end
      Folder.new(x: x, y: y, color: NODE_COLOR, z: 10)
    else
      @text = if font_path && File.exist?(font_path)
                Text.new(label, x: x-28, y: y-10, size: 18, color: 'black', font: font_path, z: 11)
              else
                Text.new(label, x: x-28, y: y-10, size: 18, color: 'black', z: 11)
              end
      Circle.new(x: x, y: y, radius: 30, color: NODE_COLOR, z: 10)
    end
    @created = true
  end
  
  def draw(selected)
    create_graphics
    
    c = if selected
          SELECT_COLOR
        elsif @fixed
          FIXED_COLOR
        elsif @linked
          LINKED_COLOR
        else
          NODE_COLOR
        end
    @circle.color = c
    @circle.x = @x
    @circle.y = @y
    @text.x = @x - 28
    @text.y = @y
  end
end

class Edge
  attr_reader :from, :to
  def initialize(from, to)
    @from = from
    @to = to
    @len = 75.0
    @line = nil
    @created = nil
  end

  def relax
    vx = to.x - from.x
    vy = to.y - from.y
    d = Math.hypot(vx, vy)
    if d > 0
      f = (@len - d) / (d * 5)
      dx = f * vx
      dy = f * vy
      to.dx += dx
      to.dy += dy
      from.dx -= dx
      from.dy -= dy
    end
  end

  def update
    # 何も処理しないが、将来拡張用
  end

  def create_graphics
    return if @created
    @line = Line.new(
      x1: from.x, y1: from.y, x2: to.x, y2: to.y,
      width: 2, color: EDGE_COLOR, opacity: 0.3, z: 5 # opacityを追加
    )
    @created = true
  end

  def draw
    create_graphics
    # 既存ラインのプロパティを更新
    @line.x1 = from.x
    @line.y1 = from.y
    @line.x2 = to.x
    @line.y2 = to.y
  end
end

# MkSemiLattice::GraphData はノードとエッジのデータをYAMLファイルから読み込み作成
module MkSemiLattice
  class GraphData
    attr_reader :nodes, :edges, :node_table
    attr_accessor :selected, :shift_pressed, :show_index

    def initialize(file = "dir_node_edge.yaml", with_semi_lattice_yaml: false, 
        show_index: false, layer: 2)
      @nodes = []
      @edges = []
      @node_table = {}
      @selected = nil
      @shift_pressed = false
      p @show_index = show_index
      load_yaml_data_with_state(file, with_semi_lattice_yaml: with_semi_lattice_yaml)
    end

    def add_node(node_data)
      return if node_data[:id].nil?
      n = Node.new(node_data)
      @nodes << n
      @node_table[node_data[:id]] = n
    end

    def add_edge(from_id, to_id)
      from = @node_table[from_id]
      to = @node_table[to_id]
      @edges << Edge.new(from, to) if from && to
    end

    def load_yaml_data_with_state(path, with_semi_lattice_yaml: false)
      state_file = path
      data = if with_semi_lattice_yaml && File.exist?(state_file)
        YAML.load_file(state_file)
      else
        YAML.load_file(path, symbolize_names: true)
      end
      load_nodes_and_edges(data)
    end

    private

    def load_nodes_and_edges(data)
      nodes_data = data[:nodes]
      edges_data = data[:edges]
      nodes_data.each do |node_data|
        node_data[:label] = @show_index ? 
          "#{node_data[:id]}:#{node_data[:name]}" : 
          node_data[:name]
        add_node(node_data)
      end
      edges_data.each do |edge_data|
        from_id = edge_data[:from]
        to_id = edge_data[:to]
        add_edge(from_id, to_id)
      end
    end
  end
end