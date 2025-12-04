# frozen_string_literal: true
require 'optparse'
require 'command_line/global'
require 'yaml'
require 'colorize'
require 'rbconfig'
require 'fileutils'

require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/config"
require_relative "mk_semi_lattice/log"
require_relative "mk_semi_lattice/mk_dir_yaml"
require_relative "mk_semi_lattice/mk_node_edge"
require_relative "mk_semi_lattice/mk_semi_lattice_graph"
require_relative "mk_semi_lattice/option_manager"
require_relative "mk_semi_lattice/manage_yaml"
require_relative "mk_semi_lattice/ruby2d_action"
require_relative "mk_semi_lattice/mk_semi_lattice_viewer"

class Error < StandardError; end

def main
  puts "mk_semi_lattice is running... with method mk_semi_lattice_viewer"

  Config.setup

  option_manager = OptionManager.new
  options = option_manager.parse!

  parent_dir = Dir.pwd
  semi_dir = File.join(parent_dir, '.semi_lattice')
  semi_lattice_yaml_path = File.join(semi_dir, "semi_lattice.yaml")

  Log.event("started", parent_dir: parent_dir)

  selector = MkSemiLattice::ManageYaml.new(
    parent_dir: parent_dir,
    semi_dir: semi_dir,
    semi_lattice_yaml_path: semi_lattice_yaml_path,
    options: options
  )
  init_file, init_step = selector.select_init_file_and_step
  p [init_file, init_step]
  input_path, with_semi_lattice_yaml = selector.select_input_path_and_flag(init_file, init_step)
  p [input_path, with_semi_lattice_yaml]

  # options[:layer] を MkSemiLatticeGraphData に渡す
  app = MkSemiLatticeGraphData.new(
    input_path,
    with_semi_lattice_yaml: with_semi_lattice_yaml,
    show_index: options[:show_index],
#    layer: options[:layer] # 追加
  )

  require 'ruby2d'

  top_node_label = app.nodes.first&.label || "KnowledgeFixer Graph"
  set width: 800, height: 600
  set title: top_node_label
  set background: 'white'
  set fps: 15

  last_click_time = nil
  last_click_node = nil

  on :key_down do |event|
    Ruby2dAction.on_key_down(app, event)
  end

  on :key_up do |event|
    Ruby2dAction.on_key_up(app, event)
  end

  on :mouse_down do |event|
    clicked_node, last_time = Ruby2dAction.on_mouse_down(app, event, last_click_node, last_click_time, parent_dir)
    last_click_node = clicked_node
    last_click_time = last_time
  end

  on :mouse_up do
    Ruby2dAction.on_mouse_up(app)
  end

  on :mouse_move do |event|
    Ruby2dAction.on_mouse_move(app, event)
  end

  update do
    Ruby2dAction.update_action(app)
  end

  at_exit do
    MkSemiLattice::ManageYaml.at_exit_action(app, semi_dir, parent_dir)
  end

  show

end

main
