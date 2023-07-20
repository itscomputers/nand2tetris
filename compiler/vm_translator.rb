class VmTranslator
  def initialize(path)
    @path = path
  end

  def program_module
    @program_module ||= ProgramModule.new(@path)
  end

  def writer
    @writer ||= ProgramWriter.new(@path.sub("vm", "asm"))
  end

  def append_commands!
    program_module.lines.each do |line|
      line.commands.each do |command|
        writer << command
      end
      writer.local += 1 if line.use_local?
    end
    self
  end

  def write!
    writer.write!
  end

  class ProgramWriter
    attr_reader :path, :commands
    attr_accessor :local

    def initialize(path)
      @path = path
      @local = 0
      @global = 0
      @commands = []
    end

    def <<(command)
      @commands << sanitize(command)
    end

    def write!
      @path.write(@commands.join("\n"))
    end

    private

    def namespace
      @namespace ||= @path.basename(".*").to_s
    end

    def sanitize(command)
      command.gsub(/\$namespace/, namespace).gsub(/\$local/, local.to_s)
    end
  end

  class ProgramModule
    attr_reader :lines

    def initialize(path)
      @path = path
      @lines = []
      build_lines
    end

    def build_lines
      @path.each_line do |text|
        text = text.split("//").first.strip.gsub(/\ +/, " ")
        next if text.empty?
        @lines << Line.build(text)
      end
    end
  end

  class Line < Struct.new(:text)
    def self.build(text)
      subclass = subclasses.find do |subclass|
        subclass != Invalid && subclass.compiled_regex.match?(text)
      end
      (subclass || Invalid).new(text)
    end

    def self.regex(value)
      @regex = value
    end

    def self.compiled_regex
      @compiled_regex ||= Regexp.compile(@regex)
    end

    def self.register(value)
      @register = value
    end

    def register
      self.class.instance_variable_get(:@register)
    end

    def self.operation(value)
      @operation = value
    end

    def operation
      self.class.instance_variable_get(:@operation)
    end

    def method_missing(name, *args)
      self.class.compiled_regex.match(text)[name]
    rescue IndexError
      raise NoMethodError
    end

    def use_local?
      false
    end

    def commands
      [
        *setup,
        *finally,
      ]
    end

    def at(register, &block)
      ["@#{register}", *block.call]
    end

    def stack_value
      at("SP") { %w(A=M) }
    end

    def stack_inc
      at("SP") { %w(M=M+1) }
    end

    def stack_dec
      at("SP") { %w(M=M-1) }
    end

    def push(value)
      [
        *stack_value,
        "M=#{value}",
        *stack_inc,
      ]
    end

    def pop(&block)
      [
        *stack_dec,
        *stack_value,
        *block.call,
      ]
    end

    def set(value, to:)
      at(value) { "#{to}=A" }
    end

    def store(value, to:)
      at(value) { "M=#{value}" }
    end
  end

  class Invalid < Line
    REGEX = /.*/

    def commands
      raise StandardError.new("invalid line: #{text}")
    end
  end

  module PushMixin
    def setup
      [
        *set(constant, to: "D"),
        *at(register) { %w(A=D+M D=M) },
      ]
    end

    def finally
      push("D")
    end
  end

  module PopMixin
    def register
      self.class.instance_variable_get(:@register)
    end

    def setup
      [
        *set(constant, to: "D"),
        *at(register) { %w(D=D+M) },
      ]
    end

    def finally
      [
        *store("D", to: "R13"),
        *pop { %w(D=M) },
        *at("R13") { %w(A=M M=D) },
      ]
    end
  end

  module UnaryOperationMixin
    def setup
      pop { operation }
    end

    def finally
      stack_inc
    end
  end

  module BinaryOperationMixin
    def setup
      [
        *pop { %w(D=M) },
        *pop { operation },
      ]
    end

    def finally
      stack_inc
    end
  end

  module ComparisonMixin
    def setup
      [
        *pop { %w(D=M) },
        *pop { %w(D=D-M) },
        *at("BRANCH.$namespace.$local") { operation },
        "D=0",
        *at("ENDBRANCH.$namespace.$local") { %w(0;JMP) },
        "(BRANCH.$namespace.$local)",
        "D=1",
        "(ENDBRANCH.$namespace.$local)",
      ]
    end

    def use_local?
      true
    end

    def finally
      [
        *push("D"),
        *stack_inc
      ]
    end
  end

  class PushConstant < Line
    include PushMixin
    regex /^push constant (?<constant>\d+)$/

    def setup
      set(constant, to: "D")
    end
  end

  class PushLocal < Line
    include PushMixin
    regex /^push local (?<constant>\d+)$/
    register "LCL"
  end

  class PushArgument < Line
    include PushMixin
    regex /^push argument (?<constant>\d+)$/
    register "ARG"
  end

  class PushThis < Line
    include PushMixin
    regex /^push this (?<constant>\d+)$/
    register "THIS"
  end

  class PushThat < Line
    include PushMixin
    regex /^push that (?<constant>\d+)$/
    register "THAT"
  end

  class PushStatic < Line
    include PushMixin
    regex /^push static (?<constant>\d+)$/

    def setup
      at("$namespace.#{constant}") { %w(D=M) }
    end
  end

  class PushTemp < Line
    include PushMixin
    regex /^push temp (?<constant>\d+)$/

    def setup
      at(5 + constant) { %w(D=M) }
    end
  end

  class PushPointer  < Line
    include PushMixin
    regex /^push pointer (?<constant>\d+)$/

    def setup
      at(3 + constant) { %w(D=M) }
    end
  end

  class PopLocal < Line
    include PopMixin
    regex /^pop local (?<constant>\d+)$/
    register "LCL"
  end

  class PopArgument < Line
    include PopMixin
    regex /^pop argument (?<constant>\d+)$/
    register "ARG"
  end

  class PopThis < Line
    include PopMixin
    regex /^pop this (?<constant>\d+)$/
    register "THIS"
  end

  class PopThat < Line
    include PopMixin
    regex /^pop that (?<constant>\d+)$/
    register "THAT"
  end

  class PopStatic < Line
    include PopMixin
    regex /^pop static (?<constant>\d+)$/

    def setup
      at("$namespace.#{constant}") { %w(D=M) }
    end
  end

  class PopTemp < Line
    include PopMixin
    regex /^pop temp (?<constant>\d+)$/

    def setup
      at(5 + constant) { %w(D=D+A) }
    end
  end

  class PopPointer < Line
    include PopMixin
    regex /^pop pointer (?<constant>\d+)$/

    def setup
      at(3 + constant) { %w(D=D+A) }
    end
  end

  class Neg < Line
    include UnaryOperationMixin
    regex /^neg$/
    operation %w(M=-M)
  end

  class Not < Line
    include UnaryOperationMixin
    regex /^not$/
    operation %w(M=!M)
  end

  class Add < Line
    include BinaryOperationMixin
    regex /^add$/
    operation %w(M=D+M)
  end

  class Sub < Line
    include BinaryOperationMixin
    regex /^sub$/
    operation %w(M=D-M)
  end

  class And < Line
    include BinaryOperationMixin
    regex /^and$/
    operation %w(M=D&M)
  end

  class Or < Line
    include BinaryOperationMixin
    regex /^or$/
    operation %w(M=D|M)
  end

  class Eq < Line
    include ComparisonMixin
    regex /^eq$/
    operation %w(D;JEQ)
  end

  class Gt < Line
    include ComparisonMixin
    regex /^gt$/
    operation %w(D;JLT)
  end

  class Lt < Line
    include ComparisonMixin
    regex /^lt$/
    operation %w(D;JGT)
  end
end

