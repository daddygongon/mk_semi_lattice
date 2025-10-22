# head
date: 2025-10-20
author: bob

## User
module MkSemiLatticeの下に，MkDirYamlクラスを作成し，mk_dir.yaml.rbの動作を実行するようにしてください．


[mk_dir_yaml.rb](./codes/nowledge_fixer.rb)

`MkSemiLattice::MkDirYaml` クラスを作成し、コマンドライン処理とディレクトリ構造の出力をクラスメソッドにまとめます。スクリプトの処理は `MkSemiLattice::MkDirYaml.run` で実行されるようにします。

````ruby
require 'yaml'
require 'optparse'

module MkSemiLattice
  class MkDirYaml
    def self.run(argv)
      options = { layer: 2, output: 'dir.yaml' }
      OptionParser.new do |opts|
        opts.banner = "Usage: ruby mk_dir_yaml.rb PATH [-L layer] [-o output_file]"
        opts.on("-L N", Integer, "Layer depth (default: 2)") { |v| options[:layer] = v }
        opts.on("-o", "--output FILE", "Output file (default: dir.yaml)") { |v| options[:output] = v }
      end.parse!(argv)

      path = argv[0] || '.'
      output_file = options[:output]
      abs_path = File.expand_path(path)
      root_key = File.basename(abs_path) + '/'

      result = { root_key => dir_tree(path, options[:layer] - 1) }
      p result
      File.write(output_file, result.to_yaml)
      puts "Directory structure exported to #{output_file}"
    end

    def self.dir_tree(path, depth)
      return nil if depth < 0
      tree = {}
      Dir.children(path).each do |entry|
        next if entry.start_with?('.')
        full = File.join(path, entry)
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
          tree[entry] = nil
        end
      end
      tree
    end
  end
end

# 実行部分
if __FILE__ == $0
  MkSemiLattice::MkDirYaml.run(ARGV)
end
````

Made changes.

## User
OptionParserの振る舞いは，mk_semi_lattice.rbに移してください．


[mk_dir_yaml.rb](./codes/nowledge_fixer.rb)

`OptionParser` の処理を削除し、`run` メソッドは引数として `path`, `layer`, `output_file` を受け取るようにします。

````ruby
require 'yaml'

module MkSemiLattice
  class MkDirYaml
    def self.run(path: '.', layer: 2, output_file: 'dir.yaml')
      abs_path = File.expand_path(path)
      root_key = File.basename(abs_path) + '/'

      result = { root_key => dir_tree(path, layer - 1) }
      p result
      File.write(output_file, result.to_yaml)
      puts "Directory structure exported to #{output_file}"
    end

    def self.dir_tree(path, depth)
      # ...existing code...
    end
  end
end

# 実行部分は削除
````

---


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

`OptionParser` の処理をこのファイルに移し、`MkSemiLattice::MkDirYaml.run` を呼び出します。

````ruby
require_relative 'lib/mk_semi_lattice/mk_dir_yaml'
require 'optparse'

options = { layer: 2, output: 'dir.yaml' }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby mk_semi_lattice.rb PATH [-L layer] [-o output_file]"
  opts.on("-L N", Integer, "Layer depth (default: 2)") { |v| options[:layer] = v }
  opts.on("-o", "--output FILE", "Output file (default: dir.yaml)") { |v| options[:output] = v }
end.parse!

path = ARGV[0] || '.'
MkSemiLattice::MkDirYaml.run(path: path, layer: options[:layer], output_file: options[:output])
````

Made changes.

## User
yamlファイルをARGV[0]に指定してきた時には，MkDirYaml.newせずに指定ファイルの中身をcatする．


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

ARGV[0]が`.yaml`または`.yml`で終わる場合は、そのファイルをcatし、それ以外の場合のみ`MkDirYaml.new`を呼び出すようにします。

````ruby
# ...existing code...

options = { layer: 2, output: 'dir.yaml' }
OptionParser.new do |opts|
  # ...existing code...
end.parse!

path = ARGV[0] || '.'

if path =~ /\.ya?ml\z/
  puts File.read(path)
else
  semi_dir = File.join(path, '.semi_lattice')
  Dir.mkdir(semi_dir) unless Dir.exist?(semi_dir)
  dir_yaml_path = File.join(semi_dir, 'dir.yaml')
  MkSemiLattice::MkDirYaml.new(path: path, layer: options[:layer], output_file: dir_yaml_path)
end

# ...existing code...
````

Made changes.

## User
dir.yamlを読み込んで，traverse関数を使ったnode_edgeのHashを作り，結果をdir_node_edge.yamlに保存するclass MkNodeEdgeをmodule SemiLattiiceの下に作成する．


[mk_node_edge.rb](./codes/nowledge_fixer.rb)

`SemiLattice::MkNodeEdge` クラスを作成し、dir.yaml を読み込んでノード・エッジ情報を生成し、`dir_node_edge.yaml` に保存する処理をクラスメソッドとしてまとめます。

````ruby
require 'yaml'
require 'pathname'

module SemiLattice
  class MkNodeEdge
    def self.run(input_path:, output_path:)
      dir_tree = YAML.load_file(input_path)
      nodes = []
      edges = []
      id_counter = { val: 1 }
      id_name_map = {}

      root_name = dir_tree.keys.first
      top_path = root_name
      traverse(dir_tree, nil, nodes, edges, id_counter, id_name_map, '.', top_path)

      output = { 'nodes' => nodes, 'edges' => edges }
      yaml_str = output.to_yaml

      # コメント追加
      yaml_lines = yaml_str.lines
      new_yaml_lines = []
      edges_section = false
      edges_idx = 0
      edges_count = edges.size

      yaml_lines.each do |line|
        new_yaml_lines << line
        if line.strip == 'edges:'
          edges_section = true
          next
        end
        if edges_section && line.strip.start_with?('- from:')
          edge = edges[edges_idx]
          from_name = id_name_map[edge['from']]
          to_name = id_name_map[edge['to']]
          comment = "# from: #{from_name}, to: #{to_name}"
          new_yaml_lines << "  #{comment}\n"
          edges_idx += 1
          edges_section = false if edges_idx >= edges_count
        end
      end

      File.write(output_path, new_yaml_lines.join)
    end

    def self.traverse(node, parent_id, nodes, edges, id_counter, id_name_map, current_path, top_path)
      # ...existing code for traverse...
      if node.is_a?(Hash)
        node.each do |name, value|
          node_id = id_counter[:val]
          id_counter[:val] += 1

          type = value.is_a?(Hash) || value.is_a?(Array) ? 'dir' : 'file'
          p [current_path, name]
          node_path = File.join(current_path, name.to_s)
          rel_path = if node_path == top_path
            '.'
          else
            rp = Pathname.new(node_path).relative_path_from(Pathname.new(top_path)).to_s
            rp.start_with?('.') ? rp : "./#{rp}"
          end

          nodes << {
            'id' => node_id,
            'name' => name,
            'type' => type,
            'file_path' => rel_path
          }
          id_name_map[node_id] = name
          if parent_id
            edges << {
              'from' => parent_id,
              'to' => node_id
            }
          end

          if value.is_a?(Hash) || value.is_a?(Array)
            traverse(value, node_id, nodes, edges, id_counter, id_name_map, node_path, top_path)
          end
        end
      elsif node.is_a?(Array)
        node.each do |item|
          traverse(item, parent_id, nodes, edges, id_counter, id_name_map, current_path, top_path)
        end
      end
    end
  end
end

# 実行部分例（必要なら有効化）
# if __FILE__ == $0
#   input_path = File.join(File.dirname(__FILE__), '.semi_lattice', 'dir.yaml')
#   output_path = File.join(File.dirname(__FILE__), '.semi_lattice', 'dir_node_edge.yaml')
#   SemiLattice::MkNodeEdge.run(input_path: input_path, output_path: output_path)
# end
````

Made changes.

## User
#terminalSelection というerrorが出ます．

## Copilot
Read terminal selection


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

`MkNodeEdge` は `SemiLattice::MkNodeEdge` です。
また、`MkDirYaml` も `MkSemiLattice::MkDirYaml` です。
クラス名の修正と、`dir_yaml_path` のスコープ修正を行います。

````ruby
# ...existing code...

  path = ARGV[0] || '.'

  if path =~ /\.ya?ml\z/
    puts File.read(path)
  else
    semi_dir = File.join(path, '.semi_lattice')
    Dir.mkdir(semi_dir) unless Dir.exist?(semi_dir)
    dir_yaml_path = File.join(semi_dir, 'dir.yaml')
    MkSemiLattice::MkDirYaml.new(path: path, layer: options[:layer], output_file: dir_yaml_path)
    # node_edge生成はdir.yaml作成時のみ
    SemiLattice::MkNodeEdge.run(
      input_path: dir_yaml_path,
      output_path: File.join(semi_dir, 'dir_node_edge.yaml')
    )
  end

# ...existing code...
````

**ポイント:**
- `MkSemiLattice::MkDirYaml` と `SemiLattice::MkNodeEdge` の名前空間を正しく指定。
- `MkNodeEdge.new` ではなく `SemiLattice::MkNodeEdge.run` を呼び出す。
- `dir_yaml_path` は else 節内でのみ有効なので、その中で node_edge 生成も行う。

Made changes.

## User
/Users/bob/git_hub/mk_semi_lattice/lib/mk_semi_lattice.rb:39:in `<top (required)>': undefined method `semi_dir' for MkSemiLattice:Module (NoMethodError)
とのerrorが出ます．semi_dirをうまく取り出す方法はありますか？


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

`semi_dir` は `else` 節内でしか定義されていません。
グラフ部分でも使いたい場合は、`semi_dir` を `path` から導出して再定義するか、
`dir_node_edge.yaml` のパスを明示的に指定してください。

下記は `semi_dir` を `path` から導出して再利用する例です。

````ruby
# ...existing code...

  path = ARGV[0] || '.'
  semi_dir = File.join(path, '.semi_lattice')

  if path =~ /\.ya?ml\z/
    puts File.read(path)
  else
    Dir.mkdir(semi_dir) unless Dir.exist?(semi_dir)
    dir_yaml_path = File.join(semi_dir, 'dir.yaml')
    MkSemiLattice::MkDirYaml.new(path: path, layer: options[:layer], output_file: dir_yaml_path)
    SemiLattice::MkNodeEdge.run(
      input_path: dir_yaml_path,
      output_path: File.join(semi_dir, 'dir_node_edge.yaml')
    )
  end

  file = ARGV[0] || File.join(semi_dir, "dir_node_edge.yaml")
  app = MkSemiLatticeData.new(file)

# ...existing code...
````

**ポイント:**
- `semi_dir` を `path` から常に導出することで、どこでも使えるようにします。
- `file = ARGV[0] || File.join(semi_dir, "dir_node_edge.yaml")` で `semi_dir` を利用できます。

Made changes.

## User
pathを実行dirに設定してください．


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

`path` を実行ディレクトリ（`Dir.pwd`）に設定します。
`ARGV[0]` が `.yaml` の場合はそのファイルをcatし、それ以外は `Dir.pwd` を使って処理します。

````ruby
# ...existing code...

  options = { layer: 2, output: 'dir.yaml' }
  OptionParser.new do |opts|
    # ...existing code...
  end.parse!

  # pathを実行ディレクトリに設定
  path = Dir.pwd

  if ARGV[0] && ARGV[0] =~ /\.ya?ml\z/
    puts File.read(ARGV[0])
    file = ARGV[0]
  else
    $semi_dir = File.join(path, '.semi_lattice')
    Dir.mkdir($semi_dir) unless Dir.exist?($semi_dir)
    dir_yaml_path = File.join($semi_dir, 'dir.yaml')
    MkDirYaml.new(path: path, layer: options[:layer], output_file: dir_yaml_path)
    MkNodeEdge.new(input_path: dir_yaml_path, output_path: File.join($semi_dir, 'dir_node_edge.yaml'))
    file = File.join($semi_dir, "dir_node_edge.yaml")
  end

  app = MkSemiLatticeData.new(file)

# ...existing code...
````

Made changes.

## User
#terminalSelection というエラーが出ます．

## Copilot
Read terminal selection


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

エラーの原因は、`at_exit` で .semi_lattice ディレクトリが存在しない場合にファイルを書き込もうとしているためです。
`at_exit` 内で .semi_lattice ディレクトリの存在を確認し、なければ作成してください。

````ruby
# ...existing code...

at_exit do
  semi_lattice_dir = File.join(File.dirname(__FILE__), '.semi_lattice')
  Dir.mkdir(semi_lattice_dir) unless Dir.exist?(semi_lattice_dir)
  nodes_data = app.nodes.map do |n|
    {
      id: app.node_table.key(n),
      name: n.label,
      type: n.type,
      file_path: n.file_path,
      x: n.x,
      y: n.y,
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
  File.write(File.join(semi_lattice_dir, "semi_lattice.yaml"), YAML.dump(yaml_data))
end

# ...existing code...
````

Made changes.

## User　knowledgeのためのsemi_lattice作成
directoryではなく，knowledgeのためのsemi_lattice作成に拡張．
copilotでは時間がかかりそうなので，手動で．

````ruby
path = ARGV[0] || '.'
$semi_dir = File.join(path, '.semi_lattice')
if path == '.'
  Dir.mkdir($semi_dir) unless Dir.exist?($semi_dir)
  dir_yaml_path = File.join($semi_dir, 'dir.yaml')
  MkSemiLattice::MkDirYaml.new(path: path, layer: options[:layer], output_file: dir_yaml_path)
  MkSemiLattice::MkNodeEdge.new(input_path: dir_yaml_path, output_path: File.join($semi_dir, 'dir_node_edge.yaml'))
end

... existing codes

t_exit do
  Dir.mkdir($semi_dir) unless 

... existing codes

  yaml_data = { nodes: nodes_data, edges: edges_data }
  if Dir.exist?($semi_dir)
    File.write(File.join($semi_dir, "semi_lattice.yaml"), YAML.dump(yaml_data))
  else
    File.write(File.join('.', "semi_lattice.yaml"), YAML.dump(yaml_data))
  end
end
