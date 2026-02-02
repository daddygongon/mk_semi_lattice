# -*- coding: utf-8 -*-
require "colorize"
require 'command_line/global'
require 'fileutils'

task :default do
  puts "Name: Rakefile for making sample_check.tgz"
  puts "> cd etymological_builder/p1_main_root #, and"
  puts "> rake deploy:mk_check_tgz"
  puts "\nIn order to see tasks, it is necessary to do:"
  puts "> rake -f ./Rakefile_mk_sample_tgz.rake -T"
end

namespace :learn do
  desc "whole vocabulary check"
  task :check do
    puts "hc check -i 5 -q 5 -a 8  #on top dir"
    puts "hc check  #at each dir"
  end

  desc "rm word_log and check_log"
  task :clean do
    ['**/check_log.yaml',
     './check_log.yaml',
     '**/word_log.yaml',
    './word_log.yaml'].each do |file|
      p comm="rm -f #{file}"
      system comm
    end
  end

  desc "new stack"
  task :stack do
    puts "cd r18_mit"
    puts "hc stack"
    puts "cp _stack_.../dir_tree.yaml ."
    puts "mv _stack_.../r18....pdf ."
  end

  desc "plot training history and score"
  task :plot do
    puts "hc plot    # for training history"
    puts "hc plot -s # for plot score"
  end
end

namespace :deploy do
  desc "swap to translated/sample sentence"
  task :swap_sentence do
    file = ARGV[1] || 'r1_2_sta_sist_situ/dir_tree.yaml'
    File.readlines(file).each do |line|
      #  p line
      if line =~ /^#/ || line.strip == '' || line.chomp == '---'
        puts line
        next
      end
      orig_line = line
      line = line.lstrip  # 最初の空白を読み飛ばす
      leading_spaces = orig_line[/^\s*/]  # 最初の空白を取得
      line = line.chomp[0..-2]
      parts = line.split('=')
      subparts = parts[1].split('/', 2)
      # 新しい形式: [空白][英単語]=[日本語訳]=[日本語訳/英語例文]:
      word = parts[0]
      intermit = subparts[0]
      sentence = subparts[1]
      translated = parts[2]
      new_line = "#{leading_spaces}#{word}=#{intermit}=#{translated}/#{sentence}:"
      puts new_line
    end
  end

  def collect_dir_trees(dir, glob_pattern, target_dir_proc)
    FileUtils.mkdir(dir) unless File.exist?(dir)
    FileUtils.cp('Rakefile', dir, verbose: true)

    Dir.glob(glob_pattern).each do |file|
      t_dir = target_dir_proc.call(dir, file)
      FileUtils.mkdir_p(t_dir, verbose: true)
      p [file, t_dir]
      p t_file = File.join(t_dir, "dir_tree.yaml")
      unless File.exist?(t_file)
        FileUtils.cp(file, t_dir, verbose: true)
      else
        File.write(t_file, File.read(file), mode: "a")
      end
    end
    #  exit
  end

  desc "collect init dir_tree.yamls"
  task :init_dirs do
    dir = ARGV[1] || '_stack_init_dirs'
    collect_dir_trees(
      dir,
      "**/_stack_1st_*/dir_tree.yaml",
      ->(dir, file) { File.join(dir, file.split('/')[0], "_stack_init") }
    )

    Dir.glob('*/*.pdf').each do |file|
      t_dir = File.join(dir, file.split('/')[0])
      FileUtils.cp(file, t_dir, verbose: true)
    end
    exit
  end

  desc "collect init check dir_tree.yamls"
  task :init_check do
    dir = ARGV[1] || '_stack_init_check_dirs'
    collect_dir_trees(
      dir,
      "**/_stack_1st_*/dir_tree.yaml",
      ->(dir, file) { File.join(dir, file.split('/')[0]) }
    )
  end

  desc "collect final check dir_tree.yamls"
  task :final_check do
    dir = ARGV[1] || '_stack_final_check_dirs'
    collect_dir_trees(
      dir,
      "*/dir_tree.yaml",
      ->(dir, file) { File.join(dir, file.split('/')[0]) }
    )
  end

  def change_equal_to_slash(lines)
    # 'key=v1=v2' -> 'key=v1/v2'
    lines.map do |line|
      if line =~ /^\s*([^=]+=[^=]+)=(.+)/
        # 最初の = で2分割し、残りの = を / に
        key, rest = line.split('=', 2)
        rest = rest.gsub('=', '/')
        "#{key}=#{rest}"
      else
        line
      end
    end
  end
  require 'date'
  desc "strip # from dir_tree.yaml"
  task :strip_sharp_from_final do
    dir = ARGV[1] || '_stack_final_check_dirs'
    Dir.glob("#{dir}/**/dir_tree.yaml").each do |file|
      lines = File.readlines(file).map { |line| line.gsub(/^# /, '') }
      lines = change_equal_to_slash(lines)
      File.write(file, lines.join)
    end 
  end

  desc "strip # from dir_tree.yaml"
  task :strip_separator_from_init do
    # strip '---' except first one from init dir_tree.yamls
    dir = ARGV[1] || '_stack_init_check_dirs'
    Dir.glob("#{dir}/**/dir_tree.yaml").each do |file|
      lines = File.readlines(file)
      found = false
      new_lines = lines.reject do |line|
        if line.strip == "---"
          if found
            true  # 2つ目以降の '---' を削除
          else
            found = true
            false # 最初の '---' は残す
          end
        else
          false
        end
      end
      File.write(file, new_lines.join)
    end 
  end

  desc "collect check.tgz"
  task :mk_check_tgz => [:init_check, 
  :final_check, 
  :strip_sharp_from_final,
  :strip_separator_from_init
  ] do
    date = Date.today.strftime('%y%m%d')
    t_name= "etymological_builder_check_#{date}.tgz"
    dirs = "_stack_final_check_dirs _stack_init_check_dirs"
    system "tar -cvf #{t_name} #{dirs}"
    system "rm -rf #{dirs}"
    exit
  end
end
