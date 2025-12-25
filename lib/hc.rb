require 'thor'
require_relative "mk_semi_lattice/version"
require_relative "mk_stack/mk_stack"
require_relative "voca_buil/multi_check"
require_relative "split_pdf/split_pdf"


class CLI < Thor
  desc "view", "View Semi Lattice Graph"
  def view(*argv)
    system "mk_semi_lattice", *argv
  end

  desc 'stack', 'make stacks'
  def stack(*argv)
      MkStack.new(argv).run
  end

  desc 'split_pdf', 'split PDF files'
  def split_pdf(*argv)
      puts "not implemented yet"
      puts "convert multi_scale_25f/ruby/ruby_basic/p4_rake/Rakefile to class"
  end

  desc 'voca_buil', 'vocabulary builder check'
  def voca_buil(*argv)
    options = VocaBuil::OptionParserWrapper.parse
    if options[:entire]
      VocaBuil::EntireCheck.new(options, options[:entire]).run
    else
      VocaBuil::BaseCheck.new(options).run
    end 
  end
end 

CLI.start(ARGV)