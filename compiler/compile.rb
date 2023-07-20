#!/usr/bin/env ruby

require "pathname"
require "optparse"

require_relative "assembler"
require_relative "vm_translator"

require 'optparse'

option_parser = OptionParser.new do |opts|
  opts.on "-a", "--assembly=ASSEMBLY", "assembly file"
  opts.on "-v", "--vm=VM", "vm file or directory"
  opts.on "-d", "--dry_run", "whether to do a dry run"
end

options = Hash.new
option_parser.parse! into: options

assembly = options[:assembly]
vm = options[:vm]
dry_run = options[:dry_run] || false

unless assembly.nil? ^ vm.nil?
  raise StandardError.new("supply either `assembly` or `vm`")
end

unless vm.nil?
  path = Pathname.new(vm)
  raise StandardError.new("#{path} invalid path") unless path.file? || path.directory?
  vm_translator = VmTranslator.new(path).append_commands!
  if dry_run
    puts "would write"
    vm_translator.writer.commands.each(&method(:puts))
    puts "to #{vm_translator.writer.path}"
  else
    puts "writing to #{vm_translator.writer.path}"
    vm_translator.write!
  end
end


# FILENAME, *_ = ARGV
# PATH = Pathname.new(FILENAME)
# TRANSLATOR = VmTranslator.new(PATH)
# TRANSLATOR.parsed_lines.each_with_index { |line, index| puts "#{index}: #{line}" }
# puts "\nassembly:\n#{TRANSLATOR.output}"
# TRANSLATOR.write
#
# ASSEMBLER = Assembler.new(PATH)
# ASSEMBLER.symbol_table.lookup.each do |k, v|
#   next if [:SP, :LCL, :ARG, :THIS, :THAT, :SCREEN, :KBD].include?(k)
#   next if k.match(/^R\d+$/)
#   puts "#{k}: #{v}"
# end
# ASSEMBLER
#   .parsed_lines
#   .reject { |line| line.is_a?(Assembler::Label) }
#   .zip(ASSEMBLER.assembled_lines)
#   .each_with_index { |(l, al), index| puts "#{index}: #{tl} #{l.inspect}" }
# ASSEMBLER.write

