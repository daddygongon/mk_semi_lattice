#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'date'


module StackOperations
  class OptionParserWrapper
    attr_reader :options, :args

    def initialize(argv)
      @options = { flatten: false, nest: false, dryrun: true, reverse: false, empty: false, no_dir_move: false }
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

  class MkTree
    def mk_dir_tree(dir, current_level = 1, max_level = 2, dirs_only: false)
      tree = {}
      return tree unless File.directory?(dir)

      Dir.children(dir).sort.each do |entry|
        path = File.join(dir, entry)
        is_dir = File.directory?(path)
        next if dirs_only && !is_dir

        if is_dir
          tree[entry] = current_level < max_level ? mk_dir_tree(path, current_level + 1, max_level, dirs_only: dirs_only) : {}
        else
          tree[entry] = nil
        end
      end
      tree
    end

    def print_tree(tree, is_last_arr = [])
      entries = tree.keys
      entries.each_with_index do |entry, idx|
        is_last = idx == entries.size - 1
        prefix = ""
        is_last_arr.each { |last| prefix += last ? "    " : "│   " }
        prefix += is_last ? "└── " : "├── "
        
        is_dir = tree[entry].is_a?(Hash)
        name = is_dir ? "#{entry}/" : entry
        puts "#{prefix}#{name}"
        
        if is_dir
          print_tree(tree[entry], is_last_arr + [is_last])
        end
      end
    end
  end

  class MkStack < MkTree
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
      ordinals = candidates.map { |d| d[/^_stack_(\d+)/, 1].to_i }.compact
      ordinals.any? ? ordinals.max : 0
    end
    def ensure_root_name
      if @root_name.nil? || @root_name.empty?
        max_num = find_max_ordinal
        @root_name = max_num > 0 ? "#{max_num}th" : "1st"
      end
    end
    def run
      ensure_root_name
      @root_name, dir = next_available_dir(@root_name, @date)

      # 1. 現在のツリーを取得
      current_tree = mk_dir_tree(".", 1, 1)

      # 2. 移動対象の決定
      exclude = ['.', '..', dir, '.vscode', 'project.code-workspace', '.git']
      all_entries = Dir.glob('*', File::FNM_DOTMATCH) - exclude
      moved_entries = []
      
      unless @options[:empty]
        all_entries.each do |entry|
          next if @options[:no_dir_move] && File.directory?(entry)
          moved_entries << entry
        end
      end

      # 3. 仮想ツリーの構築 (Hashの操作としてmvをシミュレート)
      virtual_tree = {}
      current_tree.each do |k, v|
        virtual_tree[k] = v unless moved_entries.include?(k)
      end
      
      moved_tree = {}
      moved_entries.each do |entry|
        moved_tree[entry] = current_tree[entry]
      end
      virtual_tree[dir] = moved_tree
      virtual_tree = virtual_tree.sort.to_h

      # 4. Before表示
      puts "Before stack:"
      puts "."
      print_tree(current_tree)

      # 5. 操作の表示 (Dry Run or Execute)
      puts "\nOperations:"
      prefix = @options[:dryrun] ? "[Dry Run] " : ""
      puts "#{prefix}mkdir #{dir}"
      if moved_entries.empty?
        puts "#{prefix}mv nothing (to) #{dir}"
      else
        moved_entries.each do |entry|
          puts "#{prefix}mv #{entry} (to) #{dir}"
        end
      end

      # 6. After表示
      puts "\nAfter stack:"
      puts "."
      print_tree(virtual_tree)

      # 7. 実行 (-e 指定時)
      unless @options[:dryrun]
        Dir.mkdir(dir) unless Dir.exist?(dir)
        moved_entries.each do |entry|
          FileUtils.mv(entry, dir)
        end
        puts "\nExecution completed."
      end
    end
  end

  class MkFlatten < MkTree
    def initialize(options, args)
      @options = options
      @target_dir = args[0] || "."
      @target_dir = @target_dir.chomp("/")
    end
    def build_virtual_tree
      search_dirs = Dir.glob(File.join(@target_dir, "**/_stack_*_*")).select { |d| File.directory?(d) }
      root_stacks = Dir.glob(File.join(@target_dir, "_stack_*_*")).select { |d| File.directory?(d) }
      all_stacks = (root_stacks + search_dirs).uniq
      
      tree = {}
      all_stacks.map { |d| File.basename(d) }.sort.each do |d|
        tree[d] = {}
      end
      tree
    end
    def flatten_moves
      search_dirs = Dir.glob(File.join(@target_dir, "**/_stack_*_*")).select { |d| File.directory?(d) }
      root_stacks = Dir.glob(File.join(@target_dir, "_stack_*_*")).select { |d| File.directory?(d) }
      stacks = (root_stacks + search_dirs).uniq
      
      # 深い階層から順に移動させるため、パスの深さで降順ソート
      stacks.sort_by! { |d| -d.count('/') }
      
      moves = []
      stacks.each do |src|
        dest = File.join(@target_dir, File.basename(src))
        moves << [src, dest] unless src == dest
      end
      moves
    end
    def run
      puts "Before flatten:"
      puts @target_dir == "." ? "." : "#{File.basename(@target_dir)}/"
      print_tree(mk_dir_tree(@target_dir, 1, 999, dirs_only: true))

      moves = flatten_moves

      puts "\nOperations:"
      prefix = @options[:dryrun] ? "[Dry Run] " : ""
      if moves.empty?
        puts "#{prefix}nothing to flatten"
      else
        moves.each do |src, dest|
          puts "#{prefix}mv #{src} (to) #{dest}"
        end
      end

      puts "\nAfter flatten:"
      puts "."
      print_tree(build_virtual_tree)

      unless @options[:dryrun]
        moves.each do |src, dest|
          FileUtils.mv(src, dest)
        end
        puts "\nExecution completed."
      end
    end
  end

  class MkNest < MkTree
    def initialize(options, args)
      @options = options
      @target_dir = args[0] || "."
    end
    def sorted_stacks
      stacks = Dir.glob(File.join(@target_dir, "_stack_*_*")).select { |d| File.directory?(d) }
      stacks = stacks.sort_by { |d| d[/_stack_(\d+)(st|nd|rd|th)_/, 1].to_i }
      # デフォルトはFILO（新しいものがルート: 7th, 6th, 5th...）
      # -r オプションでFIFO（古いものがルート: 1st, 2nd, 3rd...）
      @options[:reverse] ? stacks : stacks.reverse
    end
    def build_virtual_tree
      stacks = sorted_stacks
      tree = {}
      return tree if stacks.empty?
      
      current = tree
      stacks.each do |dir|
        name = File.basename(dir)
        current[name] = {}
        current = current[name]
      end
      tree
    end
    def nest_moves
      stacks = sorted_stacks
      moves = []
      return moves if stacks.size < 2
      
      # ENOENTエラーを防ぐため、一番奥（深い階層）に入るものから順に親へ移動する
      # 例: stacks = [7th, 6th, 5th] の場合
      # 1. 5th を 6th へ移動
      # 2. 6th を 7th へ移動
      (0...stacks.size - 1).to_a.reverse.each do |i|
        parent = stacks[i]
        child = stacks[i + 1]
        dest = File.join(parent, File.basename(child))
        moves << [child, dest]
      end
      moves
    end
    def run
      puts "Before nest:"
      puts @target_dir == "." ? "." : "#{File.basename(@target_dir)}/"
      print_tree(mk_dir_tree(@target_dir, 1, 999, dirs_only: true))

      moves = nest_moves

      puts "\nOperations:"
      prefix = @options[:dryrun] ? "[Dry Run] " : ""
      if moves.empty?
        puts "#{prefix}nothing to nest"
      else
        moves.each do |child, dest|
          puts "#{prefix}mv #{child} (to) #{dest}"
        end
      end

      puts "\nAfter nest:"
      puts "."
      print_tree(build_virtual_tree)

      unless @options[:dryrun]
        moves.each do |child, dest|
          FileUtils.mv(child, dest)
        end
        puts "\nExecution completed."
      end
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
