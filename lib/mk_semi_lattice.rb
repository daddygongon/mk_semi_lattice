# frozen_string_literal: true
require 'optparse'
require 'command_line/global'
require 'yaml'
require 'colorize'

require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/mk_dir_yaml"
require_relative "mk_semi_lattice/mk_node_edge"
require_relative "mk_semi_lattice/mk_semi_lattice_graph"

$semi_dir = ''
class Error < StandardError; end

puts "mk_semi_lattice is running..."

require 'optparse'
options = { layer: 2, init_step: :from_semi_lattice}
OptionParser.new do |opts|
  opts.banner = "Usage: mk_semi_lattice PATH [-L layer] [-t FILE] [-n FILE]
default PATH = '.'"

  opts.on("-L N", Integer, "Layer depth (default: 2)") do |v|
    options[:layer] = v
  end

  opts.on("-n", "--node=FILE", "Input YAML file of node-edge") do |file|
    options[:file] = file
    options[:init_step] = :from_node_edge
  end

  opts.on("-t", "--tree=FILE", "Input YAML file of tree") do |file|
    options[:file] = file
    options[:init_step] = :from_tree
  end
end.parse!

parent_dir = Dir.pwd
semi_dir = File.join(parent_dir, '.semi_lattice')
semi_lattice_yaml_path = File.join(semi_dir, "semi_lattice.yaml")

init_file, init_step = if (ARGV[0]=='.' || ARGV[0].nil?) && !options[:file]
  if Dir.exist?(semi_lattice_yaml_path)
    [semi_lattice_yaml_path, :from_semi_lattice]
  else
    ['.', :from_dir]
  end
else
  [ARGV[0], options[:init_step]]
end

input_path, with_semi_lattice_yaml = case init_step
when :from_dir
  Dir.mkdir(semi_dir) unless Dir.exist?(semi_dir)
  in_path, out_path = init_file, File.join(semi_dir, 'dir_tree.yaml')
  MkSemiLattice::MkDirYaml.new(path: in_path, layer: options[:layer],
                               output_file: out_path)
  in_path, out_path = out_path, File.join(semi_dir, 'dir_node_edge.yaml')                         
  MkSemiLattice::MkNodeEdge.new(input_path: in_path,
                                output_path: out_path )
  [out_path, false]
when :from_tree
  init_file = options[:file]
  base = File.basename(init_file, File.extname(init_file))
  in_path, out_path= init_file, File.join(parent_dir, "#{base}_node_edge.yaml")
  MkSemiLattice::MkNodeEdge.new(input_path: in_path, output_path: out_path)
  [out_path, false]
when :from_node_edge
  [options[:file], false]
when :from_semi_lattice
  [init_file, true]
end

# p [input_path, with_semi_lattice_yaml]

app = MkSemiLatticeData.new(input_path, 
  with_semi_lattice_yaml: with_semi_lattice_yaml)

require 'ruby2d'

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

def double_click?(clicked_node, last_click_node, last_click_time)
  now = Time.now
  if last_click_node == clicked_node && last_click_time && (now - last_click_time < 0.4)
    return true, now
  end
  return false, now
end

def double_click_action(clicked_node)
  comm = nil
  if clicked_node.file_path
    if File.directory?(clicked_node.file_path)
      if RbConfig::CONFIG['host_os'] =~ /darwin/
        comm = "open -a Terminal '#{clicked_node.file_path}'"
      else
        comm = "wt.exe -p Ubuntu-24.04 --colorScheme 'Tango Light' -d '#{clicked_node.file_path}'"
      end
    else
      if RbConfig::CONFIG['host_os'] =~ /darwin/
        comm = "open '#{clicked_node.file_path}'"
      else
        comm = "explorer.exe '#{clicked_node.file_path}'"
      end
    end
    puts comm
    system comm
  else
    puts "no link error"
  end
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
  if clicked_node
    is_double, now = double_click?(clicked_node, last_click_node, last_click_time)
    double_click_action(clicked_node) if is_double
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
  Dir.mkdir(semi_dir) unless 
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
  if Dir.exist?(semi_dir)
    File.write(File.join(semi_dir, "semi_lattice.yaml"), YAML.dump(yaml_data))
  else
    File.write(File.join('.', "semi_lattice.yaml"), YAML.dump(yaml_data))
  end
end

show
