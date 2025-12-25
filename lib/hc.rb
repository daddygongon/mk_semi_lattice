require 'thor'
require_relative "mk_semi_lattice/version"
require_relative "mk_stack/mk_stack"

class CLI < Thor
  desc "view", "View Semi Lattice Graph"
  def view(*argv)
    system "mk_semi_lattice", *argv
  end

  desc 'stack', 'make stacks'
  def stack(*argv)
      MkStack.new(argv).run
  end
end 

CLI.start(ARGV)