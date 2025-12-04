require_relative "kickoff/config"
require_relative "kickoff/log"
require_relative "kickoff/mk_dir_yaml"
require_relative "kickoff/mk_node_edge"
require_relative "kickoff/mk_semi_lattice_graph"
require_relative "kickoff/option_manager"
require_relative "kickoff/manage_yaml"

class Kickoff
  def setup
  Config.setup
  parent_dir = Dir.pwd
  semi_dir = File.join(parent_dir, '.semi_lattice')
  semi_lattice_yaml_path = File.join(semi_dir, "semi_lattice.yaml")
  Log.event("started", parent_dir: parent_dir)

  option_manager = OptionManager.new
  options = option_manager.parse!

  selector = MkSemiLattice::ManageYaml.new(
    parent_dir: parent_dir,
    semi_dir: semi_dir,
    semi_lattice_yaml_path: semi_lattice_yaml_path,
    options: options
  )
  init_file, init_step = selector.select_init_file_and_step
  p [init_file, init_step]
  input_path, with_semi_lattice_yaml = selector.select_input_path_and_flag(init_file, init_step)
  p [input_path, with_semi_lattice_yaml]

  # options[:layer] を MkSemiLatticeGraphData に渡す
  app = MkSemiLatticeGraphData.new(
    input_path,
    with_semi_lattice_yaml: with_semi_lattice_yaml,
    show_index: options[:show_index],
#    layer: options[:layer] # 追加
  )
    return app, semi_dir, parent_dir
  end
end
