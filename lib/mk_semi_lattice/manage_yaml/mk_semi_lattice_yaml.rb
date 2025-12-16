# frozen_string_literal: true

module ManageYaml
  class MkSemiLattice
    def initialize(options)
      @parent_dir = options[:parent_dir]
      @semi_dir = options[:semi_dir]
      @semi_lattice_yaml_path = options[:semi_lattice_yaml_path]
      @options = options
      p @options
    end

    # ARGV[0]とoptionsから初期ファイル・初期ステップを決定
    def select_init_file_and_step
      p ['ARGV', ARGV]
      if (ARGV[0] == '.' || ARGV[0].nil?) && !@options[:file]
        if File.exist?(@semi_lattice_yaml_path)
          [@semi_lattice_yaml_path, :from_semi_lattice]
        else
          ['.', :from_dir]
        end
      else
        [ARGV[0], @options[:init_step]]
      end
    end

    # 初期ステップに応じて入力ファイルとwith_semi_lattice_yamlを決定
    def select_input_path_and_flag(init_file, init_step)
      case init_step
      when :from_dir
        Dir.mkdir(@semi_dir) unless Dir.exist?(@semi_dir)
        in_path = init_file
        out_path = File.join(@semi_dir, 'dir_tree.yaml')
        MkDirYaml.new(path: in_path, layer: @options[:layer], output_file: out_path, options: @options)
        in_path = out_path
        out_path = File.join(@semi_dir, 'dir_node_edge.yaml')
        MkNodeEdge.new(input_path: in_path, output_path: out_path)
        [out_path, false]
      when :from_tree
        init_file = @options[:file]
        base = File.basename(init_file, File.extname(init_file))
        in_path = init_file
        out_path = File.join(@parent_dir, "#{base}_node_edge.yaml")
        MkNodeEdge.new(input_path: in_path, output_path: out_path)
        [out_path, false]
      when :from_node_edge
        if File.exist?(File.join(@parent_dir, 'semi_lattice.yaml'))
          puts "Warning: semi_lattice.yaml already exists in current directory.".yellow
          exit 1
        end
        [@options[:file], false]
      when :from_semi_lattice
        [init_file, true]
      else
        raise "Unknown init_step: #{init_step}"
      end
    end

    # 新メソッド: 初期ファイル・ステップ・入力パス・フラグをまとめて取得
    def prepare_paths_and_flags
      init_file, init_step = select_init_file_and_step
      p ["init_file", init_file, init_step]
      input_path, with_semi_lattice_yaml = select_input_path_and_flag(init_file, init_step)
      p ["input_path", input_path, with_semi_lattice_yaml]
      [input_path, with_semi_lattice_yaml]
    end

    # アプリ終了時の状態保存
    def self.at_exit_action(app, semi_dir, parent_dir)
      nodes_data = app.nodes.map do |n|
        #p [n.label, n.fixed, n.color]
        {
          id: app.node_table.key(n),
          name: n.name,
          type: n.type,
          file_path: n.file_path,
          icon_path: n.icon_path,
          x: n.x,
          y: n.y,
          color: n.color,
          fixed: n.fixed
        }
      end
      edges_data = app.edges.map do |e|
        {
          from: app.node_table.key(e.from),
          to: app.node_table.key(e.to)
        }
      end

      yaml_data = { nodes: nodes_data, edges: edges_data }
      yaml_text = MkNodeEdge.add_edge_comments(yaml_data)
      if Dir.exist?(semi_dir)
        File.write(File.join(semi_dir, "semi_lattice.yaml"), yaml_text)
        puts "Semi-lattice state saved to #{File.join(semi_dir, "semi_lattice.yaml")}"
      else
        File.write(File.join('.', "semi_lattice.yaml"), yaml_text)
        puts "Semi-lattice state saved to #{File.join('.', "semi_lattice.yaml")}"
      end
      InitEnv::Log.event("exited", parent_dir: parent_dir)
    end
  end
 
  class MkDirYaml
    def initialize(path: '.', layer: 2, output_file: 'dir.yaml', options: nil)
      @options = options
      abs_path = File.expand_path(path)
      root_key = File.basename(abs_path) + '/'

      # layerの数だけ深さを調整
      result = { root_key => dir_tree(path, layer - 1) }
      p ["MkDirYaml result", result]
      File.write(output_file, result.to_yaml)
      puts "Directory structure exported to #{output_file}"
    end

    def build_ignore_regex(ignore_pattern)
      return nil unless ignore_pattern
      # '_stack_*|*.yaml' → /(?:\A_stack_.*\z|\A.*\.yaml\z)/
      regex_str = ignore_pattern.split('|').map do |pat|
        pat = pat.strip
        pat = Regexp.escape(pat).gsub('\*', '.*').gsub('\?', '.')
        "\\A#{pat}\\z"
      end.join('|')
      Regexp.new("(?:#{regex_str})")
    end

    def skip_name?(entry, full, ignore_regex)
      return true if entry.end_with?('~')
      return true if ignore_regex && entry.match(ignore_regex)
      case @options && @options[:visibility]
      when 'dir_only'
        return true if entry.start_with?('.') # 隠しディレクトリ除外
        return true unless File.directory?(full)
      when 'dir_and_hidden_dir'
        return true unless File.directory?(full) # 隠しも含めてディレクトリのみ
      when 'all'
        # すべて含める（除外なし）
      when 'yaml_exclude'
        return true if entry.start_with?('.')
        return true if File.extname(entry) == '.yaml'
      else # 'normal'
        return true if entry.start_with?('.')
#        return true if File.file?(full) && File.extname(entry) == '.yaml' && 
# entry != 'semi_lattice.yaml'
      end
      false
    end

    def dir_tree(path, depth)
      return nil if depth < 0
      tree = {}
      entries =
        if @options && (@options[:visibility] == 'all' || 
            @options[:visibility] == 'dir_and_hidden_dir')
          Dir.entries(path) - ['.', '..']
        else
          Dir.children(path)
        end

      ignore_pattern = @options && @options[:ignore] ? @options[:ignore] : nil
      ignore_regex = build_ignore_regex(ignore_pattern)

      entries.each do |entry|
        full = File.join(path, entry)
        p [entry, skip_name?(entry, full, ignore_regex)]
        next if skip_name?(entry, full, ignore_regex)
        if File.symlink?(full)
          target = File.readlink(full)
          tree[entry] = "-> #{target}"
        elsif File.directory?(full)
          subtree = dir_tree(full, depth - 1)
          if subtree
            tree["#{entry}/"] = subtree
          else
            tree["#{entry}/"] = nil
          end
        else
          tree[entry] = nil unless @options && 
            (@options[:visibility] == 'dir_only' || 
            @options[:visibility] == 'dir_and_hidden_dir')
        end
      end
      tree
    end
  end

end
