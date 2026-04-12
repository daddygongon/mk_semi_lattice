# -*- coding: utf-8 -*-
require "colorize"
require 'yaml'
require 'fileutils'
require 'optparse'

class MkLightTable
  def initialize(argv)
    @options = {}
    @opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($0)} [options]"
      opts.on('-d [DIR]', '--dir [DIR]', 'Target directory for mk_yaml (default: .)') do |dir|
        @options[:dir] = dir || '.'
        @options[:action] = :dir
      end
      opts.on('-y', '--yaml', 'Output sample YAML') do
        @options[:action] = :sample
      end
      opts.on('-o FILE', '--generate-org=FILE', 'Generate Org file') do |file|
        @options[:yaml_file] = file
        @options[:action] = :generate_org
      end
      opts.on('-g FILE', '--generate-html=FILE', 'Generate HTML') do |file|
        @options[:yaml_file] = file
        @options[:action] = :generate_html
      end
    end
    @opts.parse!(argv)
  end

  def run
    case @options[:action]
    when :sample
      puts_sample_yaml
    when :generate_org
      generate_org(@options[:yaml_file])
    when :generate_html
      generate_html(@options[:yaml_file])
    when :dir
      actual_dir = File.expand_path(@options[:dir])
      dir_name = File.basename(actual_dir)
      yaml_file = "#{dir_name}.yaml"

      if File.exist?(yaml_file)
        puts "Warning: Target file ('#{yaml_file}') already exists."
        puts "Please delete it first before running this command."
        return
      end

      mk_yaml(@options[:dir], yaml_file)
      puts "Note: To generate an HTML file from this YAML, please run the command with the -g option:"
      puts "      #{File.basename($0)} -g #{yaml_file}"
    else
      puts @opts
    end
  end

  def generate_html(yaml_file = nil)
    output_dir = '.' # or some other configurable directory
    base_name = File.basename(yaml_file || @options[:yaml_file] || 'light_table.yaml', '.yaml')
    html_path = File.join(output_dir, "#{base_name}.html")
    css_path = File.join(output_dir, 'style.css')
    source_css_path = File.join(__dir__, 'style.css')

    toc = YAML.load_file(yaml_file || @options[:yaml_file] || 'light_table.yaml')
    html = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Light Table</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div id="table-of-contents">
    <h2>Table of Contents</h2>
    <ul>
      #{toc.map.with_index { |section, i| "<li><a href=\"#section-#{i}\">#{section[:head]}</a></li>" }.join("\n      ")}
    </ul>
  </div>
  <div id="content">
    <h1 class="title">Light Table</h1>
    #{toc.map.with_index do |section, i|
      images = section[:files].map do |file|
        "<img src=\"#{file}\" alt=\"#{File.basename(file)}\" loading=\"lazy\">"
      end.join("\n        ")

      <<-SECTION
      <h2 id="section-#{i}">#{section[:head]}</h2>
      <div class="outline-text-2">
        <p>
          #{images}
        </p>
      </div>
      SECTION
    end.join("\n")}
  </div>
</body>
</html>
    HTML
    File.write(html_path, html)
    puts "HTML written to #{html_path}"

    if !File.exist?(css_path) && File.exist?(source_css_path)
      FileUtils.cp(source_css_path, css_path)
      puts "Copied style.css to #{output_dir}"
    end
  end

  def generate_org(yaml_file = nil)
    base_name = File.basename(yaml_file || @options[:yaml_file] || 'light_table.yaml', '.yaml')
    org_path = "#{base_name}.org"
    
    if File.exist?(org_path)
      puts "Error: Target file ('#{org_path}') already exists."
      puts "Please delete it first before running this command."
      return
    end

    toc = YAML.load_file(yaml_file || @options[:yaml_file] || 'light_table.yaml')

    org_content = []
    
    local_template = 'template.org'
    source_template = File.join(__dir__, 'template.org')

    if File.exist?(local_template)
      org_content << File.read(local_template)
      org_content << ""
    elsif File.exist?(source_template)
      org_content << File.read(source_template)
      org_content << ""
    else
      org_content << "#+TITLE: Light Table"
      org_content << ""
    end

    toc.each do |section|
      org_content << "* #{section[:head]}"
      section[:files].each do |file|
        org_content << "  [[file:#{file}]]"
      end
      org_content << ""
    end

    File.write(org_path, org_content.join("\n"))
    puts "Org written to #{org_path}"

    css_path = 'style.css'
    source_css_path = File.join(__dir__, 'style.css')
    if !File.exist?(css_path) && File.exist?(source_css_path)
      FileUtils.cp(source_css_path, css_path)
      puts "Copied style.css to ."
    end
  end

  # ディレクトリからyamlを作成
  def mk_yaml(t_dir = nil, out_file = 'light_table.yaml')
    t_dir ||= @options[:dir]
    t_dir = '.' if t_dir.nil? || t_dir.empty?
    puts t_dir
    toc = [{head: File.basename(t_dir), files: []}]
    
    valid_exts = %w[.png .jpg .jpeg .gif .svg .webp .mp4 .mov .webm .avi]
    Dir.glob(File.join(t_dir, '*')).each do |file_path|
      next unless valid_exts.include?(File.extname(file_path).downcase)
      toc[0][:files] << file_path
    end
    
    File.write(out_file, YAML.dump(toc))
    puts "YAML written to #{out_file}"
  end

  def puts_sample_yaml(t_file = 'light_table.yaml')
    if File.exist?(t_file)
      t_file = 'light_table_sample.yaml'
    end
    hc_array = [
      {head: "system layer and installers",
       files: ["sample_pngs/c2_install.008.png"]},
      {head: "specific command steps",
       files: ["sample_pngs/c2_install.010.png"]}
    ]
    puts YAML.dump(hc_array)
    File.write(t_file, YAML.dump(hc_array))
    puts "Save sample yaml in '#{t_file}'."
  end
end

if __FILE__ == $0
  MkLightTable.new(ARGV).run
end
