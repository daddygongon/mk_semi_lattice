# !/usr/bin/env ruby
require 'optparse'
require 'colorize'
require 'yaml'
require 'date'

module VocaBuil
  class OptionParserWrapper
    OPTIONS_DEFAULT = { file: 'dir_tree.yaml', w_num: 5, a_num: 5, entire: nil }

    def self.parse(args = ARGV)
      options = OPTIONS_DEFAULT.dup
      opt = ::OptionParser.new
      opt.on('-f FILE', '--file FILE', 'YAML file to use') { |v| options[:file] = v }
      opt.on('-w NUM', '--words NUM', Integer, 'Number of words to quiz') { |v| options[:w_num] = v }
      opt.on('-a NUM', '--answers NUM', Integer, 'Number of answer choices') { |v| options[:a_num] = v }
      opt.on('-e [NUM]', '--entire [NUM]', Integer, 'Test entire words') do |v|
        options[:entire] = v.nil? ? 2 : v
      end
      opt.parse!(args)
      p options
      options
    end
  end

  class BaseCheck
    CHECK_LOG_FILE = './check_log.yaml'
    WORD_LOG_FILE = './word_log.yaml'
    def initialize(options)
      @options = options.dup
      @check_log_file = self.class::CHECK_LOG_FILE
      @word_log_file = self.class::WORD_LOG_FILE
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
        print "Q#{idx}: '#{ew[0]}' ? -> "
        if ENV['SIMPLE_CHECK_TEST']
          user_inputs << "0"
        else
          # 入力値を半角に変換
          input = Thor::Shell::Basic.new.ask "Q#{idx}: '#{ew[0]}' ? -> "
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
        ans_num = user_num <= answers_shuffled.size ? answers_shuffled[user_num][-1] : -1
        if ans == words_shuffled[ans_num]
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
      check_log = File.exist?(@check_log_file) ?
                    YAML.load_file(@check_log_file, permitted_classes: [Date, Time]) :
                    []
      learning_log = File.exist?(@word_log_file) ?
                    YAML.load(File.read(@word_log_file)) :
                    {}

      check_log << Time.now
      results.each do |word_key, result|
        learning_log[word_key] = learning_log[word_key] ? learning_log[word_key] + result : result
      end

      File.write(@check_log_file, YAML.dump(check_log))
      File.write(@word_log_file, YAML.dump(learning_log))
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
      @word_log_file = word_log_file
      @options = options
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
      if File.exist?(file)
        p ['file', file]
        lines = File.readlines(file)
        parse_word_lines(lines)
      else
        files = Dir.glob('./*/*_tree.yaml')
        p ['files', files]
        if files.empty?
          puts "No '*_tree.yaml' files found in subdirectories.".red
          return []
        end
        words = []
        files.each do |f|
          lines = File.readlines(f)
          words.concat(parse_word_lines(lines))
        end
        words
      end
    end

    def parse_word_lines(lines)
      words = []
      lines[1..-1].each do |line|
        next if line.strip == ''
        line_strip = if line.strip[0] == ':'
                      line.strip[1..-2]
                    else
                      line.strip[0..-2]
                    end
        tmp = line_strip.split("=")
        words << tmp
      end
      words
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

  class EntireCheck
    def initialize(options, iter = 2)
      @options = options
      @iter = iter
      @score = 0
      @wrong_answers = []
      @dir_count = Hash.new(0)
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
        puts "Entire check ##{i+1}/#{@iter}".blue
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
    end

    def print_wrong_answers
      return if @wrong_answers.uniq.empty?
      puts "Wrong answers:".red
      @wrong_answers.uniq.each do |w|
        print "#{w}: ".red
        result = `grep #{w}= */*_tree.yaml`
        puts result
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
end

if __FILE__ == $0
  options = OptionParserWrapper.parse
  if options[:entire]
    EntireCheck.new(options, options[:entire]).run
  else
    BaseCheck.new(options).run
  end
end
