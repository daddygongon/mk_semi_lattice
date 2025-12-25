require 'thor'
require_relative "mk_semi_lattice/version"
require_relative "mk_stack/mk_stack"
require_relative "voca_buil/multi_check"


class CLI < Thor
  desc "view", "View Semi Lattice Graph"
  def view(*argv)
    system "mk_semi_lattice", *argv
  end

  desc 'stack', 'make stacks'
  def stack(*argv)
      MkStack.new(argv).run
  end

  desc 'voc_check', 'vocabulary check'
  def voc_check(*argv)
    options = VocaBuil::OptionParserWrapper.parse
    if options[:entire]
      VocaBuil::EntireCheck.new(options, options[:entire]).run
    else
      VocaBuil::BaseCheck.new(options).run
    end 
  end
end 

CLI.start(ARGV)