class VmTranslator
  def initialize(path)
    @path = path
  end

  def raw_lines
    File.read(@path).split("\n")
  end

  def parsed_lines
    @parsed_lines ||= raw_lines.map do |text|
      text = text.split("//").first.strip.gsub(/\ +/, " ")
      next if text.empty?
      Line.build(text)
    end.compact
  end

  def output
    @output ||= parsed_lines.map(&:asm).join("\n")
  end

  def write
    @path
      .sub("vm", "asm")
      .tap { |path| puts "writing to #{path}" }
      .write(output)
  end

  class Line < Struct.new(:text)
    def self.build(text)
      subclass = subclasses.find do |subclass|
        subclass != Invalid && subclass::REGEX.match?(text)
      end
      (subclass || Invalid).new(text)
    end

    def method_missing(name, *args)
      self.class::REGEX.match(text)[name]
    rescue IndexError
      raise NoMethodError
    end

    def asm
      commands.join("\n")
    end

    def stack_value
      "@SP\nA=M"
    end

    def stack_inc
      "@SP\nM=M+1"
    end

    def stack_dec
      "@SP\nM=M-1"
    end

    def push(value)
      "#{stack_value}\nM=#{value}\n#{stack_inc}"
    end

    def pop(&block)
      "#{stack_dec}\n#{stack_value}\n#{block.call.join("\n")}"
    end

    def set(value, to:)
      "@#{value}\n#{to}=A"
    end

    def store(value, to:)
      "@#{to}\nM=#{value}"
    end

    def retrieve(register, &block)
      "@#{register}\n#{block.call.join("\n")}"
    end
  end

  class Invalid < Line
    REGEX = Regexp.compile(/.*/)

    def asm
      raise StandardError.new("invalid line: #{text}")
    end
  end

  module PushMixin
    def prefix
      set(constant, to: "D")
    end

    def core
      nil
    end

    def commands
      [prefix, core, push("D")].compact
    end
  end

  class PushConstant < Line
    include PushMixin
    REGEX = Regexp.compile(/^push constant (?<constant>\d+)$/)
  end

  class PushLocal < Line
    include PushMixin
    REGEX = Regexp.compile(/^push local (?<constant>\d+)$/)

    def core
      retrieve("LCL") { %w(A=D+M D=M) },
    end
  end

  class PopLocal < Line
    REGEX = Regexp.compile(/^pop local (?<offset>\d+)$/)

    def commands
      [
        set(offset, to: "D"),
        retrieve("LCL") { %w(D=D+M) },
        store("D", to: "R13"),
        pop { "D=M" },
        retrieve("R13") { %w(A=M M=D) },
      ]
    end
  end

  class Neg < Line
    REGEX = Regexp.compile(/^neg$/)

    def commands
      [
        pop { "M=-M" },
        stack_inc,
      ]
    end
  end

  class Add < Line
    REGEX = Regexp.compile(/^add$/)

    def commands
      [
        pop { %w(D=M) },
        pop { %w(M=D+M) },
        stack_inc,
      ]
    end
  end

  class Sub < Line
    REGEX = Regexp.compile(/^sub$/)

    def commands
      [
        pop { %w(D=M) },
        pop { %w(M=D-M) },
        stack_inc,
      ]
    end
  end

  class Eq < Line
    REGEX = Regexp.compile(/^eq$/)

    def commands
    end
  end

  class Gt < Line
    REGEX = Regexp.compile(/^gt$/)

    def commands
    end
  end

  class Lt < Line
    REGEX = Regexp.compile(/^lt$/)

    def commands
    end
  end
end



































# zero?
# x ~> 0  if x == 0
#   ~> -1 if x != 0
#
# f(0) = 0
# f(x) = -1 for x != 0
#
# and(A, B)
#   (A & B)
#
# or(A, B)
#   (A | B)
#
# not(A)
#   !A
#
# xor(A, B)
#   and(
#     or(A, B),
#     not(
#       and(A, B)
#     )
#   )
#
# and(A, 0)
#   0
#
# or(A, 0)
#   A
#
# not(0)
#   -1
#
# and(A, -1)
#   A
#
# or(A, -1)
#   -1
#
# not(-1)
#   0
#
# xor(A, 0)
#   and(or(A, 0), not(and(A, 0)))
#   and(A, not(0))
#   and(A, -1)
#   A
#
#---------------------------------------------------------
#
# xor(A, -1)
#   and(or(A, -1), not(and(A, -1)))
#   and(-1, not(A))
#   and(-1, !A)
#   !A
#   -A - 1
#
#---------------------------------------------------------
#
# and(A, 32767)       # 32767 == 0111111111111111
#   A < 0 ? 32768 + A : A
#
# or(A, 32767)
#   A < 0 ? -1 : 32767
#
# xor(A, 32767)
#   and(or(A, 32767), not(and(A, 32767)))
#   A < 0 ?
#     and(-1, not(32767 + A)) == -(32768 + A) - 1
#     and(32767, not(A)) == and(32767, -A - 1) == 32768 - A - 1
#   A < 0 ?
#     -32769 - A
#     32767 - A
#
#---------------------------------------------------------
#
# and(A, -32768)      # -32768 == 1000000000000000
#   A < 0 ? -32768 : -32768 + A
#
# or(A, -32768)
#   A < 0 ? A : -A
#
# xor(A, -32768)
#   and(or(A, -32768, not(and(A, -32768))))
#   A < 0 ?
#     and(A, not(-32768)) == and(A, 32767)
#     and(-32678 + A, not(0)) == and(-32768 + A, -1)
#   A < 0 ?
#     32768 + A
#     -32768 + A
#
#---------------------------------------------------------
#
# xor(-1, 32767)
#   -32767 - 1
#   -32768
#
# xor(-1, -32768)
#   32768 - 1
#   32767
#
#---------------------------------------------------------
#
# and(A, !A)
#   0
#
# or(A, !A)
#   -1
#
# xor(A, !A)
#   and(or(A, !A), not(and(A, !A)))
#   and(-1, not(0))
#   and(-1, -1)
#   -1
#
# A + !A
#   A + (-A - 1)
#   -1
#
#---------------------------------------------------------
# xor(A, 32767) + xor(A, -32768)
#   A < 0 ?
#     -32769 - A + 32768 + A == -1
#     32767 - A + -32768 + A == -1
#   -1
#
