# !/usr/bin/env ruby
require 'thor'
require 'optparse'
require 'colorize'
require 'yaml'
require 'date'

module Plot
  class OptionParserWrapper
    OPTIONS_DEFAULT = { file: 'check_log.yaml', plot: :cumulative }

    def self.parse(args = ARGV)
      options = OPTIONS_DEFAULT.dup

      options[:cmd_line] = args.join(' ')
      opt = ::OptionParser.new
      opt.banner = "Usage: hc plot [options]"
      opt.on('-f FILE', '--file FILE', 'YAML file to use') do |v|
        options[:file] = v
      end
      opt.on('-s', '--score', 'Plot score_log.yaml') do
        options[:plot] = :score
      end
      opt.on('-w', '--word_size', 'Plot size from score_log.yaml') do
        options[:plot] = :word_size
      end
      opt.parse!(args)
      p options
      options
    end
  end

  class Plotter
    def self.run_python_plot(py_code)
      File.write('tmp_plot.py', py_code)
      system('python3 tmp_plot.py')
      File.delete('tmp_plot.py')
    end

    # 共通のpy_code生成メソッド
    def self.generate_py_code(x_label:, y_label:, title:, x_data:, y_data:, x_fmt:, y_lim: nil, x_date_fmt: nil)
      y_lim_code = y_lim ? "plt.ylim(#{y_lim[0]}, #{y_lim[1]})" : ""
      date_fmt_import = x_date_fmt ? "from matplotlib.dates import DateFormatter" : ""
      date_fmt_setter = x_date_fmt ? "plt.gca().xaxis.set_major_formatter(DateFormatter('#{x_date_fmt}'))" : ""
      <<~PYTHON
        import matplotlib.pyplot as plt
        from datetime import datetime
        #{date_fmt_import}

        x_data = #{x_data}
        y_data = #{y_data}

        x = [datetime.strptime(val, "#{x_fmt}") for val in x_data]
        y = y_data

        plt.figure(figsize=(12,5))
        plt.plot(x, y, marker='o')
        #{date_fmt_setter}
        plt.title('#{title}')
        plt.xlabel('#{x_label}')
        plt.ylabel('#{y_label}')
        #{y_lim_code}
        plt.grid(True)
        plt.tight_layout()
        plt.show()
      PYTHON
    end

    def self.plot_word_size_log
      log = YAML.load(File.read('score_log.yaml'))
      times = []
      sizes = []

      log.each do |entry|
        timestamp = entry[:date]
        size = entry[:size]
        next if timestamp.nil? || size.nil?
        times << timestamp
        sizes << size.to_i
      end

      py_code = generate_py_code(
        x_label: 'Time',
        y_label: 'Word Size',
        title: 'Word Size Over Time',
        x_data: times,
        y_data: sizes,
        x_fmt: "%Y-%m-%d %H:%M:%S"
      )

      run_python_plot(py_code)
    end

    def self.plot_score_log
      log = YAML.load(File.read('score_log.yaml'))
      times = []
      scores = []

      log.each do |entry|
        timestamp = entry[:date]
        score_str = entry[:score].to_s # "4/5" の形式
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

    # 例えば cumulative の場合
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
        y_label: 'Cumulative Practice Count',
        title: 'Dependence of Cumulative Practice Time',
        x_data: sorted_minutes,
        y_data: cumulative_counts,
        x_fmt: "%Y-%m-%d %H:%M",
        x_date_fmt: "%m-%d"
      )

      run_python_plot(py_code)
    end
  end
end

if __FILE__ == $0
  options = Plot::OptionParserWrapper.parse
  case options[:plot]
  when :score
    Plot::Plotter.plot_score_log
  when :word_size
    Plot::Plotter.plot_word_size_log
  else
    Plot::Plotter.plot_check_cumulative_per_minute
  end
end
