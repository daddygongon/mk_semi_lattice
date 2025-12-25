# frozen_string_literal: true
require 'optparse'
require 'command_line/global'
require 'yaml'
require 'colorize'
require 'rbconfig'
require 'fileutils'

require_relative "mk_semi_lattice/version"
require_relative "mk_semi_lattice/ruby2d_run"


class Error < StandardError; end


if defined?(RSpec) || defined?(Minitest)
  # テスト時は何もしない
else
  ruby2d_run(*init())
end
