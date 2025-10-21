# frozen_string_literal: true
require 'optparse'
require 'command_line/global'
require 'yaml'

require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/mk_dir_yaml"
require_relative "mk_semi_lattice/mk_node_edge"
require_relative "mk_semi_lattice/mk_semi_lattice_graph"

$semi_dir = ''
class Error < StandardError; end

puts "mk_semi_lattice is running..."

require 'optparse'
options = { layer: 2, output: 'dir.yaml' }
OptionParser.new do |opts|
  opts.banner = "Usage: mk_semi_lattice PATH [-L layer]
default PATH = '.'"

  opts.on("-L N", Integer, "Layer depth (default: 2)") do |v|
    options[:layer] = v
  end
end.parse!

path = ARGV[0] || '.'
$semi_dir = File.join(path, '.semi_lattice')
if path == '.'
  Dir.mkdir($semi_dir) unless Dir.exist?($semi_dir)
  dir_yaml_path = File.join($semi_dir, 'dir.yaml')
  MkSemiLattice::MkDirYaml.new(path: path, layer: options[:layer],
                               output_file: dir_yaml_path)
  MkSemiLattice::MkNodeEdge.new(input_path: dir_yaml_path,
                                output_path: File.join($semi_dir, 'dir_node_edge.yaml'))
end

require 'ruby2d'

file = ARGV[0] || File.join($semi_dir, "dir_node_edge.yaml")
semi_lattice_yaml_path = File.join($semi_dir, "semi_lattice.yaml")

if (ARGV[0] && ARGV[0] =~ /semi_lattice\.ya?ml\z/) || File.exist?(semi_lattice_yaml_path)
  # ARGV[0]でsemi_lattice.yamlが指定された場合、または存在する場合はノード座標・fixed状態を反映
  file = (ARGV[0] =~ /semi_lattice\.ya?ml\z/) ? ARGV[0] : semi_lattice_yaml_path
  app = MkSemiLatticeData.new(file, with_semi_lattice_yaml: true)
else
  app = MkSemiLatticeData.new(file)
end

# top nodeのname（label）をタイトルに使う
top_node_label = app.nodes.first&.label || "KnowledgeFixer Graph"
set width: 800, height: 600
set title: top_node_label
set background: 'white'
set fps: 15

last_click_time = nil
last_click_node = nil

on :key_down do |event|
  app.shift_pressed = true if event.key.include?('shift')
end

on :key_up do |event|
  app.shift_pressed = false if event.key.include?('shift')
end

on :mouse_down do |event|
  mx, my = event.x, event.y
  shift_down = !!app.shift_pressed
  clicked_node = nil
  app.nodes.each do |n|
    if Math.hypot(n.x - mx, n.y - my) < 30
      clicked_node = n
      if shift_down
        n.fixed = false
        app.selected = nil
      else
        app.selected = n
        n.fixed = true if event.button == :left
        n.fixed = false if event.button == :middle
        n.linked = true if event.button == :right
      end
    end
  end

  # ダブルクリック判定とファイルオープン
  now = Time.now
  if clicked_node
    if last_click_node == clicked_node && last_click_time && (now - last_click_time < 0.4)
      comm = nil
      if clicked_node.file_path
        if File.directory?(clicked_node.file_path)
          comm = "open -a Terminal '#{clicked_node.file_path}'"
        else
          comm = "open #{clicked_node.file_path}"
        end
        puts comm
        system comm
      else
        puts "no link error"
      end
    end
    last_click_time = now
    last_click_node = clicked_node
  end
end

on :mouse_up do
  app.selected = nil
end

on :mouse_move do |event|
  if app.selected
    app.selected.x = event.x
    app.selected.y = event.y
  end
end

update do
  clear
  app.edges.each(&:relax)
  app.nodes.each { |n| n.relax(app.nodes) }
  app.nodes.each(&:update)
  app.edges.reverse.each(&:draw)
  app.nodes.reverse.each { |n| n.draw(app.selected == n) }
end

# Ruby2Dには:closeイベントはありません。at_exitで保存処理を行います。
at_exit do
  Dir.mkdir($semi_dir) unless 
  nodes_data = app.nodes.map do |n|
    {
      id: app.node_table.key(n),
      name: n.label,
      type: n.type,
      file_path: n.file_path,
      x: n.x,
      y: n.y,
      fixed: n.fixed
    }
  end
  edges_data = app.edges.map do |e|
    {
      from: app.node_table.key(e.from),
      to: app.node_table.key(e.to)
    }
  end
  yaml_data = { nodes: nodes_data, edges: edges_data }
  if Dir.exist?($semi_dir)
    File.write(File.join($semi_dir, "semi_lattice.yaml"), YAML.dump(yaml_data))
  else
    File.write(File.join('.', "semi_lattice.yaml"), YAML.dump(yaml_data))
  end
end

show
