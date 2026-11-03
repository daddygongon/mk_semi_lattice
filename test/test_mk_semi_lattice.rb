# frozen_string_literal: true


require "test_helper"
require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
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
    icons_dir = File.join(TEST_DIR, '.semi_lattice', 'icons')
    %w[file.png stack.png].each { |name| FileUtils.rm_f(File.join(icons_dir, name)) }
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

  def test_default_icons_include_stack
    Dir.mktmpdir do |dir|
      InitEnv::MkSemiLatticeDir.copy_default_icons(dir)

      assert File.exist?(File.join(dir, 'stack.png'))
    end
  end
end

class TestStackIcon < Minitest::Test
  def setup
    @original_image = Object.const_get(:Image) if Object.const_defined?(:Image)
    @original_text = Object.const_get(:Text) if Object.const_defined?(:Text)
    Object.send(:remove_const, :Image) if Object.const_defined?(:Image)
    Object.send(:remove_const, :Text) if Object.const_defined?(:Text)
    Object.const_set(:Image, Class.new do
      def initialize(path, **attrs)
        @path = path
        attrs.each { |name, value| instance_variable_set("@#{name}", value) }
      end

      attr_accessor :path, :x, :y, :width, :height, :z
    end)
    Object.const_set(:Text, Class.new do
      def initialize(_value, **attrs)
        attrs.each { |name, value| instance_variable_set("@#{name}", value) }
      end

      attr_accessor :x, :y
      attr_reader :width
    end)
  end

  def teardown
    Object.send(:remove_const, :Image)
    Object.send(:remove_const, :Text)
    Object.const_set(:Image, @original_image) if @original_image
    Object.const_set(:Text, @original_text) if @original_text
  end

  def test_stack_node_uses_stack_png
    node = SLComponents::Node.new(
      type: 'stack', label: 'Phase diagram 26f', x: 100, y: 120
    )
    node.create_graphics
    icon = node.instance_variable_get(:@circle)
    image = icon.instance_variable_get(:@image)

    assert_instance_of SLComponents::StackIcon, icon
    assert_equal '.semi_lattice/icons/stack.png', image.path
  end
end
