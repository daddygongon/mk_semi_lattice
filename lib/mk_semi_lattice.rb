# frozen_string_literal: true
require 'optparse'
require 'command_line/global'
require 'yaml'
require 'colorize'
require 'rbconfig'
require 'fileutils'
require 'thor'

require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/ruby2d_run"


class Error < StandardError; end

class CLI<Thor
    desc 'view', 'view semi-lattice'
    def view(*argv)
      ruby2d_run(*init())
    end
  end
end

HyperCard::CLI.start(ARGV)

