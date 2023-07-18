#!/usr/bin/env ruby

require "pathname"
require "optparse"

require_relative "assembler"
require_relative "vm_translator"

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

