# frozen_string_literal: true
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