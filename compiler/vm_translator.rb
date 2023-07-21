class VmTranslator
  def initialize(path)
    @path = path
  end

  def program_modules
    @program_modules ||= [ProgramModule.new(@path)]
  end

  def writer
    @writer ||= ProgramWriter.new(@path.sub("vm", "asm"))
  end

  def append_commands
    program_modules.each do |program_module|
      writer.append_commands(program_module)
    end
    self
  end

  def write
    writer.write
    self
  end

  class ProgramWriter
    attr_reader :path, :commands

    def initialize(path)
      @path = path
      @local = 0
      @commands = []
    end

    def write
      @path.write(@commands.join("\n"))
    end

    def append_commands(program_module)
      program_module.lines.each do |line|
        line.commands.each do |command|
          @commands << sanitize(command, program_module.namespace)
        end
        @local += 1 if line.use_local?
      end
      @local = 0
      self
    end

    private

    def sanitize(command, namespace)
      command.gsub(/\$namespace/, namespace).gsub(/\$local/, @local.to_s)
    end
  end

  class ProgramModule
    attr_reader :lines

    def initialize(path)
      @path = path
      @lines = []
      build_lines
    end

    def namespace
      @namespace ||= @path.basename(".*").to_s
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

    def self.operation(value)
      @operation = value
    end

    attr_reader :commands

    def initialize(text)
      @text = text
      @commands = []
      build_commands
    end

    def add_command(command)
      @commands += Array(command)
    end

    def build_commands
    end

    def operation
      self.class.instance_variable_get(:@operation)
    end

    def register
      self.class.instance_variable_get(:@register)
    end

    def method_missing(name, *args, **kwargs)
      self.class.compiled_regex.match(@text)[name]
    rescue IndexError
      super(name, *args, **kwargs)
    end

    def use_local?
      false
    end

    def at(register, &block)
      add_command("@#{register}")
      add_command(block.call) unless block.nil?
    end

    def push
      at("SP") { %w(A=M M=D) }
      at("SP") { "M=M+1" }
    end

    def pop(&block)
      at("SP") { %w(M=M-1 A=M) }
      add_command(block.call) unless block.nil?
    end
  end

  class Invalid < Line
    REGEX = /.*/

    def build_commands
      raise StandardError.new("invalid line: #{@text}")
    end
  end

  module PushMixin
    def build_commands
      at(constant) { "D=A" }
      at(register) { %w(A=D+M D=M) }
      push
    end
  end

  module PushDirectMixin
    def build_commands
      at(register) { "D=M" }
      push
    end
  end

  module PopMixin
    def build_commands
      at(constant) { "D=A" }
      at(register) { "D=D+M" }
      at("R13") { "M=D" }
      pop { "D=M" }
      at("R13") { %w(A=M M=D) }
    end
  end

  module PopDirectMixin
    def build_commands
      pop { "D=M" }
      at(register) { "M=D" }
    end
  end

  module UnaryOperationMixin
    def build_commands
      pop { operation }
      at("SP") { "M=M+1" }
    end
  end

  module BinaryOperationMixin
    def build_commands
      pop { "D=M" }
      pop { operation }
      at("SP") { "M=M+1" }
    end
  end

  module ComparisonMixin
    def build_commands
      pop { "D=M" }
      pop { "D=D-M" }
      at(branch) { operation }
      add_command("D=0")
      at(end_branch) { "0;JMP" }
      add_command("(#{branch})")
      add_command("D=-1")
      add_command("(#{end_branch})")
      push
    end

    def use_local?
      true
    end

    def branch
      "BRANCH.$namespace.$local"
    end

    def end_branch
      "END#{branch}"
    end
  end

  class PushConstant < Line
    regex /^push constant (?<constant>\d+)$/

    def build_commands
      at(constant) { "D=A" }
      push
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

  class PushTemp < Line
    include PushDirectMixin
    regex /^push temp (?<constant>\d+)$/

    def register
      5 + constant.to_i
    end
  end

  class PushPointer  < Line
    include PushDirectMixin
    regex /^push pointer (?<constant>\d+)$/

    def register
      3 + constant.to_i
    end
  end

  class PushStatic < Line
    include PushDirectMixin
    regex /^push static (?<constant>\d+)$/

    def register
      "$namespace.#{constant}"
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

  class PopTemp < Line
    include PopDirectMixin
    regex /^pop temp (?<constant>\d+)$/

    def register
      5 + constant.to_i
    end
  end

  class PopPointer < Line
    include PopDirectMixin
    regex /^pop pointer (?<constant>\d+)$/

    def register
      3 + constant.to_i
    end
  end

  class PopStatic < Line
    include PopDirectMixin
    regex /^pop static (?<constant>\d+)$/

    def register
      "$namespace.#{constant}"
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
    operation %w(D=-D M=D+M)
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

