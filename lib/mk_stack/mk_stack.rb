#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'date'

module StackOperations
  class OptionParserWrapper
    attr_reader :options, :args

    def initialize(argv)
      @options = { flatten: false, nest: false, dryrun: true, reverse: false }
      @args = []
      OptionParser.new do |opts|
        opts.banner = "Usage: hc stack [options]"
        opts.on('-o ORDINAL', '--ordinal=ORDINAL', 'Add ordinal number') { |ord| @options[:ordinal] = ord }
        opts.on('-d', '--dryrun', 'Dry run (do not move or create anything)') { @options[:dryrun] = true }
        opts.on('-D', 'Do not move directories (only move files)') { @options[:no_dir_move] = true }
        opts.on('-A', 'Do not move hidden files and directories') { @options[:no_hidden] = true }
        opts.on('-c', '--create', 'Create (empty) stack only') { @options[:empty] = true }
        opts.on('-e', '--exec', 'Execute stack making') { @options[:dryrun] = false }
        opts.on('-f', '--flatten', 'Flatten stacks') { @options[:flatten] = true }
        opts.on('-n', '--nest', 'Nest stacks by _yymmdd') { @options[:nest] = true }
        opts.on('-r', '--reverse', 'Reverse _yymmdd order for nest') { @options[:reverse] = true }
      end.parse!(argv)
      @args = argv
    end
  end

  class MkStack
    def initialize(options, args)
      @options = options
      @root_name = args[0]
      @date = args[1] || Date.today.strftime('%y%m%d')
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
        puts "[Dry Run] mkdir #{dir}"
      else
        Dir.mkdir(dir) unless Dir.exist?(dir)
        puts "Created directory: #{dir}"
      end
    end

    def move_entries(dir)
      exclude = ['.', '..', dir, '.vscode', 'project.code-workspace']
      entries = Dir.glob('*', File::FNM_DOTMATCH) - exclude

      if @options[:no_hidden]
        entries.reject! { |entry| entry.start_with?('.') }
      end

      if @options[:empty]
        entries.select! { |entry| File.directory?(entry) && entry.start_with?('_stack') }
      end

      entries.each do |entry|
        next if @options[:no_dir_move] && File.directory?(entry)
        if @options[:dryrun]
          puts "[Dry Run] mv #{entry} (to) #{dir}"
        else
          FileUtils.mv(entry, dir, force: true)
        end
      end

      if @options[:dryrun]
        puts "[Dry Run] mv #{entries.empty? ? 'nothing' : entries.join(', ')} (to) #{dir}"
      else
        puts "Moved #{entries.empty? ? 'nothing' : entries.join(', ')} to #{dir}"
      end
    end

    def run
      ensure_root_name
      @root_name, dir = next_available_dir(@root_name, @date)
      create_dir(dir)
      move_entries(dir)
    end
  end

  class MkFlatten
    def initialize(options, args)
      @options = options
      @target_dir = args[0] || "."
      @target_dir = @target_dir.chomp("/")
    end

    # 指定ディレクトリ以下のtree構造を表示（ディレクトリのみ）
    def print_tree(dir, prefix = "", is_last_arr = [])
      puts "#{prefix}#{File.basename(dir)}"
      if File.directory?(dir)
        entries = Dir.children(dir).sort.select { |entry| File.directory?(File.join(dir, entry)) }
        entries.each_with_index do |entry, idx|
          path = File.join(dir, entry)
          is_last = idx == entries.size - 1
          # インデント生成
          new_prefix = ""
          is_last_arr.each { |last| new_prefix += last ? "    " : "│   " }
          new_prefix += is_last ? "└── " : "├── "
          print_tree(path, new_prefix, is_last_arr + [is_last])
        end
      end
    end

    # flatten後のtree構造を表示（@target_dir直下に全ての_stack_*_*ディレクトリを並べる）
    def print_flattened_tree
      stacks = []
      search_dirs = Dir.glob(File.join(@target_dir, "**/_stack_*_*")).select { |d| File.directory?(d) }
      # ルート直下の_stack_*_*も含める
      root_stacks = Dir.glob(File.join(@target_dir, "_stack_*_*")).select { |d| File.directory?(d) }
      all_stacks = (root_stacks + search_dirs).uniq
      all_stacks.map! { |d| File.basename(d) }
      all_stacks.each do |d|
        puts "└── #{d}"
      end
    end

    # flattenで移動するディレクトリのmvコマンドをdryrun表示
    def print_flatten_moves
      flatten_moves.each do |src, dest|
        puts "[Dry Run] mv '#{src}' '#{dest}'"
      end
    end

    def flatten_moves
      stacks = Dir.glob(File.join(@target_dir, "**/_stack_*_*")).select { |d| File.directory?(d) }
      stacks.sort_by! { |d| -d.count(File::SEPARATOR) }
      stacks.map { |src| [src, File.join(".", File.basename(src))] }
    end

    def execute_flatten_moves
      flatten_moves.each do |src, dest|
        # mv元とmv先が同じ場合はスキップ
        if File.expand_path(src) == File.expand_path(dest)
          puts "[Skip] mv '#{src}' '#{dest}' (same path)"
          next
        end
        puts "mv '#{src}' '#{dest}'"
        FileUtils.mv(src, dest)
      end
    end

    def run
      puts "Before flatten:"
      puts "."
      print_tree(@target_dir, "", [])
      puts "\nAfter flatten:"
      puts "."
      print_flattened_tree
      puts "\nFlatten moves:"
      if @options[:dryrun]
        print_flatten_moves
      else
        execute_flatten_moves
      end
    end
  end

  class MkNest
    def initialize(options, args)
      @options = options
      @target_dir = args[0] || "."
    end

    # yymmdd順に並べ替え（reverseオプションで順序切替）
    def sorted_stacks
      stacks = Dir.glob(File.join(@target_dir, "_stack_*_*"))
         .select { |d| File.directory?(d) && d =~ /_stack_.+_\d{6}$/ }
         .sort_by { |d| d[/_stack_.+_(\d{6})$/, 1].to_i }
        #.select { |d| File.directory?(d) }
        #.sort_by { |d| d[/^_stack_(\d+)(st|nd|rd|th)_/, 1].to_i }
      @options[:reverse] ? stacks : stacks.reverse
    end

    # ディレクトリのみtree表示
    def print_tree(dir, prefix = "", is_last_arr = [])
      puts "#{prefix}#{File.basename(dir)}"
      if File.directory?(dir)
        entries = Dir.children(dir).sort.select { |entry| File.directory?(File.join(dir, entry)) }
        entries.each_with_index do |entry, idx|
          path = File.join(dir, entry)
          is_last = idx == entries.size - 1
          # インデント生成
          new_prefix = ""
          is_last_arr.each { |last| new_prefix += last ? "    " : "│   " }
          new_prefix += is_last ? "└── " : "├── "
          print_tree(path, new_prefix, is_last_arr + [is_last])
        end
      end
    end

    # nest後のtree構造を表示
    def print_nested_tree
      p stacks = sorted_stacks
      return if stacks.empty?
      puts "."
      stacks.each_with_index do |dir, idx|
        indent = "  " * idx + "└── "
        puts "#{indent}#{File.basename(dir)}"
      end
    end

    # nestのmvコマンド生成＆実行/表示
    def nest_moves
      stacks = sorted_stacks
      # 子から親へ（パスが変わらないように逆順でmv）
      moves = stacks.each_cons(2).to_a.reverse
      moves.each do |parent, child|
        dest = File.join(parent, File.basename(child))
        if @options[:dryrun]
          puts "[Dry Run] mv '#{child}' '#{dest}'"
        else
          puts "mv '#{child}' '#{dest}'"
          FileUtils.mkdir_p(parent) unless Dir.exist?(parent)
          FileUtils.mv(child, dest)
        end
      end
    end

    def run
      puts "Before nest:"
      puts "."
      print_tree(@target_dir, "", [])
      puts "\nAfter nest:"
      print_nested_tree
      puts "\nNest moves:"
      nest_moves
    end
  end
end

if __FILE__ == $0
  wrapper = StackOperations::OptionParserWrapper.new(ARGV)
  if wrapper.options[:flatten]
    StackOperations::MkFlatten.new(wrapper.options, wrapper.args).run
  elsif wrapper.options[:nest]
    StackOperations::MkNest.new(wrapper.options, wrapper.args).run
  else
    StackOperations::MkStack.new(wrapper.options, wrapper.args).run
  end
end
