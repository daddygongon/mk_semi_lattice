# -*- coding: utf-8 -*-
require "colorize"
require 'yaml'
require 'fileutils'
require 'optparse'

class SplitPDF
  def initialize(argv)
    @options = {}
    OptionParser.new do |opts|
      opts.on('-d[DIR]', '--dir=[DIR]', 'Target directory for mk_yaml (default: .)') do |dir|
        @options[:dir] = dir || '.'
        @options[:action] = :dir
      end
      opts.on('-s [YAML]', '--split [YAML]', 'Split pdf wo pages by YAML (default: hc_array.yaml)') do |yaml|
        @options[:yaml] = yaml || 'hc_array.yaml'
        @options[:action] = :split_without_pages
      end
      opts.on('-w [YAML]', '--split_with_pages [YAML]', 'Split pdf with pages by YAML (default: hc_array.yaml)') do |yaml|
        @options[:yaml] = yaml || 'hc_array.yaml'
        @options[:action] = :split_with_pages
      end      
      opts.on('-y', '--yaml', 'Output sample YAML') do
        @options[:action] = :sample
      end
    end.parse!(argv)
  end

  def run
    case @options[:action]
    when :sample
      puts_sample_yaml
    when :dir
      mk_yaml
    when :split_without_pages
      split_pdf(true) # option: pages_wo
    when :split_with_pages
      split_pdf(false)
    else
      # OptionParserがusageを表示するので何もしない
    end
  end

  # ディレクトリからyamlを作成
  def mk_yaml(t_dir = nil, out_file = 'tmp.yaml')
    t_dir ||= @options[:dir]
    t_dir = '.' if t_dir.nil? || t_dir.empty?
    puts t_dir
    toc = []
    Dir.glob(File.join(t_dir, '*')).each do |file|
      data = File.basename(file, '.pdf').split('_')
      pages = data[1].split('-')
      new_data = {
        no: data[0],
        init: pages[0].to_i,
        fin:  pages[1].to_i,
        head: data[2..-1].join("_")
      }
      toc << new_data
    end
    File.write(out_file, YAML.dump(toc))
    puts "YAML written to #{out_file}"
  end

  # yamlを元にPDFを分割
  def split_pdf(pages_wo = true, yaml_file = nil)
    yaml_file ||= @options[:yaml]

    puts yaml_file
    data = YAML.load(File.read(yaml_file))
    source_file = data[:source_file]
    target_dir = data[:target_dir]
    FileUtils.mkdir_p target_dir unless Dir.exist? target_dir
    data[:toc].each do |v|
      init = v[:init]
      fin = v[:fin]
      pages = if fin.nil?
                fin = init
                "#{init}"
              else
                "#{init}-#{fin}"
              end
      if pages_wo
        o_file = [v[:no], v[:head]].compact.join('_') + ".pdf"
      else
        o_file = [v[:no], v[:head], pages].compact.join('_') + ".pdf"
      end
      target = File.join(target_dir, o_file)
      comm = "qpdf #{source_file} --pages . #{init}-#{fin} -- #{target}"
      puts comm
      system(comm)
    end
  end

  # サンプルyamlを出力
  def puts_sample_yaml(t_file = 'hc_array.yaml')
    # ファイルが存在する場合は新しいファイル名にする
    if File.exist?(t_file)
      t_file = 'hc_array_new.yaml'
    end
    hc_array = {
      source_file: './linux_basic.pdf',
      target_dir: './linux_basic',
      toc: [
        { no: nil, init: 1, fin: nil, head: 'title' },
        { no: 's1', init: 2, fin: nil, head: 'command' },
        { no: 's1', init: 7, fin: 7, head: 'line_edit' }
      ]
    }
    puts YAML.dump(hc_array)
    File.write(t_file, YAML.dump(hc_array))
    puts "Save yaml data in '#{t_file}'."
  end
end

if __FILE__ == $0
  SplitPDF.new(ARGV).run
end
