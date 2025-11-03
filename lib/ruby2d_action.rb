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

  def self.double_click_action(clicked_node, parent_dir)
    comm = nil
    if clicked_node.file_path
      if File.directory?(clicked_node.file_path)
        if RbConfig::CONFIG['host_os'] =~ /darwin/
          comm = "open -a Terminal '#{clicked_node.file_path}'"
        elsif RbConfig::CONFIG['host_os'] =~ /debian/
          comm = "gnome-terminal --working-directory='#{clicked_node.file_path}'"
        else
          comm = "wt.exe -p Ubuntu-24.04 --colorScheme 'Tango Light' -d '#{clicked_node.file_path}'"
        end
      else
        if RbConfig::CONFIG['host_os'] =~ /darwin/
          comm = "open '#{clicked_node.file_path}'"
        else
          comm = "open '#{clicked_node.file_path}'"
        end
      end
      puts comm
      Log.event("open", target_dir: File.expand_path(clicked_node.file_path, parent_dir), parent_dir: parent_dir)
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