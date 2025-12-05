require 'pathname'

module ManageYaml
  class MkNodeEdge
    def initialize(input_path:, output_path:)
      dir_tree = YAML.load_file(input_path)
      nodes = []
      edges = []
      id_counter = { val: 1 }

      root_name = dir_tree.keys.first
      top_path = root_name
      traverse(dir_tree, nil, nodes, edges, id_counter, '.', top_path)

      output = { nodes: nodes, edges: edges }

      # クラスメソッドとして呼び出す
      yaml_str_with_comments = self.class.add_edge_comments(output)

      File.write(output_path, yaml_str_with_comments)
    end

    # クラスメソッド化
    def self.add_edge_comments(output)
      nodes = output[:nodes]
      edges = output[:edges]
      id_name_map = nodes.each_with_object({}) do |node, map|
        map[node[:id]] = node[:name]
      end

      yaml_lines = output.to_yaml.lines
      new_yaml_lines = []
      edges_section = false
      edges_idx = 0
      edges_count = edges.size

      yaml_lines.each do |line|
        new_yaml_lines << line
        if line.strip == ':edges:'
          edges_section = true
          next
        end
        if edges_section && line.strip.start_with?('- :from:')
          edge = edges[edges_idx]
          from_name = id_name_map[edge[:from]]
          to_name = id_name_map[edge[:to]]
          comment = "# from: #{from_name}, to: #{to_name}"
          new_yaml_lines << "  #{comment}\n"
          edges_idx += 1
          edges_section = false if edges_idx >= edges_count
        end
      end
      new_yaml_lines.join
    end

    def traverse(node, parent_id, nodes, edges, id_counter, current_path, top_path)
      if node.is_a?(Hash)
        node.each do |name, value|
          node_id = id_counter[:val]
          id_counter[:val] += 1

          type = if name.to_s.end_with?('/')
            'dir'
          else
            value.is_a?(Hash) || value.is_a?(Array) ? 'dir' : 'file'
          end

          p [current_path, name]
          node_path = File.join(current_path, name.to_s)
          rel_path = if node_path == top_path
            '.'
          else
            rp = Pathname.new(node_path).relative_path_from(Pathname.new(top_path)).to_s
            rp.start_with?('.') ? rp : "./#{rp}"
          end

          nodes << {
            :id => node_id,
            :name => name,
            :type => type,
            :file_path => rel_path
          }
          if parent_id
            edges << {
              :from => parent_id,
              :to => node_id
            }
          end

          if value.is_a?(Hash) || value.is_a?(Array)
            traverse(value, node_id, nodes, edges, id_counter, node_path, top_path)
          end
        end
      elsif node.is_a?(Array)
        node.each do |item|
          traverse(item, parent_id, nodes, edges, id_counter, current_path, top_path)
        end
      end
    end
  end
end
