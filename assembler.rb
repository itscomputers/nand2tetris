#!/usr/bin/env ruby

class Assembler
  def initialize(path)
    @path = path
  end

  def raw_lines
    File.read(@path).split("\n")
  end

  def parsed_lines
    @parsed_lines ||= raw_lines.map do |text|
      text = text.split("//").first.strip
      next if text.empty?
      Line.build(text).tap do |line|
        raise StandardError.new("#{line.text} is invalid") unless line.valid?
      end
    end.compact
  end

  def assembled_lines
    @assembled_lines ||= parsed_lines
      .reject { |line| line.is_a?(Label) }
      .map { |line| line.binary_string(symbol_table) }
  end

  def symbol_table
    @symbol_table ||= SymbolTable.build(parsed_lines)
  end

  def output
    assembled_lines.join("\n")
  end

  def write
    @path
      .sub("asm", "hack")
      .tap { |path| puts "writing to #{path}" }
      .write(output)
  end

  class Line < Struct.new(:text)
    def self.build(text)
      if text.start_with?("@")
        AInstruction.new(text)
      elsif text.start_with?("(") && text.end_with?(")")
        Label.new(text)
      else
        CInstruction.new(text)
      end
    end

    def symbol_regex
      @symbol_regex ||= Regexp.compile(/^[A-Za-z_:\.\$][A-Za-z0-9_:\.\$]*$/)
    end

    def with_padding(string, size)
      [
        *size.times.map { "0" },
        *string.chars,
      ].last(size).join
    end
  end

  class AInstruction < Line
    def inspect
      "<A #{symbol? ? "symbol" : "number"}: #{name}>"
    end

    def name
      text.slice(1..)
    end

    def symbol?
      name.match?(symbol_regex)
    end

    def symbol
      @symbol ||= name.to_sym
    end

    def number?
      name.match?(/^[0-9]+$/)
    end

    def valid?
      text.start_with?("@") && (number? || symbol?)
    end

    def address(symbol_table)
      return name.to_i if number?
      symbol_table.add(symbol)
      symbol_table.get_address(symbol)
    end

    def binary_string(symbol_table)
      with_padding(address(symbol_table).to_s(2), 16)
    end
  end

  class CInstruction < Line
    COMP_LOOKUP = {
      "0" => 42,
      "1" => 63,
      "-1" => 58,
      "D" => 12,
      "A" => 48,
      "M" => 112,
      "!D" => 13,
      "!A" => 49,
      "!M" => 113,
      "-D" => 15,
      "-A" => 51,
      "-M" => 115,
      "D+1" => 31,
      "A+1" => 55,
      "M+1" => 119,
      "D-1" => 14,
      "A-1" => 50,
      "M-1" => 114,
      "D+A" => 2,
      "D+M" => 66,
      "D-A" => 19,
      "D-M" => 83,
      "A-D" => 7,
      "M-D" => 71,
      "D&A" => 0,
      "D&M" => 64,
      "D|A" => 21,
      "D|M" => 85,
    }

    DEST_LOOKUP = {
      nil => 0,
      "M" => 1,
      "D" => 2,
      "MD" => 3,
      "A" => 4,
      "AM" => 5,
      "AD" => 6,
      "AMD" => 7,
    }

    JUMP_LOOKUP = {
      nil => 0,
      "JGT" => 1,
      "JEQ" => 2,
      "JGE" => 3,
      "JLT" => 4,
      "JNE" => 5,
      "JLE" => 6,
      "JMP" => 7,
    }

    def inspect
      [
        "<C",
        dest.nil? ? nil : "dest=#{dest}",
        comp.nil? ? nil : "comp=#{comp}",
        jump.nil? ? nil : "jump=#{jump}",
        ">"
      ].compact.join(" ")
    end

    def regex
      @regex ||= Regexp.compile(
        /^(?<dest>[ADM]+)?=?(?<comp>[ADM01!+\-&\|]+);?(?<jump>J(GT|EQ|GE|LT|NE|LE|MP))?$/
      )
    end

    def parts
      @parts ||= text.match(regex).named_captures
    end

    def dest
      @dest ||= parts["dest"]
    end

    def comp
      @comp ||= parts["comp"]
    end

    def jump
      @jump ||= parts["jump"]
    end

    def valid?
      text.match?(regex) && !comp.nil?
    end

    def get_binary_string(lookup, key, size:)
      raise KeyError.new("invalid key: #{key}") unless lookup.key?(key)
      with_padding(lookup[key].to_s(2), size)
    end

    def binary_string(symbol_table)
      [
        "111",
        get_binary_string(COMP_LOOKUP, comp, size: 7),
        get_binary_string(DEST_LOOKUP, dest, size: 3),
        get_binary_string(JUMP_LOOKUP, jump, size: 3),
      ].join
    end
  end

  class Label < Line
    def inspect
      "<Label #{name}>"
    end

    def name
      @name ||= text.slice(1...-1).to_sym
    end

    def valid?
      text.start_with?("(") &&
        text.end_with?(")") &&
        name.match?(symbol_regex)
    end

    def binary_string(_symbol_table)
      nil
    end
  end

  class SymbolTable
    def self.build(lines)
      new(lines).build
    end

    attr_reader :lookup

    def initialize(lines)
      @lines = lines
      @lookup = {
        :SP => 0,
        :LCL => 1,
        :ARG => 2,
        :THIS => 3,
        :THAT => 4,
        :SCREEN => 16384,
        :KBD => 24576,
      }
      (0..15).each do |register|
        @lookup["R#{register}".to_sym] = register
      end
      @label_count = 0
      @address = 16
    end

    def add(key)
      unless includes?(key)
        @lookup[key] = @address
        @address += 1
      end
      self
    end

    def add_label(label, value)
      raise StandardError.new("duplicate: #{label.name}") if includes?(label.name)
      @lookup[label.name] = value
      @label_count += 1
    end

    def includes?(variable)
      @lookup.key?(variable)
    end

    def get_address(variable)
      unless includes?(variable)
        raise ArgumentError.new("unknown variable: #{variable}")
      end
      @lookup[variable]
    end

    def build
      @lines.each_with_index do |line, index|
        if line.is_a?(Label)
          add_label(line, index - @label_count)
        end
      end
      self
    end
  end
end

require "pathname"

FILENAME, *_ = ARGV
PATH = Pathname.new(FILENAME)
puts "assembling: #{PATH}"
ASSEMBLER = Assembler.new(PATH)
puts "parsing... line count: #{ASSEMBLER.parsed_lines.size}"
puts "\nsymbol table:"
ASSEMBLER.symbol_table.lookup.each do |k, v|
  next if [:SP, :LCL, :ARG, :THIS, :THAT, :SCREEN, :KBD].include?(k)
  next if k.match?(/R\d+/)
  puts "  #{k}: #{v}"
end
puts "\nlines:"
ASSEMBLER
  .parsed_lines
  .reject { |line| line.is_a?(Assembler::Label) }
  .zip(ASSEMBLER.assembled_lines)
  .each_with_index { |(l, tl), index| puts "#{index}: #{tl} #{l.inspect}" }

puts "\nfinishing:"
ASSEMBLER.write

