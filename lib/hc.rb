require 'thor'
require_relative "mk_semi_lattice/version"
require_relative "mk_stack/mk_stack"
require_relative "voca_buil/multi_check"
require_relative "split_pdf/split_pdf"
require_relative "abbrev_checker/abbrev_check"
require_relative "plot/plot" # 追加

class CLI < Thor
  desc "view", "View Semi Lattice Graph"
  def view(*argv)
    system "mk_semi_lattice", *argv
  end

  desc "version", "show version"
  def version()
    puts MkSemiLattice::VERSION
  end

  desc 'stack', 'make stacks'
  def stack(*argv)
      MkStack.new(argv).run
  end

  desc 'split_pdf', 'split PDF files'
  def split_pdf(*argv)
    SplitPDF.new(argv).run
  end

  desc 'check', 'check word for vocabulary builder'
  def check(*argv)
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
  
  desc 'abbrev', 'check abbreviations'
  def abbrev(*argv)
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

  desc 'plot', 'plot logs'
  def plot(*argv)
    options = Plot::OptionParserWrapper.parse
    plotter = Plot::Plotter.new(options[:file], layer: options[:layer],
                                dark: options[:dark])
    case options[:plot]
    when :score
      plotter.plot_score_log
    when :word_size
      plotter.plot_word_size_log
    else
      plotter.plot_check_cumulative_per_minute
    end
  end

    

end 

CLI.start(ARGV)

