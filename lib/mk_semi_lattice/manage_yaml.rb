# frozen_string_literal: true

module MkSemiLattice
  class ManageYaml
    def initialize(parent_dir:, semi_dir:, semi_lattice_yaml_path:, options:)
      @parent_dir = parent_dir
      @semi_dir = semi_dir
      @semi_lattice_yaml_path = semi_lattice_yaml_path
      @options = options
    end

    # ARGV[0]とoptionsから初期ファイル・初期ステップを決定
    def select_init_file_and_step
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
        MkSemiLattice::MkDirYaml.new(path: in_path, layer: @options[:layer], output_file: out_path)
        in_path = out_path
        out_path = File.join(@semi_dir, 'dir_node_edge.yaml')
        MkSemiLattice::MkNodeEdge.new(input_path: in_path, output_path: out_path)
        [out_path, false]
      when :from_tree
        init_file = @options[:file]
        base = File.basename(init_file, File.extname(init_file))
        in_path = init_file
        out_path = File.join(@parent_dir, "#{base}_node_edge.yaml")
        MkSemiLattice::MkNodeEdge.new(input_path: in_path, output_path: out_path)
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
  end
end