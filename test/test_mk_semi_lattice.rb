# frozen_string_literal: true


require "test_helper"
require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require_relative '../lib/mk_semi_lattice/init_env'

class TestMkSemiLattice < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::MkSemiLattice::VERSION
  end

  def test_it_does_something_useful
    assert true    # 仮の成功テスト
  end
end

class TestInitEnv < Minitest::Test
  TEST_DIR = File.expand_path('test_env', __dir__)
  CONFIG_DIR = File.join(TEST_DIR, '.config')
  CONF_PATH = File.join(CONFIG_DIR, 'semi_lattice.conf')

  def setup
    ENV['SEMI_LATTICE_CONFIG_DIR'] = File.expand_path('test_env/.config', __dir__)
    FileUtils.rm_rf(CONFIG_DIR)
    FileUtils.mkdir_p(CONFIG_DIR)
  end

  def teardown
    ENV.delete('SEMI_LATTICE_CONFIG_DIR')
  end

  def test_init_env_creates_config
    InitEnv.init_env(TEST_DIR)
    assert File.exist?(CONF_PATH), "semi_lattice.conf should exist in test_env/.config"
    loaded = YAML.load_file(CONF_PATH)
    assert loaded.is_a?(Hash), "Config file should be a hash"
  end

  def test_default_config_values
    InitEnv.init_env(TEST_DIR)
    loaded = YAML.load_file(CONF_PATH)
    assert_equal false, loaded["log"], "log should be false by default"
    assert_equal "open -a Terminal .", loaded["open_terminal_command"], "open_terminal_command should be default"
    assert_equal "open .", loaded["open_finder_command"], "open_finder_command should be default"
  end
end
