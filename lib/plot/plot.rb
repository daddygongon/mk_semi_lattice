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
        options[:file] = 'score_log.yaml'
      end
      opt.on('-w', '--word_size', 'Plot size from score_log.yaml') do
        options[:plot] = :word_size
        options[:file] = 'score_log.yaml'
      end
      opt.on('-L LAYER', '--layer LAYER', 'Specify layer directory') do |v|
        options[:layer] = v.to_i
      end
      opt.on('-d', '--dark', 'Use dark theme for plot') do
        options[:dark] = true
      end
      opt.parse!(args)
#      p options
      options
    end
  end

  class Plotter
    def initialize(log_file, layer: nil, dark: false)
      @dark = dark
      if layer
        patterns = (0...layer).map { |i| File.join(['.'] + ['*'] * i, log_file) }
        files = patterns.flat_map { |pat| Dir.glob(pat, base: '.') }.select { |f| File.exist?(f) }
        @log = files.flat_map { |f| YAML.load(File.read(f)) }
      else
        @log = YAML.load(File.read(log_file))
      end
    end

    def run_python_plot(py_code)
      File.write('tmp_plot.py', py_code)
      system('python3 tmp_plot.py')
      File.delete('tmp_plot.py')
    end

    # 共通のpy_code生成メソッド
    def generate_py_code(x_label:, y_label:, title:, x_data:, y_data:, x_fmt:, y_lim: nil, x_date_fmt: nil)
      y_lim_code = y_lim ? "plt.ylim(#{y_lim[0]}, #{y_lim[1]})" : ""
      date_fmt_import = x_date_fmt ? "from matplotlib.dates import DateFormatter" : ""
      date_fmt_setter = x_date_fmt ? "plt.gca().xaxis.set_major_formatter(DateFormatter('#{x_date_fmt}'))" : ""
      dark_theme_code = @dark ? "plt.style.use('dark_background')" : ""
      <<~PYTHON
        import matplotlib.pyplot as plt
        from datetime import datetime
        #{date_fmt_import}
        #{dark_theme_code}

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

    def generic_plot(x_label:, y_label:, title:, x_fmt:, y_lim: nil, x_date_fmt: nil, &extractor)
      x_data, y_data = extractor.call(@log)
      py_code = generate_py_code(
        x_label: x_label,
        y_label: y_label,
        title: title,
        x_data: x_data,
        y_data: y_data,
        x_fmt: x_fmt,
        y_lim: y_lim,
        x_date_fmt: x_date_fmt
      )
      run_python_plot(py_code)
    end

    def plot_word_size_log
      generic_plot(
        x_label: 'Time',
        y_label: 'Word Size',
        title: 'Word Size Over Time',
        x_fmt: "%Y-%m-%d %H:%M:%S"
      ) do |log|
        times = []
        sizes = []
        log.each do |entry|
          timestamp = entry[:date]
          size = entry[:size]
          next if timestamp.nil? || size.nil?
          times << timestamp
          sizes << size.to_i
        end
        # 時間でソート
        sorted = times.zip(sizes).sort_by { |t, _| t }
        sorted_times, sorted_sizes = sorted.transpose
        [sorted_times || [], sorted_sizes || []]
      end
    end

    def plot_score_log
      generic_plot(
        x_label: 'Time',
        y_label: 'Score (%)',
        title: 'Score Percentage Over Time',
        x_fmt: "%Y-%m-%d %H:%M:%S",
        y_lim: [0, 100]
      ) do |log|
        times = []
        scores = []
        log.each do |entry|
          timestamp = entry[:date]
          score_str = entry[:score].to_s
          num, denom = score_str.split('/').map(&:to_f)
          percent = (num / denom * 100).round(1)
          times << timestamp
          scores << percent
        end
        # 時間でソート
        sorted = times.zip(scores).sort_by { |t, _| t }
        sorted_times, sorted_scores = sorted.transpose
        [sorted_times || [], sorted_scores || []]
      end
    end

    # 例えば cumulative の場合
    def plot_check_cumulative_per_minute
      generic_plot(
        x_label: 'Time (minute)',
        y_label: 'Cumulative Practice Count',
        title: 'Dependence of Cumulative Practice Time',
        x_fmt: "%Y-%m-%d %H:%M",
        x_date_fmt: "%m-%d"
      ) do |log|
        counts = Hash.new(0)
        log.each do |entry|
          timestamp = entry.is_a?(Array) ? entry[0] : entry.to_s
          minute_str = timestamp[0,16]
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
        # 時間でソート（sorted_minutesは既にsort済みだが念のため）
        [sorted_minutes, cumulative_counts]
      end
    end
  end
end

if __FILE__ == $0
  options = Plot::OptionParserWrapper.parse
  plotter = Plot::Plotter.new(options[:file], layer: options[:layer], dark: options[:dark])
  case options[:plot]
  when :score
    plotter.plot_score_log
  when :word_size
    plotter.plot_word_size_log
  else
    plotter.plot_check_cumulative_per_minute
  end
end
