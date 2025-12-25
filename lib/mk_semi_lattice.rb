# frozen_string_literal: true
require 'optparse'
require 'command_line/global'
require 'yaml'
require 'colorize'
require 'rbconfig'
require 'fileutils'

require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/ruby2d_action"
require_relative "mk_semi_lattice/ruby2d_run"
require_relative "mk_semi_lattice/init_env"
require_relative "mk_semi_lattice/option_manager"
require_relative "mk_semi_lattice/manage_yaml/mk_node_edge_yaml"
require_relative "mk_semi_lattice/manage_yaml/mk_semi_lattice_yaml"
require_relative "mk_semi_lattice/sl_components"

class Error < StandardError; end


if defined?(RSpec) || defined?(Minitest)
  # テスト時は何もしない
else
  ruby2d_run(*init())
end
