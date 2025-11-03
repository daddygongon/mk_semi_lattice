# frozen_string_literal: true
require 'optparse'
require 'command_line/global'
require 'yaml'
require 'colorize'
require 'rbconfig'
require 'fileutils'

require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/mk_dir_yaml"
require_relative "mk_semi_lattice/mk_node_edge"
require_relative "mk_semi_lattice/mk_semi_lattice_graph"
require_relative "mk_semi_lattice/config"  # ← 追加
require_relative "mk_semi_lattice/log"
require_relative "mk_semi_lattice/option_manager"
require_relative "mk_semi_lattice/select_yaml"

$semi_dir = ''
class Error < StandardError; end

puts "mk_semi_lattice is running..."

Config.setup

option_manager = OptionManager.new
options = option_manager.parse!

# 以降は options をそのまま利用

$parent_dir = Dir.pwd
semi_dir = File.join($parent_dir, '.semi_lattice')
semi_lattice_yaml_path = File.join(semi_dir, "semi_lattice.yaml")

# 例: 起動時
Log.event("started", parent_dir: $parent_dir)

selector = MkSemiLattice::SelectYaml.new(
  parent_dir: $parent_dir,
  semi_dir: semi_dir,
  semi_lattice_yaml_path: semi_lattice_yaml_path,
  options: options
)
init_file, init_step = selector.select_init_file_and_step
p [init_file, init_step]
input_path, with_semi_lattice_yaml = selector.select_input_path_and_flag(init_file, init_step)
p [input_path, with_semi_lattice_yaml]

app = MkSemiLatticeData.new(input_path, 
  with_semi_lattice_yaml: with_semi_lattice_yaml,
  show_index: options[:show_index]
)

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
      elsif RbConfig::CONFIG['host_os'] =~ /debian/
        comm = "gnome-terminal --working-directory='#{clicked_node.file_path}'"
      else
        comm = "wt.exe -p Ubuntu-24.04 --colorScheme 'Tango Light' -d '#{clicked_node.file_path}'"
      end
    else
      if RbConfig::CONFIG['host_os'] =~ /darwin/
        comm = "open '#{clicked_node.file_path}'"
      else
        comm = "open '#{clicked_node.file_path}'"
      end
    end
    puts comm
    # 例: ダブルクリックアクション内
    Log.event("open", target_dir: File.expand_path(clicked_node.file_path, $parent_dir), parent_dir: $parent_dir)
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
        n.color = NODE_COLOR # optional: reset color when unfixed
        app.selected = nil
      else
        app.selected = n
        if event.button == :left
          n.fixed = true
          n.color = FIXED_COLOR # ← ここを変更
        end
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
#  clear
  app.edges.each(&:relax)
  app.nodes.each { |n| n.relax(app.nodes) }
  app.nodes.each(&:update)
  app.edges.reverse.each(&:draw)
  app.nodes.reverse.each do |n|
    n.draw(app.selected == n)
  end
end

# Ruby2Dには:closeイベントはありません。at_exitで保存処理を行います。
at_exit do
  nodes_data = app.nodes.map do |n|
    p [n.label, n.fixed, n.color]
    #color = n.color? ? nil : n.color
    {
      id: app.node_table.key(n),
      name: n.name,
      type: n.type,
      file_path: n.file_path,
      x: n.x,
      y: n.y,
      color: n.color,
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
  # コメント付きテキストに変換
  yaml_text = MkSemiLattice::MkNodeEdge.add_edge_comments(yaml_data)
  if Dir.exist?(semi_dir)
    File.write(File.join(semi_dir, "semi_lattice.yaml"), yaml_text)
  else
    File.write(File.join('.', "semi_lattice.yaml"), yaml_text)
  end
  # 例: 終了時
  Log.event("exited", parent_dir: $parent_dir)
end

show
