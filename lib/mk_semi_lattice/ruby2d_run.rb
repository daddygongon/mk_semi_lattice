
def init
  puts "mk_semi_lattice is running..."

  # prep semi lattice viewer app
  parent_dir = Dir.pwd
  InitEnv.init_env(parent_dir)
  
  options = OptionManager.new.parse!
  semi_dir = File.join(parent_dir, '.semi_lattice')
  semi_lattice_yaml_path = File.join(semi_dir, "semi_lattice.yaml")
  options[:parent_dir] = parent_dir
  options[:semi_dir] = semi_dir
  options[:semi_lattice_yaml_path] = semi_lattice_yaml_path

  input_path, with_semi_lattice_yaml = ManageYaml::MkSemiLattice.new(
    options).prepare_paths_and_flags

  options[:with_semi_lattice_yaml] = with_semi_lattice_yaml
  sl_viewer_app = SLComponents::BuildViewer.new(
    input_path, options)

  return [sl_viewer_app, semi_dir, parent_dir]
end

def ruby2d_run(sl_viewer_app, semi_dir, parent_dir)
  require 'ruby2d'

  top_node_label = sl_viewer_app.nodes.first&.label || "Semi Lattice Graph"
  set width: 800, height: 600
  set title: top_node_label
  set background: 'white'
  set fps: 15

  last_click_time = nil
  last_click_node = nil

  on :key_down do |event|
    Ruby2dAction.on_key_down(sl_viewer_app, event)
  end

  on :key_up do |event|
    Ruby2dAction.on_key_up(sl_viewer_app, event)
  end

  on :mouse_down do |event|
    clicked_node, last_time = Ruby2dAction.on_mouse_down(sl_viewer_app, event, last_click_node, last_click_time, parent_dir)
    last_click_node = clicked_node
    last_click_time = last_time
  end

  on :mouse_up do
    Ruby2dAction.on_mouse_up(sl_viewer_app)
  end

  on :mouse_move do |event|
    Ruby2dAction.on_mouse_move(sl_viewer_app, event)
  end

  update do
    Ruby2dAction.update_action(sl_viewer_app)
  end

  at_exit do
    ManageYaml::MkSemiLattice.at_exit_action(sl_viewer_app, semi_dir, parent_dir)
  end

  show

end
