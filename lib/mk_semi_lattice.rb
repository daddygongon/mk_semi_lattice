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

mk_semi_lattice_viewer
