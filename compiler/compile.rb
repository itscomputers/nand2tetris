#!/usr/bin/env ruby

require "pathname"
require "optparse"

require_relative "assembler"
require_relative "vm_translator"

require 'optparse'

def validate_presence!(assembly:, vm:)
  unless assembly.nil? ^ vm.nil?
    raise StandardError.new("supply either `assembly` or `vm`")
  end
end

def process_assembly(path, dry_run:)
  raise StandardError.new("#{path} invalid path") unless path.file?
  assembler = Assembler.new(path)
  if dry_run
    puts "would write"
    assembler.symbol_table.lookup.each do |k, v|
      next if [:SP, :LCL, :ARG, :THIS, :THAT, :SCREEN, :KBD].include?(k)
      next if k.match?(/^R\d+$/)
      puts "#{k}: #{v}"
    end
    assembler
      .parsed_lines
      .reject { |line| line.is_a?(Assembler::Label) }
      .zip(assembler.assembled_lines)
      .each_with_index { |(l, al), index| puts "#{index}: #{al} #{l.inspect}" }
  else
    assembler.write
  end
end

def process_vm(path, dry_run:)
  raise StandardError.new("#{path} invalid path") unless path.file? || path.directory?
  writer = VmTranslator.new(path).writer
  writer.append_commands
  if dry_run
    puts "would write"
    writer.commands.each(&method(:puts))
    puts "to #{writer.path}"
  else
    puts "writing to #{writer.path}"
    writer.write
  end
end

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

validate_presence!(assembly: assembly, vm: vm)

unless assembly.nil?
  process_assembly(Pathname.new(assembly), dry_run: dry_run)
end

unless vm.nil?
  process_vm(Pathname.new(vm), dry_run: dry_run)
end

