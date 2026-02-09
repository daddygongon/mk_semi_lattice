#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'date'

class MkStack
  def initialize(argv)
    @options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: hc stack [options]"
      opts.on('-n NUMBER', '--number=NUMBER', 'Add ordinal number') { |num| @options[:number] = num }
      opts.on('-d', '--dryrun', 'Dry run (do not move or create anything)') { @options[:dryrun] = true }
      opts.on('-D', 'Do not move directories (only move files)') { @options[:no_dir_move] = true }
      opts.on('-A', 'Do not move hidden files and directories') { @options[:no_hidden] = true }
      opts.on('-c', '--create', 'create (empty) stack only') { @options[:empty] = true }
      opts.on('-e', '--exec', 'execute stack making') { @options[:exec] = true }
      opts.on('-f', '--flatten', 'making stacks flatten') { @options[:flatten] = true }
    end.parse!(argv)

    @root_name = argv[0]
    @date = argv[1] || Date.today.strftime('%y%m%d')
  end

  def ordinal(n)
    abs_n = n.to_i.abs
    if (11..13).include?(abs_n % 100)
      "#{n}th"
    else
      case abs_n % 10
      when 1; "#{n}st"
      when 2; "#{n}nd"
      when 3; "#{n}rd"
      else    "#{n}th"
      end
    end
  end

  def pull_root_name(dir_name)
    if dir_name =~ /^_stack_(.+)_(\d{6})$/
      $1
    else
      dir_name
    end
  end

  def next_available_dir(root_name, date)
    n = 1
    if root_name =~ /^(\d+)(st|nd|rd|th)$/
      n = $1.to_i
    elsif root_name =~ /^(\d+)(st|nd|rd|th)_(.+)$/
      n = $1.to_i
    end

    candidates = Dir.glob("_stack_*_*").select do |d|
      d =~ /^_stack_(\d+)(st|nd|rd|th)_(\d{6})$/
    end
    if candidates.any?
      ordinals = candidates.map do |d|
        if d =~ /^_stack_(\d+)(st|nd|rd|th)_(\d{6})$/
          $1.to_i
        else
          nil
        end
      end.compact
      n = ordinals.max + 1
    end

    base_name = ordinal(n)
    dir = "_stack_#{base_name}_#{date}"
    [base_name, dir]
  end

  def find_max_ordinal
    candidates = Dir.glob("_stack_*_*").select { |d| d =~ /^_stack_(\d+)(st|nd|rd|th)_(\d{6})$/ }
    ordinals = candidates.map do |d|
      if d =~ /^_stack_(\d+)(st|nd|rd|th)_(\d{6})$/
        $1.to_i
      else
        nil
      end
    end.compact
    ordinals.any? ? ordinals.max : 0
  end

  def ensure_root_name
    if @root_name.nil? || @root_name.strip.empty?
      max_num = find_max_ordinal
      @root_name = max_num > 0 ? ordinal(max_num) : "1st"
    end
  end

  def create_dir(dir)
    if @options[:dryrun]
      puts "[Dry Run] Would create directory: #{dir}"
    else
      Dir.mkdir(dir) unless Dir.exist?(dir)
      puts "Created directory: #{dir}"
    end
  end

  def move_entries(dir)
    exclude = ['.', '..', dir, '.vscode', 'project.code-workspace']
    entries = Dir.glob('*', File::FNM_DOTMATCH) - exclude

    # -Aオプションが指定された場合、ドットで始まるファイル/ディレクトリを除外
    if @options[:no_hidden]
      entries.reject! { |entry| entry.start_with?('.') }
    end

    # -e/--empty オプションが指定された場合、_stackで始まるディレクトリのみ移動
    if @options[:empty]
      entries.select! { |entry| File.directory?(entry) && entry.start_with?('_stack') }
    end

    entries.each do |entry|
      next if @options[:no_dir_move] && File.directory?(entry)
      if @options[:dryrun]
        puts "[Dry Run] Would move #{entry} to #{dir}"
      else
        FileUtils.mv(entry, dir, force: true)
      end
    end

    if @options[:dryrun]
      puts "[Dry Run] Would move #{entries.empty? ? 'nothing' : entries.join(', ')} to #{dir}"
    else
      puts "Moved #{entries.empty? ? 'nothing' : entries.join(', ')} to #{dir}"
    end
  end

  def execute
    ensure_root_name
    @root_name, dir = next_available_dir(@root_name, @date)
    create_dir(dir)
    move_entries(dir)
  end
end

if __FILE__ == $0
  MkStack.new(ARGV).execute
end
