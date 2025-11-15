require 'thor'
require_relative 'option_manager'
require_relative 'mk_semi_lattice'

class MkSemiLatticeCLI < Thor
  desc "run [PATH]", "Run mk_semi_lattice with options"
  option :layer, type: :numeric, aliases: '-L', desc: 'Layer depth (default: 2)'
  option :node, type: :string, aliases: '-n', desc: 'using File from node-edge'
  option :tree, type: :string, aliases: '-t', desc: 'using File from tree'
  option :index, type: :boolean, aliases: '-i', desc: 'Display node ids'
  option :log, type: :string, aliases: '-l', desc: 'Enable/disable logging (true/false), and save to config'

  def run(path = '.')
    options_hash = {
      layer: options[:layer] || 2,
      init_step: :from_semi_lattice,
      show_index: options[:index] || false,
      merge: false
    }

    if options[:node]
      options_hash[:file] = options[:node]
      options_hash[:init_step] = :from_node_edge
    elsif options[:tree]
      options_hash[:file] = options[:tree]
      options_hash[:init_step] = :from_tree
    end

    if options[:log]
      bool =
        case options[:log].strip.downcase
        when "true", "yes", "on", "1"
          true
        when "false", "no", "off", "0"
          false
        else
          puts "Invalid value for log: #{options[:log]}. Using default: false".yellow
          false
        end
      Config.set_log(bool)
      puts "Logging is now #{bool ? 'enabled' : 'disabled'} (saved to #{Config::CONF_PATH})"
      exit
    end

    # 実際の処理呼び出し例
    mk_semi_lattice_viewer(path, options_hash)
  end
end

# CLI実行用
if $PROGRAM_NAME == __FILE__
  MkSemiLatticeCLI.start(ARGV)
end