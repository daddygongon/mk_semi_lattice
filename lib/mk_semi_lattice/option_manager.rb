# frozen_string_literal: true
require 'optparse'
require 'colorize'

class OptionManager
  attr_reader :options

  def initialize
    @options = { layer: 2, init_step: :from_semi_lattice, show_index: false, merge: false, visibility: 'normal' }
  end

  def parse!
    a_flag = false
    d_flag = false
    OptionParser.new do |opts|
      opts.banner = <<~BANNER
        Usage: mk_semi_lattice PATH [options]
           or: hc view PATH [options]
        Default PATH = '.'
      BANNER

      opts.on("-L N", Integer, "Layer depth (default: 2)") do |v|
        @options[:layer] = v
      end

      opts.on("-n", "--node=FILE", "using File from node-edge") do |file|
        @options[:file] = file
        @options[:init_step] = :from_node_edge
      end

      opts.on("-t", "--tree=FILE", "using File from tree") do |file|
        @options[:file] = file
        @options[:init_step] = :from_tree
      end

      opts.on("-i", "--index", "Display node ids") do
        @options[:show_index] = true
      end

      opts.on("-l", "--log [BOOL]", "Enable/disable logging (true/false), and save to config") do |v|
        bool =
          if v.nil?
            true
          elsif v.is_a?(String)
            case v.strip.downcase
            when "true", "yes", "on", "1"
              true
            when "false", "no", "off", "0"
              false
            else
              puts "Invalid value for log: #{v}. Using default: false".yellow
              false
            end
          else
            !!v
          end
        Config.set_log(bool)
        puts "Logging is now #{bool ? 'enabled' : 'disabled'} (saved to #{Config::CONF_PATH})"
        exit
      end

      opts.on("-v", "--version", "show version") do
        puts MkSemiLattice::VERSION
        exit
      end

      opts.on("-d", "Show directories only") do
        d_flag = true
      end

      opts.on("-a", "Show all (files and directories)") do
        a_flag = true
      end

      opts.on("-Y", "YAML exclude mode") do
        @options[:visibility] = 'yaml_exclude'
      end
=begin
      opts.on("-ad", "Show all directories including hidden ones") do
        a_flag = true
        d_flag = true
      end
=end
      opts.on("-I PATTERN", "--ignore=PATTERN", "Ignore files/dirs matching PATTERN (e.g. '_stack_*|*.yaml')") do |pattern|
        # Remove leading '=' if present (e.g. when user writes -I='_stack_*|*.yaml')
        pattern = pattern.sub(/\A=/, '') if pattern
        @options[:ignore] = pattern
      end

      opts.separator "
        When using -I, always use '=' or quote the pattern, e.g.:
            -I='_stack_*|*.yaml' -a
            --ignore='_stack_*|*.yaml' -a
          Multiple patterns can be separated by '|'.
          Wildcards '*' and '?' are supported (like the 'tree' command).
        Do not use -ad; use -a -d for combined flags.
        "
    end.parse!

    if a_flag && d_flag
      @options[:visibility] = 'dir_and_hidden_dir'
    elsif d_flag
      @options[:visibility] = 'dir_only'
    elsif a_flag
      @options[:visibility] = 'all'
    end

    @options
  end
end
