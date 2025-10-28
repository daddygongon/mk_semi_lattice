# head
date: 2025-10-20
author: bob

## User
.semi_lattice/semi_lattice.yamlが存在する場合にも，ノード座標・fixed状態を反映


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

変更内容:
`.semi_lattice/semi_lattice.yaml` が存在する場合にもノード座標・fixed状態を反映するように、ファイル存在チェックを追加します。

````ruby
# ...existing code...

file = ARGV[0] || File.join($semi_dir, "dir_node_edge.yaml")

semi_lattice_yaml_path = File.join($semi_dir, "semi_lattice.yaml")
if file =~ /semi_lattice\.ya?ml\z/ || File.exist?(semi_lattice_yaml_path)
  # semi_lattice.yamlが指定された場合、または存在する場合はノード座標・fixed状態を反映
  app = MkSemiLatticeData.new(file =~ /semi_lattice\.ya?ml\z/ ? file : semi_lattice_yaml_path, with_semi_lattice_yaml: true)
else
  app = MkSemiLatticeData.new(file)
end

# ...existing code...
````

Made changes.

## User
ARGV[0]でsemi_lattice.yamlが指定された場合，あるいは'.semi_lattice/sem_lattice.yaml'が存在する場合はwith_semi_lattice_yaml: trueでMkSemiLatticeData.newを呼びだす．


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

ARGV[0]でsemi_lattice.yamlが指定された場合、または`.semi_lattice/semi_lattice.yaml`が存在する場合は`with_semi_lattice_yaml: true`で`MkSemiLatticeData.new`を呼び出すように変更します。

````ruby
# ...existing code...

file = ARGV[0] || File.join($semi_dir, "dir_node_edge.yaml")
semi_lattice_yaml_path = File.join($semi_dir, "semi_lattice.yaml")

if (ARGV[0] && ARGV[0] =~ /semi_lattice\.ya?ml\z/) || File.exist?(semi_lattice_yaml_path)
  # ARGV[0]でsemi_lattice.yamlが指定された場合、または存在する場合はノード座標・fixed状態を反映
  app = MkSemiLatticeData.new(ARGV[0] =~ /semi_lattice\.ya?ml\z/ ? ARGV[0] : semi_lattice_yaml_path, with_semi_lattice_yaml: true)
else
  app = MkSemiLatticeData.new(file)
end

# ...existing code...
````

Made changes.

## User
node.type=='dir'ならばFolderを描画．


[mk_semi_lattice_graph.rb](./codes/nowledge_fixer.rb)

`node.type == 'dir'` の場合に `Folder` を描画するようになっています。既にそのような実装になっているため、変更は不要です。

````ruby
# ...existing code...
  def draw(selected)
    c = if selected
      SELECT_COLOR
    elsif fixed
      FIXED_COLOR
    elsif linked
      LINKED_COLOR
    else
      NODE_COLOR
    end
    if @type == 'dir'
      Folder.new(x, y, color: c, z: 10).draw
      Text.new(label, x: x-20, y: y-10, size: 18, color: 'black', z: 11)
    else
      Circle.new(x: x, y: y, radius: 30, color: c, z: 10)
      Text.new(label, x: x-20, y: y-10, size: 18, color: 'black', z: 11)
    end
  end
# ...existing code...
````

この部分は既に要件を満たしています。

Made changes.

## User
末尾が’/’で終了するnode.labelは:typeを'dir'にセットする．


[mk_node_edge.rb](./codes/nowledge_fixer.rb)

`node.label`（ここでは`name`）が`'/'`で終わる場合、`:type`を`'dir'`にセットするようにします。

````ruby
# ...existing code...
          # type判定を修正: nameが'/'で終わる場合は'dir'
          type = if name.to_s.end_with?('/')
            'dir'
          else
            value.is_a?(Hash) || value.is_a?(Array) ? 'dir' : 'file'
          end
          # ...existing code...
````

Made changes.

## User
node.type=='dir'をdouble clickした時にはterminalでそのpathを開くように修正．


[mk_semi_lattice.rb](./codes/nowledge_fixer.rb)

ダブルクリック時、`node.type == 'dir'` の場合はターミナルでそのパスを開くように修正します。

````ruby
# ...existing code...
  # ダブルクリック判定とファイルオープン
  now = Time.now
  if clicked_node
    if last_click_node == clicked_node && last_click_time && (now - last_click_time < 0.4)
      if clicked_node.file_path
        if clicked_node.type == 'dir'
          system("open -a Terminal '#{clicked_node.file_path}'")
        else
          system("open #{clicked_node.file_path}")
        end
      end
    end
    last_click_time = now
    last_click_node = clicked_node
  end
# ...existing code...
````

Made changes.

## User
file.extension=='.yaml'はtreeに含めない．


[mk_dir_yaml.rb](./codes/nowledge_fixer.rb)

`.yaml`拡張子のファイルはtreeに含めないように修正します。

````ruby
# ...existing code...
    def dir_tree(path, depth)
      return nil if depth < 0
      tree = {}
      Dir.children(path).each do |entry|
        next if entry.start_with?('.')
        full = File.join(path, entry)
        # .yamlファイルは含めない
        next if File.file?(full) && File.extname(entry) == '.yaml'
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
# ...existing code...
````

Made changes.