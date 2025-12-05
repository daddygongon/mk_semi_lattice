# frozen_string_literal: true
require 'optparse'
require 'command_line/global'
require 'yaml'
require 'colorize'
require 'rbconfig'
require 'fileutils'

require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/ruby2d_action"
require_relative "mk_semi_lattice/init_env"
require_relative "mk_semi_lattice/option_manager"
require_relative "mk_semi_lattice/manage_yamle/mk_node_edge"
require_relative "mk_semi_lattice/manage_yaml/mk_semi_lattice"
require_relative "mk_semi_lattice/sl_components"

class Error < StandardError; end

def main
  puts "mk_semi_lattice is running... with method mk_semi_lattice_viewer"

  # prep semi lattice viewer app
  parent_dir = Dir.pwd
  InitEnv.init_env(parent_dir)
  
  options = OptionManager.new.parse!
  semi_dir = File.join(parent_dir, '.semi_lattice')
  semi_lattice_yaml_path = File.join(semi_dir, "semi_lattice.yaml")
  options[:parent_dir] = parent_dir
  options[:semi_dir] = semi_dir
  options[:semi_lattice_yaml_path] = semi_lattice_yaml_path

  input_path, with_semi_lattice_yaml = MkSemiLattice::ManageYaml.new(
    options).prepare_paths_and_flags

  options[:with_semi_lattice_yaml] = with_semi_lattice_yaml
  sl_viewer_app = MkSemiLattice::GraphData.new(
    input_path, options)

  require 'ruby2d'

  top_node_label = sl_viewer_app.nodes.first&.label || "Semi Lattice Graph"
  set width: 800, height: 600
  set title: top_node_label
  set background: 'white'
  set fps: 15

  last_click_time = nil
  last_click_node = nil

  on :key_down do |event|
    Ruby2dAction.on_key_down(sl_viewer_app, event)
  end

  on :key_up do |event|
    Ruby2dAction.on_key_up(sl_viewer_app, event)
  end

  on :mouse_down do |event|
    clicked_node, last_time = Ruby2dAction.on_mouse_down(sl_viewer_app, event, last_click_node, last_click_time, parent_dir)
    last_click_node = clicked_node
    last_click_time = last_time
  end

  on :mouse_up do
    Ruby2dAction.on_mouse_up(sl_viewer_app)
  end

  on :mouse_move do |event|
    Ruby2dAction.on_mouse_move(sl_viewer_app, event)
  end

  update do
    Ruby2dAction.update_action(sl_viewer_app)
  end

  at_exit do
    MkSemiLattice::ManageYaml.at_exit_action(sl_viewer_app, semi_dir, parent_dir)
  end

  show

end

main
