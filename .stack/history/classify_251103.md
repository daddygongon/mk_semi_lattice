# head
date: 2025-11-03
author: bob

## User
codeのrefactorを進めます．まずは，config関連の動作をclass Configにまとめて呼び出すようにしましょう．

## Copilot
以下のように`Config`クラスを新設し、設定ファイルの読み書きやディレクトリ作成、ログ有効化/無効化の管理をまとめます。
グローバル変数`$conf`や`CONF_PATH`なども`Config`クラスのクラス変数/メソッドで管理します。

````ruby
# ...existing code...

class Config
  CONFIG_DIR = File.expand_path("~/.config/semi_lattice")
  CONF_PATH = File.join(CONFIG_DIR, "semi_lattice.conf")
  LOG_PATH = File.join(CONFIG_DIR, "semi_lattice_history")

  @conf = { "log" => false }

  class << self
    attr_reader :conf

    def setup
      FileUtils.mkdir_p(CONFIG_DIR)
      load_conf
    end

    def load_conf
      if File.file?(CONF_PATH)
        begin
          loaded = YAML.load_file(CONF_PATH)
          if loaded.is_a?(Hash)
            @conf.merge!(loaded)
          else
            puts "Warning: #{CONF_PATH} is not a hash. Using default config.".yellow
          end
        rescue
          puts "Warning: #{CONF_PATH} is invalid. Using default config.".yellow
        end
      end
    end

    def save_conf
      File.write(CONF_PATH, @conf.to_yaml)
    end

    def log_enabled?
      @conf["log"]
    end

    def set_log(value)
      @conf["log"] = value
      save_conf
    end

    def log_path
      LOG_PATH
    end
  end
end

Config.setup

# ...existing code...

options = { layer: 2, init_step: :from_semi_lattice, show_index: false, merge: false }
OptionParser.new do |opts|
  # ...existing code...
  opts.on("-l", "--log [BOOL]", "Enable/disable logging (true/false), and save to config") do |v|
    bool =
      if v.nil?
        true
      elsif v.is_a?(String)
        case v.strip.downcase
        when "true", "yes", "on", "1"
          true
        when "false", "no", "off", "0"
          false
        else
          puts "Invalid value for log: #{v}. Using default: false".yellow
          false
        end
      else
        !!v
      end
    Config.set_log(bool)
    puts "Logging is now #{bool ? 'enabled' : 'disabled'} (saved to #{Config::CONF_PATH})"
    exit
  end
end.parse!

# ...existing code...

def log_event(action, target_dir: nil)
  return unless Config.log_enabled?
  log_entry = {
    timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
    action: action
  }
  log_entry[:target_dir] = target_dir if target_dir
  log_entry[:where] = $parent_dir
  logs = []
  if File.exist?(Config.log_path)
    begin
      logs = YAML.load_file(Config.log_path) || []
    rescue
      logs = []
    end
  end
  logs << log_entry
  File.write(Config.log_path, logs.to_yaml)
end

# ...existing code...
````

- これでconfig関連の処理が`Config`クラスに集約され、グローバル変数の使用も減ります。
- 他の箇所で`$conf`や`CONF_PATH`を参照していた場合は`Config.conf`や`Config::CONF_PATH`に置き換えてください。

## User
class Configを切り離して，lib/mk_semi_lattice/config.rbに移しましょう．

## Copilot
````ruby
# frozen_string_literal: true
require 'yaml'
require 'fileutils'
require 'colorize'

class Config
  CONFIG_DIR = File.expand_path("~/.config/semi_lattice")
  CONF_PATH = File.join(CONFIG_DIR, "semi_lattice.conf")
  LOG_PATH = File.join(CONFIG_DIR, "semi_lattice_history")

  @conf = { "log" => false }

  class << self
    attr_reader :conf

    def setup
      FileUtils.mkdir_p(CONFIG_DIR)
      load_conf
    end

    def load_conf
      if File.file?(CONF_PATH)
        begin
          loaded = YAML.load_file(CONF_PATH)
          if loaded.is_a?(Hash)
            @conf.merge!(loaded)
          else
            puts "Warning: #{CONF_PATH} is not a hash. Using default config.".yellow
          end
        rescue
          puts "Warning: #{CONF_PATH} is invalid. Using default config.".yellow
        end
      end
    end

    def save_conf
      File.write(CONF_PATH, @conf.to_yaml)
    end

    def log_enabled?
      @conf["log"]
    end

    def set_log(value)
      @conf["log"] = value
      save_conf
    end

    def log_path
      LOG_PATH
    end
  end
end
````

そして、mk_semi_lattice.rbの先頭付近で次のように修正してください。

````ruby
# ...existing code...
require_relative "mk_semi_lattice/config"
# ...class Configの定義を削除...
Config.setup
# ...existing code...
````

これで`Config`クラスが分離され、他のファイルからも`require_relative "mk_semi_lattice/config"`で利用できます。

## User
#file:mk_semi_lattice.rb:12-69 あたりも修正を反映させて．

## Copilot
````ruby
# ...existing code...
require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/mk_dir_yaml"
require_relative "mk_semi_lattice/mk_node_edge"
require_relative "mk_semi_lattice/mk_semi_lattice_graph"
require_relative "mk_semi_lattice/config"  # ← 追加

$semi_dir = ''
class Error < StandardError; end

puts "mk_semi_lattice is running..."

# ↓↓↓ ここ（class Config ... end）は削除してください ↓↓↓
# class Config
#   CONFIG_DIR = File.expand_path("~/.config/semi_lattice")
#   CONF_PATH = File.join(CONFIG_DIR, "semi_lattice.conf")
#   LOG_PATH = File.join(CONFIG_DIR, "semi_lattice_history")
#   ...
# end

Config.setup
# ...existing code...
````

- `class Config ... end` の定義を削除し、
- 代わりに `require_relative "mk_semi_lattice/config"` を追加してください。
- 以降の `Config.setup` や `Config.xxx` の呼び出しはそのまま使えます。

この修正で、`Config` クラスは config.rb から読み込まれるようになります。

## User
#file:mk_semi_lattice.rb:72-96 を分離してclass Logを作成

## Copilot
````ruby
# frozen_string_literal: true
require 'yaml'

class Log
  class << self
    def event(action, target_dir: nil, parent_dir: Dir.pwd)
      return unless Config.log_enabled?
      log_entry = {
        timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        action: action
      }
      log_entry[:target_dir] = target_dir if target_dir
      log_entry[:where] = parent_dir
      logs = []
      if File.exist?(Config.log_path)
        begin
          logs = YAML.load_file(Config.log_path) || []
        rescue
          logs = []
        end
      end
      logs << log_entry
      File.write(Config.log_path, logs.to_yaml)
    end
  end
end
````

**使い方（lib/mk_semi_lattice.rb側の修正例）:**

````ruby
# ...existing code...
require_relative "mk_semi_lattice/log"

# ...existing code...

Log.event("started", parent_dir: $parent_dir)

# ...log_event("open", ...) → Log.event("open", target_dir: ..., parent_dir: $parent_dir)
# ...log_event("exited")    → Log.event("exited", parent_dir: $parent_dir)
````

- これでログ機能が`Log`クラスに分離され、`Log.event`で呼び出せます。
- `$parent_dir`は必要に応じて引数で渡してください（デフォルトは`Dir.pwd`）。

## User
#file:mk_semi_lattice.rb:72-96 を変更を反映．

## Copilot
````ruby
# ...existing code...
require_relative "mk_semi_lattice/log"
# ...existing code...

# LOG_DIR, LOG_PATH, log_eventメソッドを削除

Log.event("started", parent_dir: $parent_dir)
# ...existing code...
````

**新規ファイル:**

````ruby
# frozen_string_literal: true
require 'yaml'

class Log
  class << self
    def event(action, target_dir: nil, parent_dir: Dir.pwd)
      return unless Config.log_enabled?
      log_entry = {
        timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        action: action
      }
      log_entry[:target_dir] = target_dir if target_dir
      log_entry[:where] = parent_dir
      logs = []
      if File.exist?(Config.log_path)
        begin
          logs = YAML.load_file(Config.log_path) || []
        rescue
          logs = []
        end
      end
      logs << log_entry
      File.write(Config.log_path, logs.to_yaml)
    end
  end
end
````

**ポイント:**
- `log_event`の呼び出しはすべて`Log.event`に置き換えてください（例: `Log.event("open", target_dir: ..., parent_dir: $parent_dir)`）。
- `LOG_DIR`や`LOG_PATH`の定義も不要です（`Config`クラスで管理）。
- `require_relative "mk_semi_lattice/log"`を忘れずに追加してください。

## User
/Users/bob/.rbenv/versions/3.0.2/lib/ruby/gems/3.0.0/gems/mk_semi_lattice-0.1.0/lib/mk_semi_lattice.rb:261:in `block in <top (required)>': undefined method `log_event' for main:Object (NoMethodError)
/Users/bob/.rbenv/versions/3.0.2/lib/ruby/gems/3.0.0/gems/mk_semi_lattice-0.1.0/lib/mk_semi_lattice.rb:169:in `double_click_action': undefined method `log_event' for main:Object (NoMethodError)
となっています．

## Copilot
`log_event`メソッドを`Log.event`に置き換える必要があります。
`log_event(...)`を呼んでいる箇所をすべて`Log.event(...)`に修正してください。

例：

````ruby
# ...existing code...

# 例: 起動時
Log.event("started", parent_dir: $parent_dir)

# 例: ダブルクリックアクション内
Log.event("open", target_dir: File.expand_path(ファイルパス, $parent_dir), parent_dir: $parent_dir)

# 例: 終了時
Log.event("exited", parent_dir: $parent_dir)
# ...existing code...
````

**ポイント**
- `log_event`というメソッドはもう存在しません。
- 代わりに`Log.event`を使ってください。
- `require_relative "mk_semi_lattice/log"`がファイル冒頭に必要です。

**例: ダブルクリックアクションの修正例**
````ruby
# ...existing code...
def double_click_action(clicked_node)
  comm = nil
  if clicked_node.file_path
    # ...省略...
    Log.event("open", target_dir: File.expand_path(clicked_node.file_path, $parent_dir), parent_dir: $parent_dir)
    system comm
  else
    puts "no link error"
  end
end
# ...existing code...
````

この修正でエラーは解消します。

## User
/Users/bob/.rbenv/versions/3.0.2/lib/ruby/gems/3.0.0/gems/mk_semi_lattice-0.1.0/lib/mk_semi_lattice.rb:72:in `<top (required)>': uninitialized constant CONFIG_DIR (NameError)
Did you mean?  Config
とエラーが出てます．

## Copilot
`CONFIG_DIR`や`LOG_PATH`などの定数は、すでに`Config`クラスで管理されています。
mk_semi_lattice.rb内の以下の部分は不要なので削除してください。

```ruby
LOG_DIR = CONFIG_DIR
Dir.mkdir_p(LOG_DIR) unless Dir.exist?(LOG_DIR)
LOG_PATH = File.join(LOG_DIR, "semi_lattice_history") # 拡張子なし

def log_event(action, target_dir: nil)
  # ...省略...
end
```

また、`log_event(...)`の呼び出しもすべて削除し、`Log.event(...)`のみを使ってください。

**修正例：**

````ruby
# ...既存のrequireの下に追加...
require_relative "mk_semi_lattice/log"
# ...既存コード...

# ↓↓↓ この部分を削除してください ↓↓↓
# LOG_DIR = CONFIG_DIR
# Dir.mkdir_p(LOG_DIR) unless Dir.exist?(LOG_DIR)
# LOG_PATH = File.join(LOG_DIR, "semi_lattice_history") # 拡張子なし
#
# def log_event(action, target_dir: nil)
#   ...
# end

# ...既存コード...

# 例: 起動時
Log.event("started", parent_dir: $parent_dir)

# log_event("started") ← これも削除

# ...ダブルクリックアクション内...
Log.event("open", target_dir: File.expand_path(clicked_node.file_path, $parent_dir), parent_dir: $parent_dir)
# log_event("open", ...) ← これも削除

# ...終了時...
Log.event("exited", parent_dir: $parent_dir)
# log_event("exited") ← これも削除

# ...既存コード...
````

**ポイント**
- `CONFIG_DIR`や`LOG_PATH`は`Config`クラスで管理されているので、直接参照しないでください。
- ログ記録は`Log.event`のみを使ってください。
- `require_relative "mk_semi_lattice/log"`を忘れずに。

この修正で`uninitialized constant CONFIG_DIR`エラーは解消します。

## User
#selectionを管理するclass OptionManagerを作成して分離．

## Copilot
````ruby
# frozen_string_literal: true
require 'optparse'
require 'colorize'

class OptionManager
  attr_reader :options

  def initialize
    @options = { layer: 2, init_step: :from_semi_lattice, show_index: false, merge: false }
  end

  def parse!
    OptionParser.new do |opts|
      opts.banner = "Usage: mk_semi_lattice PATH [-L layer] [-t FILE] [-n FILE]\n default PATH = '.'"

      opts.on("-L N", Integer, "Layer depth (default: 2)") do |v|
        @options[:layer] = v
      end

      opts.on("-n", "--node=FILE", "using File from node-edge") do |file|
        @options[:file] = file
        @options[:init_step] = :from_node_edge
      end

      opts.on("-t", "--tree=FILE", "using File from tree") do |file|
        @options[:file] = file
        @options[:init_step] = :from_tree
      end

      opts.on("-i", "--index", "Display node ids") do
        @options[:show_index] = true
      end

      opts.on("-l", "--log [BOOL]", "Enable/disable logging (true/false), and save to config") do |v|
        bool =
          if v.nil?
            true
          elsif v.is_a?(String)
            case v.strip.downcase
            when "true", "yes", "on", "1"
              true
            when "false", "no", "off", "0"
              false
            else
              puts "Invalid value for log: #{v}. Using default: false".yellow
              false
            end
          else
            !!v
          end
        Config.set_log(bool)
        puts "Logging is now #{bool ? 'enabled' : 'disabled'} (saved to #{Config::CONF_PATH})"
        exit
      end
    end.parse!
    @options
  end
end
````

**mk_semi_lattice.rb 側の修正例：**

````ruby
require_relative "mk_semi_lattice/option_manager"
# ...existing code...

option_manager = OptionManager.new
options = option_manager.parse!

# 以降は options をそのまま利用
````

このようにすることで、コマンドラインオプションの管理が`OptionManager`クラスに集約され、mk_semi_lattice.rbがすっきりします。

## User
#file:mk_semi_lattice.rb:32-51 はLog.eventに代替しませんでしたっけ？

## Copilot
はい、その通りです。
`log_event`メソッド（#file:mk_semi_lattice.rb:32-51）は**不要**です。
すでに`Log.event`で代替されているので、**このメソッド定義は削除してください**。

修正例：

````ruby
# ...existing code...

# ↓↓↓ この部分を削除してください ↓↓↓
# def log_event(action, target_dir: nil)
#   return unless Config.log_enabled?
#   log_entry = {
#     timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
#     action: action
#   }
#   log_entry[:target_dir] = target_dir if target_dir
#   log_entry[:where] = $parent_dir
#   logs = []
#   if File.exist?(Config.log_path)
#     begin
#       logs = YAML.load_file(Config.log_path) || []
#     rescue
#       logs = []
#     end
#   end
#   logs << log_entry
#   File.write(Config.log_path, logs.to_yaml)
# end

# ...existing code...
````

以降は`Log.event(...)`のみを使ってください。

## User
#file:mk_semi_lattice.rb:35-74  の動作をまとめてclass SelectYamlを作成

## Copilot
````ruby
# frozen_string_literal: true

module MkSemiLattice
  class SelectYaml
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
````

**mk_semi_lattice.rb 側の利用例：**

````ruby
require_relative "mk_semi_lattice/select_yaml"
# ...existing code...

selector = MkSemiLattice::SelectYaml.new(
  parent_dir: $parent_dir,
  semi_dir: semi_dir,
  semi_lattice_yaml_path: semi_lattice_yaml_path,
  options: options
)
init_file, init_step = selector.select_init_file_and_step
p [init_file, init_step]
input_path, with_semi_lattice_yaml = selector.select_input_path_and_flag(init_file, init_step)
p [input_path, with_semi_lattice_yaml]

# ...existing code...
````

このように分離することで、初期ファイル・初期ステップの選択ロジックが`SelectYaml`クラスにまとまります。

## User
#file:mk_semi_lattice.rb:160-192 の動作を行う関数def at_exit_actionを作成．

## Copilot
````ruby
# ...existing code...

def at_exit_action(app, semi_dir, parent_dir)
  nodes_data = app.nodes.map do |n|
    p [n.label, n.fixed, n.color]
    {
      id: app.node_table.key(n),
      name: n.name,
      type: n.type,
      file_path: n.file_path,
      x: n.x,
      y: n.y,
      color: n.color,
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
  yaml_text = MkSemiLattice::MkNodeEdge.add_edge_comments(yaml_data)
  if Dir.exist?(semi_dir)
    File.write(File.join(semi_dir, "semi_lattice.yaml"), yaml_text)
  else
    File.write(File.join('.', "semi_lattice.yaml"), yaml_text)
  end
  Log.event("exited", parent_dir: parent_dir)
end

# ...existing code...

at_exit do
  at_exit_action(app, semi_dir, $parent_dir)
end

# ...existing code...
````

このように関数化することで、`at_exit`ブロックがすっきりします。

## User
at_exit_actionをSelectYamlに入れることは可能ですか？

## Copilot
はい、`at_exit_action`を`SelectYaml`に入れることは**技術的には可能**ですが、設計上はあまりおすすめしません。

### 理由
- `SelectYaml`は「初期ファイルや初期ステップの選択」を担当するクラスです。
- `at_exit_action`は「アプリの状態（ノード・エッジ）をYAMLに保存する」責務であり、役割が異なります。
- 責務分離の観点から、`at_exit_action`は`SelectYaml`ではなく、例えば`MkSemiLatticeData`のインスタンスメソッドや、専用の`Saver`クラスなどに分離するのが自然です。

---

### どうしても`SelectYaml`に入れたい場合

- クラスメソッドやインスタンスメソッドとして追加はできます。
- ただし、`SelectYaml`の責務が曖昧になり、保守性が下がります。

#### 例（クラスメソッドとして追加）：

````ruby
module MkSemiLattice
  class SelectYaml
    # ...既存コード...

    def self.at_exit_action(app, semi_dir, parent_dir)
      nodes_data = app.nodes.map do |n|
        {
          id: app.node_table.key(n),
          name: n.name,
          type: n.type,
          file_path: n.file_path,
          x: n.x,
          y: n.y,
          color: n.color,
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
      yaml_text = MkSemiLattice::MkNodeEdge.add_edge_comments(yaml_data)
      if Dir.exist?(semi_dir)
        File.write(File.join(semi_dir, "semi_lattice.yaml"), yaml_text)
      else
        File.write(File.join('.', "semi_lattice.yaml"), yaml_text)
      end
      Log.event("exited", parent_dir: parent_dir)
    end
  end
end
````

**呼び出し側：**

````ruby
at_exit do
  MkSemiLattice::SelectYaml.at_exit_action(app, semi_dir, $parent_dir)
end
````

---

### 結論

- **可能だが、設計上は推奨しません。**
- 責務分離のため、保存処理は別クラスや`MkSemiLatticeData`のメソッドにするのがベターです。

## User
MkSemiLatticeDataをMkSemiLatticeGraphDataに変更

## Copilot
````ruby
# ...existing code...
class MkSemiLatticeGraphData
  attr_reader :nodes, :edges, :node_table
  attr_accessor :selected, :shift_pressed, :show_index

  def initialize(file = "dir_node_edge.yaml", with_semi_lattice_yaml: false, show_index: false)
    @nodes = []
    @edges = []
    @node_table = {}
    @selected = nil
    @shift_pressed = false
    p @show_index = show_index
    load_yaml_data_with_state(file, with_semi_lattice_yaml: with_semi_lattice_yaml)
  end

  # ...以下同じ...
end
````

````ruby
# ...existing code...

app = MkSemiLatticeGraphData.new(input_path,
  with_semi_lattice_yaml: with_semi_lattice_yaml,
  show_index: options[:show_index]
)

# ...existing code...
````

- `MkSemiLatticeData` → `MkSemiLatticeGraphData` にクラス名を変更してください。
- インスタンス生成も同様に変更してください。

## User
SelectYamlをManageYamlに変更．

## Copilot
````ruby
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
````

**呼び出し側（mk_semi_lattice.rb）も修正してください：**

````ruby
require_relative "mk_semi_lattice/manage_yaml" # ファイル名も変更した場合

# ...
selector = MkSemiLattice::ManageYaml.new(
  parent_dir: $parent_dir,
  semi_dir: semi_dir,
  semi_lattice_yaml_path: semi_lattice_yaml_path,
  options: options
)
init_file, init_step = selector.select_init_file_and_step
input_path, with_semi_lattice_yaml = selector.select_input_path_and_flag(init_file, init_step)
# ...
````

- クラス名を`SelectYaml`→`ManageYaml`に変更
- ファイル名もselect_yaml.rb→`manage_yaml.rb`に変更するのが推奨です（`require_relative`も合わせて修正）

この修正で意図通り動作します。

## User
def at_exit_action(app, semi_dir, parent_dir)をManageYamlに移動．

## Copilot
````ruby
# ...existing code...

    # アプリ終了時の状態保存
    def self.at_exit_action(app, semi_dir, parent_dir)
      nodes_data = app.nodes.map do |n|
        p [n.label, n.fixed, n.color]
        {
          id: app.node_table.key(n),
          name: n.name,
          type: n.type,
          file_path: n.file_path,
          x: n.x,
          y: n.y,
          color: n.color,
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
      yaml_text = MkSemiLattice::MkNodeEdge.add_edge_comments(yaml_data)
      if Dir.exist?(semi_dir)
        File.write(File.join(semi_dir, "semi_lattice.yaml"), yaml_text)
      else
        File.write(File.join('.', "semi_lattice.yaml"), yaml_text)
      end
      Log.event("exited", parent_dir: parent_dir)
    end

# ...existing code...
````

````ruby
# ...existing code...

# Ruby2Dには:closeイベントはありません。at_exitで保存処理を行います。
at_exit do
  MkSemiLattice::ManageYaml.at_exit_action(app, semi_dir, $parent_dir)
end

# ...existing code...
````

- `at_exit_action`は`ManageYaml`の**クラスメソッド**として追加しました。
- `at_exit`ブロックでは`MkSemiLattice::ManageYaml.at_exit_action(...)`で呼び出してください。
- 元の`def at_exit_action ... end`は削除してください。

## User
それぞれの動作に対するactionをそれぞれの関数を作成し，それらをlib/ruby2d_action.rbに移動．

## Copilot
````ruby
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
````

**mk_semi_lattice.rb 側の修正例：**

````ruby
require_relative "ruby2d_action"
# ...existing code...

last_click_time = nil
last_click_node = nil

on :key_down do |event|
  Ruby2dAction.on_key_down(app, event)
end

on :key_up do |event|
  Ruby2dAction.on_key_up(app, event)
end

on :mouse_down do |event|
  clicked_node, last_time = Ruby2dAction.on_mouse_down(app, event, last_click_node, last_click_time, $parent_dir)
  last_click_node = clicked_node
  last_click_time = last_time
end

on :mouse_up do
  Ruby2dAction.on_mouse_up(app)
end

on :mouse_move do |event|
  Ruby2dAction.on_mouse_move(app, event)
end

update do
  Ruby2dAction.update_action(app)
end
````

- それぞれのRuby2Dイベントの処理を`Ruby2dAction`モジュールの関数に分離しました。
- `last_click_node`と`last_click_time`の更新も`on_mouse_down`の返り値で管理できます。
- これでmk_semi_lattice.rbがすっきりし、イベントごとの処理が明確になります。