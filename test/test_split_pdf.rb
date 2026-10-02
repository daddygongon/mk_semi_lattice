# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "yaml"
require_relative "../lib/split_pdf/split_pdf"

class TestSplitPDF < Minitest::Test
  def test_page_add_is_applied_to_init_and_fin
    Dir.mktmpdir do |dir|
      yaml_file = File.join(dir, "custom.yaml")
      target_dir = File.join(dir, "output")
      data = {
        source_file: "source.pdf",
        target_dir: target_dir,
        page_add: 10,
        toc: [
          { no: "c1", init: 1, fin: 3, head: "first" },
          { no: "c2", init: 4, fin: nil, head: "second" }
        ]
      }
      File.write(yaml_file, YAML.dump(data))

      commands = []
      splitter = SplitPDF.new([])
      splitter.define_singleton_method(:system) { |command| commands << command }
      splitter.split_pdf(false, yaml_file)

      assert_equal [
        "qpdf source.pdf --pages . 11-13 -- #{target_dir}/c1_first_11-13.pdf",
        "qpdf source.pdf --pages . 14-14 -- #{target_dir}/c2_second_14.pdf"
      ], commands
    end
  end

  def test_missing_page_add_defaults_to_zero
    Dir.mktmpdir do |dir|
      yaml_file = File.join(dir, "hc_array.yaml")
      target_dir = File.join(dir, "output")
      data = {
        source_file: "source.pdf",
        target_dir: target_dir,
        toc: [{ no: "c1", init: 2, fin: 5, head: "chapter" }]
      }
      File.write(yaml_file, YAML.dump(data))

      commands = []
      splitter = SplitPDF.new([])
      splitter.define_singleton_method(:system) { |command| commands << command }
      splitter.split_pdf(false, yaml_file)

      assert_equal [
        "qpdf source.pdf --pages . 2-5 -- #{target_dir}/c1_chapter_2-5.pdf"
      ], commands
    end
  end
end
