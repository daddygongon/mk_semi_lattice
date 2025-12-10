# frozen_string_literal: true
require 'yaml'
require 'fileutils'
require 'colorize'

module InitEnv
  def self.init_env(parent_dir)
    Config.setup
    Log.event("started", parent_dir: parent_dir)
    MkSemiLatticeDir.setup(parent_dir)
  end

  class MkSemiLatticeDir
    SEMI_LATTICE_DIR = ".semi_lattice"
    ICONS_DIR = "icons"

    def self.setup(parent_dir)
      semi_dir = File.join(parent_dir, SEMI_LATTICE_DIR)
      icons_dir = File.join(semi_dir, ICONS_DIR)
      FileUtils.mkdir_p(icons_dir)
      copy_default_icons(icons_dir)
    end

    def self.copy_default_icons(icons_dir)
      icons_src_dir = File.expand_path(File.join(__dir__, "..", "..", "app", "assets", "icons"))
      ["folder.png", "document.png"
      ].each do |icon_name|
        src_path = File.join(icons_src_dir, icon_name)
        dest_path = File.join(icons_dir, icon_name)
        FileUtils.cp(src_path, dest_path) unless File.exist?(dest_path)
      end
    end
  end

  class Config
    @conf = { "log" => false,
         "open_terminal_command" => "open -a Terminal .",
         "open_finder_command" => "open ." }

    def self.conf # needed, failed by attr_reader, private?
      @conf
    end

    def self.config_dir
      ENV['SEMI_LATTICE_CONFIG_DIR'] || File.expand_path("~/.config/semi_lattice")
    end

    def self.conf_path
      File.join(config_dir, "semi_lattice.conf")
    end

    def self.log_path
      File.join(config_dir, "semi_lattice_history")
    end

    class << self
      def setup
        FileUtils.mkdir_p(config_dir)
        if File.file?(conf_path)
          load_conf
        else
          save_conf
        end
      end

      def load_conf
        if File.file?(conf_path)
          begin
            loaded = YAML.load_file(conf_path)
            if loaded.is_a?(Hash)
              @conf.merge!(loaded)
            else
              puts "Warning: #{conf_path} is not a hash. Using default config.".yellow
            end
          rescue
            puts "Warning: #{conf_path} is invalid. Using default config.".yellow
          end
        end
      end

      def save_conf
        File.write(conf_path, @conf.to_yaml)
      end

      def log_enabled?
        @conf["log"]
      end

      def set_log(value)
        @conf["log"] = value
        save_conf
      end
    end
  end

  require 'yaml'

  class Log
    class << self
      def event(action, target_dir: nil, parent_dir: Dir.pwd)
        return unless Config.log_enabled?
        log_entry = {
          timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
          action: action
        }
        log_entry[:target_dir] = target_dir if target_dir
        log_entry[:where] = parent_dir
        logs = []
        if File.exist?(Config.log_path)
          begin
            logs = YAML.load_file(Config.log_path) || []
          rescue
            logs = []
          end
        end
        logs << log_entry
        File.write(Config.log_path, logs.to_yaml)
      end
    end
  end
end
