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
      opts.on('-o[FILE]', '--generate-org=[FILE]', 'Generate Org file') do |file|
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
      puts "      hc mk_light_table -g #{yaml_file}"
    else
      puts @opts
    end
  end

  def generate_html(yaml_file = nil)
    output_dir = '.' # or some other configurable directory
    target_yaml = yaml_file || @options[:yaml_file] || "#{File.basename(Dir.pwd)}.yaml"
    base_name = File.basename(target_yaml, '.yaml')
    html_path = File.join(output_dir, "#{base_name}.html")

    if File.exist?(html_path)
      puts "Error: Target file ('#{html_path}') already exists."
      puts "Please delete it first before running this command."
      return
    end

    css_path = File.join(output_dir, 'style.css')
    source_css_path = File.join(__dir__, 'style.css')

    actual_yaml = File.exist?(target_yaml) ? target_yaml : 'light_table.yaml'
    toc = YAML.load_file(actual_yaml)
    html = <<-HTML
<!DOCTYPE html>
<html>
<head>ls

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
      images_table = "<table class=\"light-table\" style=\"width: 100%; border-collapse: collapse;\">\n"
      section[:files].each_slice(3) do |row|
        images_table << "          <tr>\n"
        row.each do |file|
          images_table << "            <td style=\"padding: 5px; vertical-align: top; width: 33.33%;\">\n"
          images_table << "              <a href=\"#{file}\" target=\"_blank\">\n"
          images_table << "                <img src=\"#{file}\" alt=\"#{File.basename(file)}\" loading=\"lazy\" style=\"width: 100%; height: auto; display: block;\">\n"
          images_table << "              </a>\n"
          images_table << "            </td>\n"
        end
        (3 - row.size).times do
          images_table << "            <td style=\"padding: 5px; width: 33.33%;\"></td>\n"
        end
        images_table << "          </tr>\n"
      end
      images_table << "        </table>"

      <<-SECTION
      <h2 id="section-#{i}">#{section[:head]}</h2>
      <div class="outline-text-2">
        #{images_table}
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
    # 引数がない場合はカレントディレクトリ名を使用
    target_yaml = yaml_file || @options[:yaml_file] || "#{File.basename(Dir.pwd)}.yaml"
    base_name = File.basename(target_yaml, '.yaml')
    org_path = "#{base_name}.org"
    
    if File.exist?(org_path)
      org_path = "readme.org"
      if File.exist?(org_path)
        puts "Error: Target files ('#{base_name}.org' and 'readme.org') already exist."
        puts "Please delete it first before running this command."
        return
      end
    end

    local_template = 'template.org'
    source_template = File.join(__dir__, 'template.org')

    actual_yaml = File.exist?(target_yaml) ? target_yaml : 'light_table.yaml'
    
    # YAMLファイルが存在しない場合はテンプレートのコピーのみ行う
    unless File.exist?(actual_yaml)
      if File.exist?(local_template)
        FileUtils.cp(local_template, org_path)
      elsif File.exist?(source_template)
        FileUtils.cp(source_template, org_path)
      else
        File.write(org_path, "#+TITLE: #{base_name}\n\n")
      end
      puts "Copied template to #{org_path} (YAML not found)"
      
      css_path = 'style.css'
      source_css_path = File.join(__dir__, 'style.css')
      if !File.exist?(css_path) && File.exist?(source_css_path)
        FileUtils.cp(source_css_path, css_path)
        puts "Copied style.css to ."
      end
      
      return
    end

    toc = YAML.load_file(actual_yaml)
    org_content = []

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
