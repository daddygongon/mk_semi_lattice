# frozen_string_literal: true
require 'optparse'
require 'colorize'

class OptionManager
  attr_reader :options

  def initialize
    @options = { layer: 2, init_step: :from_semi_lattice, show_index: false, merge: false }
  end

  def parse!
    OptionParser.new do |opts|
      opts.banner = "Usage: mk_semi_lattice PATH [-L layer] [-t FILE] [-n FILE]\n default PATH = '.'"

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
    end.parse!
    @options
  end
end