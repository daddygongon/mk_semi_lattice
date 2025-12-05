require_relative "init_env"
require_relative "option_manager"
require_relative "mk_semi_lattice_yaml/mk_node_edge"
require_relative "mk_semi_lattice_yaml/mk_semi_lattice_graph"
require_relative "mk_semi_lattice_yaml/manage_yaml"

class Kickoff
  def prep_sl_viewer_app
    init_env

    options = OptionManager.new.parse!

    semi_dir = File.join(@parent_dir, '.semi_lattice')
    semi_lattice_yaml_path = File.join(semi_dir, "semi_lattice.yaml")
    input_path, with_semi_lattice_yaml = MkSemiLattice::ManageYaml.new(
      parent_dir: @parent_dir,
      semi_dir: semi_dir,
      semi_lattice_yaml_path: semi_lattice_yaml_path,
      options: options
    ).prepare_paths_and_flags

    app = MkSemiLattice::GraphData.new(
      input_path,
      with_semi_lattice_yaml: with_semi_lattice_yaml,
      show_index: options[:show_index],
      layer: options[:layer]
    )
    return app, semi_dir, @parent_dir
  end

  def init_env
    InitEnv::Config.setup
    @parent_dir = Dir.pwd
    InitEnv::Log.event("started", parent_dir: @parent_dir)
  end
end
