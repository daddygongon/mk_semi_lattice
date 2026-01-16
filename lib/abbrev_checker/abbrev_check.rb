# !/usr/bin/env ruby
require 'thor'
require 'optparse'
require 'colorize'
require 'yaml'
require 'date'
require_relative '../voca_buil/multi_check' # VocaBuilを親クラスとして利用

module AbbrevCheck
  class OptionParserWrapper < VocaBuil::OptionParserWrapper
    # 必要ならここでオプションのデフォルト値などを上書き
  end

  class BaseCheck < VocaBuil::BaseCheck
    # 選択肢を作らず、単語を直接入力させる
    def get_user_inputs(words_shuffled, w_num)
      user_inputs = []
      words_shuffled.first(w_num).each_with_index do |ew, idx|
        break if ew.nil?
        question = "Q#{idx+1}: '#{ew[0]}' ? -> "
        if ENV['SIMPLE_CHECK_TEST']
          puts question
          user_inputs << ew[1] # テスト時は正解を自動入力
        else
          input = Thor::Shell::Basic.new.ask question
          user_input = input ? input.chomp.unicode_normalize(:nfkc) : ""
          user_inputs << user_input
        end
      end
      user_inputs
    end

    # 入力が正解と完全一致するか判定
    def check_results(words_shuffled, user_inputs, w_num)
      results = {}
      [w_num, words_shuffled.size].min.times do |i|
        ans = words_shuffled[i]
        next if ans.nil?
        user_input = user_inputs[i]
        print "'#{user_input}' "
        correct_answer = @options[:reverse] ? ans[-1] : ans[1]
        if user_input == correct_answer
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

    # runメソッドを上書き
    def run
      selector = WordsSelector.new(@word_log_file, @options)
      words_shuffled = selector.select(@options[:w_num], @options[:a_num])
      user_inputs = get_user_inputs(words_shuffled, @options[:w_num])
      results = check_results(words_shuffled, user_inputs, @options[:w_num])
      update_logs(results)
      results
    end
  end

  class WordsSelector < VocaBuil::WordsSelector
    # 必要ならここで上書き
  end

  class IterativeCheck < VocaBuil::IterativeCheck
    def run_checks
      @iter.times do |i|
        puts "\nIterative check ##{i+1}/#{@iter}".blue
        # ここでAbbrevCheck::BaseCheckを明示的に使う
        AbbrevCheck::BaseCheck.new(@options).run.each do |w, val|
          if val == 'f'
            @wrong_answers << w
          else
            @score += 1
          end
        end
      end
    end
  end

  class InstallCheckSample < VocaBuil::InstallCheckSample
    def initialize(tgz_file = 'abbrev_sample.tgz')
      # abbrev_checker ディレクトリを基準にパスを解決
      @tgz_file = File.join(File.dirname(__FILE__), tgz_file)
    end
  end
end

if __FILE__ == $0
  options = AbbrevCheck::OptionParserWrapper.parse
  if options[:install]
    AbbrevCheck::InstallCheckSample.new.run
    exit
  end
  if options[:iter]
    AbbrevCheck::IterativeCheck.new(options, options[:iter]).run
  else
    AbbrevCheck::BaseCheck.new(options).run
  end
end
