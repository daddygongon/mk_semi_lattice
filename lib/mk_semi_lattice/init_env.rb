# frozen_string_literal: true
require 'yaml'
require 'fileutils'
require 'colorize'

module InitEnv
  def self.init_env(parent_dir)
    Config.setup
    Log.event("started", parent_dir: parent_dir)
  end

  class Config
    CONFIG_DIR = File.expand_path("~/.config/semi_lattice")
    CONF_PATH = File.join(CONFIG_DIR, "semi_lattice.conf")
    LOG_PATH = File.join(CONFIG_DIR, "semi_lattice_history")

    @conf = { "log" => false }

    class << self
      attr_reader :conf

      def setup
        FileUtils.mkdir_p(CONFIG_DIR)
        load_conf
      end

      def load_conf
        if File.file?(CONF_PATH)
          begin
            loaded = YAML.load_file(CONF_PATH)
            if loaded.is_a?(Hash)
              @conf.merge!(loaded)
            else
              puts "Warning: #{CONF_PATH} is not a hash. Using default config.".yellow
            end
          rescue
            puts "Warning: #{CONF_PATH} is invalid. Using default config.".yellow
          end
        end
      end

      def save_conf
        File.write(CONF_PATH, @conf.to_yaml)
      end

      def log_enabled?
        @conf["log"]
      end

      def set_log(value)
        @conf["log"] = value
        save_conf
      end

      def log_path
        LOG_PATH
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
