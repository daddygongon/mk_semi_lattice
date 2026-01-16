require "test_helper"
require "fileutils"
require_relative '../lib/mk_semi_lattice/manage_yaml/mk_semi_lattice_yaml'

class TestMkDirYaml < Minitest::Test
  TEST_DIR = File.expand_path('test_env', __dir__)

  def setup
    FileUtils.mkdir_p(TEST_DIR)
    @test_files = [
      "cur_sur",
      ".semi_lattice",
      "sl_shot.png",
      "dir_tree_node_edge.yaml",
      "dir_tree.yaml",
      ".DS_Store"
    ]
    @test_files.each { |f| FileUtils.touch(File.join(TEST_DIR, f)) }
  end

  def teardown
    @test_files.each { |f| FileUtils.rm_f(File.join(TEST_DIR, f)) }
  end

  def test_skip_name_for_various_entries_with_normal_visibility
    options = { visibility: 'normal' }
    mk_dir_yaml = ManageYaml::MkDirYaml.allocate
    mk_dir_yaml.instance_variable_set(:@options, options)

    sample = [
      ["cur_sur", false],
      [".semi_lattice", true],
      ["sl_shot.png", false],
      ["dir_tree_node_edge.yaml", false],
      ["dir_tree.yaml", false],
      [".DS_Store", true],
    ]

    sample.each do |entry, expected|
      full = File.join(TEST_DIR, entry)
      result = mk_dir_yaml.skip_name?(entry, full, nil)
#      p [entry, result, expected]
      assert_equal expected, result, "skip_name? for #{entry.inspect} should be #{expected}"
    end
  end

  def test_skip_name_for_various_entries_with_yaml_exclude
    options = { visibility: 'yaml_exclude' }
    mk_dir_yaml = ManageYaml::MkDirYaml.allocate
    mk_dir_yaml.instance_variable_set(:@options, options)

    sample = [
      ["cur_sur", false],
      [".semi_lattice", true],
      ["sl_shot.png", false],
      ["dir_tree_node_edge.yaml", true],
      ["dir_tree.yaml", true],
      [".DS_Store", true],
    ]

    sample.each do |entry, expected|
      full = File.join(TEST_DIR, entry)
      result = mk_dir_yaml.skip_name?(entry, full, nil)
#      p [entry, result, expected]
      assert_equal expected, result, "skip_name? (yaml_exclude) for #{entry.inspect} should be #{expected}"
    end
  end
end