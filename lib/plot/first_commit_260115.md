# head
date: 2026-01-15
author: bob

## User
Iterationで動かした時に，score_log.yamlとしてその結果を残す機能を加えられますか？

## Copilot
はい、`IterativeCheck` 実行時にスコアを `score_log.yaml` として保存する機能を追加できます。
`print_score` メソッドでスコアを表示しているので、ここでログファイルへの書き込みも行うのが自然です。

## User
plot_check_count_per_dayをplot_check_sumとして積算plotに変更できますか？

## User
横軸は日付順ではなく，分単位で刻んでください．

## User
縦軸のcountは積算してください．

## User
オプションとして-s, --scoreが来た時には，score_log.yamlから読み込んで縦軸には20/25などを80/100と変換して，80をつけるようなplot作成にできますか？

## User
OptionParserWrapperも先ほどの変更に対応するように修正．


## User
py_code部分を共通のmethodにできますか？

## User
py_code = <<~PYTHON
        import matplotlib.pyplot as plt
        from datetime import datetime

        times = #{times}
        scores = #{scores}

        x = [datetime.strptime(t, "%Y-%m-%d %H:%M:%S") for t in times]
        y = scores

        plt.figure(figsize=(12,5))
        plt.plot(x, y, marker='o')
        plt.title('Score Percentage Over Time')
        plt.xlabel('Time')
        plt.ylabel('Score (%)')
        plt.ylim(0, 100)
        plt.grid(True)
        plt.tight_layout()
        plt.show()
      PYTHON
もテキトウな引数をとって生成するように共通化しましょう．

## Copilot
````ruby
# ...existing code...

  class Plotter
    def self.run_python_plot(py_code)
      File.write('tmp_plot.py', py_code)
      system('python3 tmp_plot.py')
      File.delete('tmp_plot.py')
    end

    # 共通のpy_code生成メソッド
    def self.generate_py_code(x_label:, y_label:, title:, x_data:, y_data:, x_fmt:, y_lim: nil)
      y_lim_code = y_lim ? "plt.ylim(#{y_lim[0]}, #{y_lim[1]})" : ""
      <<~PYTHON
        import matplotlib.pyplot as plt
        from datetime import datetime

        x_data = #{x_data}
        y_data = #{y_data}

        x = [datetime.strptime(val, "#{x_fmt}") for val in x_data]
        y = y_data

        plt.figure(figsize=(12,5))
        plt.plot(x, y, marker='o')
        plt.title('#{title}')
        plt.xlabel('#{x_label}')
        plt.ylabel('#{y_label}')
        #{y_lim_code}
        plt.grid(True)
        plt.tight_layout()
        plt.show()
      PYTHON
    end

    def self.plot_score_log
      log = YAML.load(File.read('score_log.yaml'))
      times = []
      scores = []

      log.each do |entry|
        timestamp = entry[0]
        score_str = entry[2] # "20/25" の形式
        num, denom = score_str.split('/').map(&:to_f)
        percent = (num / denom * 100).round(1)
        times << timestamp
        scores << percent
      end

      py_code = generate_py_code(
        x_label: 'Time',
        y_label: 'Score (%)',
        title: 'Score Percentage Over Time',
        x_data: times,
        y_data: scores,
        x_fmt: "%Y-%m-%d %H:%M:%S",
        y_lim: [0, 100]
      )

      run_python_plot(py_code)
    end

    def self.plot_check_cumulative_per_minute
      log = YAML.load(File.read('check_log.yaml'))
      counts = Hash.new(0)
      log.each do |entry|
        timestamp = entry.is_a?(Array) ? entry[0] : entry.to_s
        minute_str = timestamp[0,16] # "YYYY-MM-DD HH:MM"
        counts[minute_str] += 1
      end

      sorted_minutes = counts.keys.sort
      sorted_counts = sorted_minutes.map { |m| counts[m] }

      cumulative_counts = []
      sum = 0
      sorted_counts.each do |c|
        sum += c
        cumulative_counts << sum
      end

      py_code = generate_py_code(
        x_label: 'Time (minute)',
        y_label: 'Cumulative Count',
        title: 'Cumulative Access Count per Minute',
        x_data: sorted_minutes,
        y_data: cumulative_counts,
        x_fmt: "%Y-%m-%d %H:%M"
      )

      run_python_plot(py_code)
    end
  end
# ...existing code...
````

## User
Plotモジュールをhc.rbから呼び出すように修正できますか？

## Copilot
````ruby
require_relative "plot/plot" # 追加

  desc 'plot', 'plot logs'
  def plot(*argv)
    options = Plot::OptionParserWrapper.parse(argv)
    if options[:score]
      Plot::Plotter.plot_score_log
    else
      Plot::Plotter.plot_check_cumulative_per_minute
    end
  end
end

CLI.start(ARGV)
````