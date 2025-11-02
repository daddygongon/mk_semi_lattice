module MkSemiLattice
  class MkDirYaml
    def initialize(path: '.', layer: 2, output_file: 'dir.yaml')
      abs_path = File.expand_path(path)
      root_key = File.basename(abs_path) + '/'

      result = { root_key => dir_tree(path, layer - 1) }
      p result
      File.write(output_file, result.to_yaml)
      puts "Directory structure exported to #{output_file}"
    end

    def dir_tree(path, depth)
      return nil if depth < 0
      tree = {}
      Dir.children(path).each do |entry|
        next if entry.start_with?('.')
        full = File.join(path, entry)
        # .yamlファイルは含めないが、semi_lattice.yamlは含める
        next if File.file?(full) && File.extname(entry) == '.yaml' && entry != 'semi_lattice.yaml'
        next if entry.end_with?('~')
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
