# !/usr/bin/env ruby
require 'thor'
require 'optparse'
require 'colorize'
require 'yaml'
require 'date'

module VocaBuil
  class OptionParserWrapper
    OPTIONS_DEFAULT = { file: 'dir_tree.yaml', w_num: 5, a_num: 5, iter: nil, install: false }

    def self.parse(args = ARGV)
      options = OPTIONS_DEFAULT.dup

      options[:cmd_line] = args.join(' ') # 追加: 残ったargsを記録
      opt = ::OptionParser.new
      opt.banner = "Usage: hc check [options]"
      opt.on('-f FILE', '--file FILE', 'YAML file to use') do |v|
        options[:file] = v
      end
      opt.on('-a NUM', '--answer NUM', Integer, 'Number of answer choices(def 5)') do |v|
        options[:a_num] = v
      end
      opt.on('-q NUM', '--quiz NUM', Integer, 'Number of quiz(def 5)') do |v|
        options[:w_num] = v
      end
      opt.on('-i [NUM]', '--iterative [NUM]', Integer, 'Test iteratively (num=2)') do |v|
        options[:iter] = v.nil? ? 2 : v
      end
      opt.on('--install', 'Install sample check data') do
        options[:install] = true
      end
      # 追加: reverseモード
      opt.on('-r', '--reverse', 'Reverse quiz and answers') do
        options[:reverse] = true
      end
      opt.parse!(args)
      p options
      options
    end
  end

  class BaseCheck
    CHECK_LOG_FILE = './check_log.yaml'
    WORD_LOG_FILE = './word_log.yaml'
    WORD_LOG_FILE_J2E = './word_log_j2e.yaml' # 追加

    def initialize(options)
      @options = options.dup
      @check_log_file = self.class::CHECK_LOG_FILE
      # reverseオプションでファイル名を切り替え
      @word_log_file = options[:reverse] ? self.class::WORD_LOG_FILE_J2E : self.class::WORD_LOG_FILE
    end
    def shuffle_words(words, w_num)
      words.shuffle.first(w_num)
    end

    def make_answers(words_shuffled)
      words_shuffled.each_with_index.map { |word, idx| [word[-1], idx] }
    end

    def shuffle_answers(answers, a_num)
      answers.shuffle[0..a_num]
    end

    def print_answers(answers_shuffled)
      answers_shuffled.each_with_index do |word, idx|
        puts "#{idx}: #{word[0]}" #, #{word[-1]}"
      end
    end

    # w_num個だけ問題を出すように修正
    def get_user_inputs(words_shuffled, w_num)
      user_inputs = []
      words_shuffled.first(w_num).each_with_index do |ew, idx|
        break if ew.nil?
        question = "Q#{idx+1}: '#{ew[0]}' ? -> "
        if ENV['SIMPLE_CHECK_TEST']
          puts question
          user_inputs << "0"
        else
          # reverseモードかつquestionが標準ターミナル幅(80-10)を超える場合はputsで表示しaskは空文字
          if @options[:reverse] && question.length > 70
            puts question
            input = Thor::Shell::Basic.new.ask ""
          else
            input = Thor::Shell::Basic.new.ask question
          end
          # 入力値を半角に変換
          user_input = input ? input.chomp.unicode_normalize(:nfkc) : ""
          user_inputs << user_input
        end
      end
      user_inputs
    end

    # w_num個だけ解答をチェックするように修正
    def check_results(words_shuffled, answers_shuffled, user_inputs, w_num)
      results = {}
      [w_num, words_shuffled.size].min.times do |i|
        ans = words_shuffled[i]
        next if ans.nil?
        user_num = user_inputs[i].to_i
        print "%-2s" % user_num
        if user_num < answers_shuffled.size && 
           ans == words_shuffled[answers_shuffled[user_num][-1]]
          print "true:  ".green
          t_or_f = 't'
        else
          print "false: ".red
          t_or_f = 'f'
        end
        p ans
        results[ans[0]] = t_or_f
      end
      results
    end

    def update_logs(results)
      cmd_opts = @options[:cmd_line] || ""
      correct = results.values.count('t')
      total = results.size
      log_line = [
        Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        cmd_opts,
        "#{correct}/#{total}"
      ]

      # check_log.yamlの更新
      log_file = @check_log_file
      logs = File.exist?(log_file) ? YAML.load_file(log_file) : []
      logs << log_line
      File.write(log_file, YAML.dump(logs))

      # word_log.yamlの更新
      word_log = File.exist?(@word_log_file) ? YAML.load_file(@word_log_file) : {}
      results.each do |word, tf|
        word_log[word] ||= ""
        word_log[word] += tf
      end
      File.write(@word_log_file, YAML.dump(word_log))
    end

    def select_least_correct_words(whole_words)
      return unless File.exist?(@word_log_file)
      word_log = YAML.load_file(@word_log_file)
      # 対象words数が100未満ならその数、100以上なら100
      limit = [whole_words.size, 100].min
      least_words = word_log.sort_by { |k, v| v&.count('t') || 0 }.first(limit)
      selected_words = []
      least_words.each do |sel_word, _|
        whole_words.each { |word| selected_words << word if word[0] == sel_word }
      end
      selected_words
    end

    def init_word_log(words)
      word_log = {}
      words.each { |word| word_log[word[0]] = nil }
      word_log
    end

    def run
      selector = WordsSelector.new(@word_log_file, @options)
      words_shuffled = selector.select(@options[:w_num], @options[:a_num])
      answers = make_answers(words_shuffled)
      answers_shuffled = shuffle_answers(answers, @options[:a_num])
      print_answers(answers_shuffled)
      user_inputs = get_user_inputs(words_shuffled, @options[:w_num])
      results = check_results(words_shuffled, answers_shuffled, user_inputs, @options[:w_num])
      update_logs(results)
      results
    end

  end

  class WordsSelector
    def initialize(word_log_file, options)
      @options = options
      # reverseオプションでファイル名を切り替え
      @word_log_file = options[:reverse] ? './word_log_j2e.yaml' : word_log_file
    end

    # w_num, a_numを受け取り、a_num+1個の単語を返す
    def select(w_num, a_num)
      word_list = read_words(@options[:file])
      if File.exist?(@word_log_file)
        learning_log = YAML.load_file(@word_log_file)
        word_list.each do |word_entry|
          learning_log[word_entry[0]] = nil unless learning_log.key?(word_entry[0])
        end
        learning_log.delete_if { |word_key, _| word_list.none? { |word_entry| word_entry[0] == word_key } }
        File.write(@word_log_file, YAML.dump(learning_log))
      else
        learning_log = init_word_log(word_list)
        File.write(@word_log_file, YAML.dump(learning_log))
      end

      selected_words = select_least_correct_words(word_list)
      shuffle_words(selected_words, a_num)
    end

    private

    def read_words(file)
      files = Dir.glob(file)
      if files.empty?
        files = Dir.glob('./*/*_tree.yaml')
        if files.empty?
          puts "No '*_tree.yaml' files found in subdirectories.".red
          return []
        end
      end
      files.flat_map { |f| parse_word_file(f) }
    end

    def parse_word_file(filepath)
      lines = File.readlines(filepath)
      words = lines[1..-1].each_with_object([]) do |line, arr|
        line = line.split('#', 2)[0]
        next if line.strip == ''
        line_strip = if line.strip[0] == ':'
                       line.strip[1..-2]
                     else
                       line.strip[0..-2]
                     end
        tmp = line_strip.split("=")
        arr << (@options[:reverse] ? tmp.reverse : tmp)
      end
      words # ← ここを元に戻す
    end

    def shuffle_words(words, w_num)
      words.shuffle.first(w_num)
    end

    def select_least_correct_words(word_list)
      learning_log = YAML.load_file(@word_log_file)
      limit = [word_list.size/4, @options[:a_num]].max
      least_learned = learning_log.sort_by { |word_key, log| log&.count('t') || 0 }.first(limit)
      selected_words = []
      least_learned.each do |word_key, _|
        word_list.each { |word_entry| selected_words << word_entry if word_entry[0] == word_key }
      end
      selected_words
    end

    def init_word_log(word_list)
      learning_log = {}
      word_list.each { |word_entry| learning_log[word_entry[0]] = nil }
      learning_log
    end
  end

  class IterativeCheck
    SCORE_LOG_FILE = './score_log.yaml' # 追加

    def initialize(options, iter = 2)
      @options = options
      @iter = iter
      @score = 0
      @wrong_answers = []
      @dir_count = Hash.new(0) # ディレクトリごとの間違い数カウント
    end

    def run
      run_checks
      print_score
      print_wrong_answers
      print_difficult_roots
    end

    private

    def run_checks
      @iter.times do |i|
        puts "\nIterative check ##{i+1}/#{@iter}".blue
        BaseCheck.new(@options).run.each do |w, val|
          if val == 'f'
            @wrong_answers << w
          else
            @score += 1
          end
        end
      end
    end

    def print_score
      puts "%2d/%2d" % [@score, (@iter * @options[:w_num])]
      log_score # 追加
    end

    # 追加: スコアをscore_log.yamlに記録
    def log_score
      word_log_file = @options[:reverse] ? VocaBuil::BaseCheck::WORD_LOG_FILE_J2E : VocaBuil::BaseCheck::WORD_LOG_FILE
      words_size = File.exist?(word_log_file) ? YAML.load_file(word_log_file).size : 0

      log_file = self.class::SCORE_LOG_FILE
      logs = File.exist?(log_file) ? YAML.load_file(log_file) : []
      log_line = {
        date:  Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        comm:  @options[:cmd_line] || "",
        score: "#{@score}/#{@iter * @options[:w_num]}",
        size:  words_size # 追加
      }
      logs << log_line
      File.write(log_file, YAML.dump(logs))
    end

    def print_wrong_answers
      return if @wrong_answers.uniq.empty?
      puts "Wrong answers:".red
      # カレントディレクトリに *_tree.yaml が1つでもあればそれらを対象に
      local_tree_files = Dir.glob("*_tree.yaml")
      grep_target = if !local_tree_files.empty?
                      local_tree_files.join(' ')
                    else
                      '*/*_tree.yaml'
                    end
      @wrong_answers.uniq.each do |w|
        print "#{w}: ".red
        result = `grep -E "#{w}" #{grep_target}`
        word = result.split(":")[1]
        puts word ? word.strip : "(not found)"
        count_dirs(result)
      end
    end

    def count_dirs(result)
      result.each_line do |line|
        if line =~ /^([^\/]+)\//
          dir = $1
          @dir_count[dir] += 1
        end
      end
    end

    def print_difficult_roots
      return if @dir_count.empty?
      puts "Difficult roots:".yellow
      @dir_count.each do |dir, count|
        puts "#{dir}: #{count}"
      end
    end
  end

  class InstallCheckSample
    def initialize(tgz_file = 'etymological_builder_check_sample.tgz')
      @tgz_file = File.join(__dir__, tgz_file)
    end

    def run
      unless File.exist?(@tgz_file)
        puts "#{@tgz_file} not found.".red
        return
      end
      puts "Extracting #{@tgz_file} to current directory...".green
      system("tar", "xf", @tgz_file)
      puts "Extraction complete.".green
    end
  end
end

if __FILE__ == $0
  options = VocaBuil::OptionParserWrapper.parse
  if options[:install]
    VocaBuil::InstallCheckSample.new.run
    exit
  end
  if options[:iter]
    VocaBuil::IterativeCheck.new(options, options[:iter]).run
  else
    VocaBuil::BaseCheck.new(options).run
  end
end
