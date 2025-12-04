**daddygongon**: 描かれたnodeにidも表示するoptionとして-i, -indexを追加．

GitHub Copilot: ### [mk_semi_lattice.rb](file:///Users/bob/git_hub/mk_semi_lattice/lib/mk_semi_lattice.rb)

Add an option `-i`/`--index` to display node ids. Pass this option to the app and update node drawing to show id if enabled.

````ruby
# ...existing code...
options = { layer: 2, init_step: :from_semi_lattice, show_index: false }
OptionParser.new do |opts|
  # ...existing code...
  opts.on("-i", "--index", "Display node ids") do
    options[:show_index] = true
  end
  # ...existing code...
end.parse!
# ...existing code...

app = MkSemiLatticeData.new(input_path, 
  with_semi_lattice_yaml: with_semi_lattice_yaml,
  show_index: options[:show_index]
)
# ...existing code...

update do
  clear
  app.edges.each(&:relax)
  app.nodes.each { |n| n.relax(app.nodes) }
  app.nodes.each(&:update)
  app.edges.reverse.each(&:draw)
  app.nodes.reverse.each do |n|
    n.draw(app.selected == n)
    # show node id if option enabled
    if app.respond_to?(:show_index) && app.show_index
      id = app.node_table.key(n)
      Text.new(id.to_s, x: n.x + 20, y: n.y - 20, size: 16, color: 'black')
    end
  end
end
# ...existing code...
````

Made changes.

daddygongon: #file:mk_semi_lattice.rb:86-89 に対応するようにMkSemiLatticeDataを修正

GitHub Copilot: ### [mk_semi_lattice_graph.rb](file:///Users/bob/git_hub/mk_semi_lattice/lib/mk_semi_lattice/mk_semi_lattice_graph.rb)

Update `MkSemiLatticeData` to accept and store `show_index` option, and provide it as an attribute for use in the main file.

````ruby
# ...existing code...

class MkSemiLatticeData
  attr_reader :nodes, :edges, :node_table
  attr_accessor :selected, :shift_pressed
  attr_accessor :show_index # add this line

  def initialize(file = "dir_node_edge.yaml", with_semi_lattice_yaml: false, show_index: false)
    @nodes = []
    @edges = []
    @node_table = {}
    @selected = nil
    @shift_pressed = false
    @show_index = show_index # store the option
    load_yaml_data_with_state(file, with_semi_lattice_yaml: with_semi_lattice_yaml)
  end

  # ...existing code...
end
# ...existing code...
````

Made changes.

daddygongon: /Users/bob/.rbenv/versions/3.0.2/lib/ruby/gems/3.0.0/gems/mk_semi_lattice-0.1.0/lib/mk_semi_lattice/mk_semi_lattice_graph.rb:165:in `initialize': unknown keyword: :show_index (ArgumentError)
とのエラー

GitHub Copilot: ### [mk_semi_lattice_graph.rb](file:///Users/bob/git_hub/mk_semi_lattice/lib/mk_semi_lattice/mk_semi_lattice_graph.rb)

Fix the error by adding `show_index` as an optional keyword argument to `MkSemiLatticeData#initialize` and storing it as an attribute.

````ruby
# ...existing code...
class MkSemiLatticeData
  attr_reader :nodes, :edges, :node_table
  attr_accessor :selected, :shift_pressed, :show_index

  def initialize(file = "dir_node_edge.yaml", with_semi_lattice_yaml: false, show_index: false)
    @nodes = []
    @edges = []
    @node_table = {}
    @selected = nil
    @shift_pressed = false
    @show_index = show_index
    load_yaml_data_with_state(file, with_semi_lattice_yaml: with_semi_lattice_yaml)
  end
  # ...existing code...
end
# ...existing code...
````

Made changes.

daddygongon: #file:mk_semi_lattice_graph.rb:193-226 の重複を取り除くrefactoringを掛けてください

GitHub Copilot: ### [mk_semi_lattice_graph.rb](file:///Users/bob/git_hub/mk_semi_lattice/lib/mk_semi_lattice/mk_semi_lattice_graph.rb)

Refactor `load_yaml_data_with_state` to remove duplication by extracting node/edge loading into a helper method.

````ruby
# ...existing code...

class MkSemiLatticeData
  # ...existing code...

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
      id = node_data[:id]
      name = node_data[:name]
      type = node_data[:type]
      color = node_data[:color]
      file_path = node_data[:file_path]
      x = node_data[:x] || rand(80..520)
      y = node_data[:y] || rand(80..520)
      fixed = node_data[:fixed] || false
      label = @show_index ? "#{id}:#{name}" : name
      add_node(id, x, y, label, type, color, file_path, fixed)
    end
    edges_data.each do |edge_data|
      from_id = edge_data[:from]
      to_id = edge_data[:to]
      add_edge(from_id, to_id)
    end
  end
  # ...existing code...
end
# ...existing code...
````

Made changes.