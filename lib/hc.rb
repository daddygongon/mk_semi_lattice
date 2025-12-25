require 'thor'

class CLI < Thor
  desc "view", "View Semi Lattice Graph"
  def view(*argv)
    system "mk_semi_lattice", *argv
  end
end

CLI.start.run(ARGV)