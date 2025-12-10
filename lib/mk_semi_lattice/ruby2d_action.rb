# frozen_string_literal: true

module Ruby2dAction
  def self.on_key_down(app, event)
    app.shift_pressed = true if event.key.include?('shift')
  end

  def self.on_key_up(app, event)
    app.shift_pressed = false if event.key.include?('shift')
  end

  def self.double_click?(clicked_node, last_click_node, last_click_time)
    now = Time.now
    if last_click_node == clicked_node && last_click_time && (now - last_click_time < 0.4)
      return true, now
    end
    return false, now
  end

  def self.auto_fp_modifier(parent_dir, file_path)
    pd = File.expand_path(parent_dir)
    fp = file_path.dup

    # file_pathが"./"で始まる場合は除去
    fp = fp.sub(%r{\A\./}, '')

    # parent_dirのbasenameを取得
    pd_base = File.basename(pd)

    # parent_dirのパスの中にfile_pathの先頭要素が含まれている場合は、重複しないようにする
    fp_first = fp.split(File::SEPARATOR).first
    if fp == pd_base
      # 完全一致ならparent_dir自身
      pd
    elsif pd.include?(fp_first) && fp.start_with?(fp_first + File::SEPARATOR)
      # parent_dirのどこかにfile_pathの先頭要素が含まれている場合は、その要素以降をparent_dirに連結
      idx = fp.index(File::SEPARATOR)
      rest = idx ? fp[idx+1..-1] : ""
      File.join(pd, rest)
    else
      File.expand_path(fp, pd)
    end
  end

  def self.double_click_action(clicked_node, parent_dir)
    comm = nil
    if clicked_node.file_path
      # URL判定
      if clicked_node.file_path =~ /\Ahttps?:\/\//
        abs_path = clicked_node.file_path
        comm = "open '#{abs_path}'"
      else
        abs_path =
          if Pathname.new(clicked_node.file_path).absolute?
            clicked_node.file_path
          else
            auto_fp_modifier(parent_dir, clicked_node.file_path)
          end

        puts "[DEBUG] parent_dir: #{parent_dir}"
        puts "[DEBUG] file_path: #{clicked_node.file_path}"
        puts "[DEBUG] abs_path: #{abs_path}"
        puts "[DEBUG] config[open_terminal_command]: #{InitEnv::Config.conf['open_terminal_command']}"

        if File.directory?(abs_path)
          if RbConfig::CONFIG['host_os'] =~ /darwin/
            comm = "open -a Terminal '#{abs_path}'"
            # comm = "osascript -e 'tell application \"Terminal\" to do script \"cd #{abs_path}; your_command_here\"'"
          elsif RbConfig::CONFIG['host_os'] =~ /debian/
            comm = "gnome-terminal --working-directory='#{abs_path}'"
            # comm = "gnome-terminal --working-directory='#{abs_path}' -- bash -c 'your_command_here; exec bash'"
          else
            comm = InitEnv::Config.conf['open_terminal_command'] || "wt.exe -p Ubuntu-24.04 "
            comm += " --colorScheme 'Tango Light' -d '#{abs_path}'"
            # comm = "wt.exe -d '#{abs_path}' bash -c 'your_command_here; exec bash'"
            p ["comm", comm]
          end
        else
          comm = "open '#{abs_path}'"
        end
      end
      p ["comm", comm]
      puts comm
      InitEnv::Log.event("open", target_dir: abs_path, parent_dir: parent_dir)
      system comm
    else
      puts "no link error"
    end
  end

  def self.on_mouse_down(app, event, last_click_node, last_click_time, parent_dir)
    mx, my = event.x, event.y
    shift_down = !!app.shift_pressed
    clicked_node = nil
    app.nodes.each do |n|
      if Math.hypot(n.x - mx, n.y - my) < 30
        clicked_node = n
        if shift_down
          n.fixed = false
          n.color = NODE_COLOR
          app.selected = nil
        else
          app.selected = n
          if event.button == :left
            n.fixed = true
            n.color = FIXED_COLOR
          end
          n.fixed = false if event.button == :middle
          n.linked = true if event.button == :right
        end
      end
    end

    # ダブルクリック判定とファイルオープン
    if clicked_node
      is_double, now = double_click?(clicked_node, last_click_node, last_click_time)
      double_click_action(clicked_node, parent_dir) if is_double
      return clicked_node, now
    end
    [last_click_node, last_click_time]
  end

  def self.on_mouse_up(app)
    app.selected = nil
  end

  def self.on_mouse_move(app, event)
    if app.selected
      app.selected.x = event.x
      app.selected.y = event.y
    end
  end

  def self.update_action(app)
    app.edges.each(&:relax)
    app.nodes.each { |n| n.relax(app.nodes) }
    app.nodes.each(&:update)
    app.edges.reverse.each(&:draw)
    app.nodes.reverse.each do |n|
      n.draw(app.selected == n)
    end
  end
end