require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'avsh'

require 'pp' # workaround for https://github.com/fakefs/fakefs/issues/99
require 'fakefs/spec_helpers'
