require "logger"

SEGMENT_BITS = 10
DEBUG        = false

class Platters
  @mapping : (Array(Array(UInt32) | Nil) | Nil)

  def initialize(@size : UInt32)
  end

  def [](idx : UInt32)
    m = @mapping
    if !m
      0_u32
    else
      a = m[idx >> SEGMENT_BITS]?
      if !a
        0_u32
      else
        a[idx & ((1_u32 << SEGMENT_BITS) - 1)]
      end
    end
  end

  def []=(idx : UInt32, value : UInt32)
    m = @mapping
    i1 = idx >> SEGMENT_BITS
    i2 = idx & ((1_u32 << SEGMENT_BITS) - 1)
    if !m
      m = Array(Array(UInt32) | Nil).new(((@size + ((1 << SEGMENT_BITS) - 1)) >> SEGMENT_BITS) + 1_u32, nil)
      a = Array.new(1 << SEGMENT_BITS, 0_u32)
      a[i2] = value
      m[i1] = a
      @mapping = m
    else
      a = m[i1]?
      if !a
        a = Array.new(1 << SEGMENT_BITS, 0_u32)
        a[i2] = value
        m[i1] = a
      else
        a[i2] = value
      end
    end
  end

  def size
    @size
  end

  def to_a
    m = @mapping
    ret = Array.new(@size, 0_u32)
    if !m
      ret
    else
      m.size.times do |i|
        a = m[i]
        if a
          a.size.times do |j|
            break if (i << SEGMENT_BITS) + j >= @size
            ret[(i << SEGMENT_BITS) + j] = a[j]
          end
        end
      end
      ret
    end
  end
end

class UniversalMachine
  def initialize(program_file : String)
    file = File.new(program_file)
    bytes = Bytes.new(file.size)
    file.read(bytes)
    @program = Array(UInt32).new(bytes.size / 4) do |i|
      (bytes[i * 4].to_u32 << 24) +
        (bytes[i * 4 + 1].to_u32 << 16) +
        (bytes[i * 4 + 2].to_u32 << 8) +
        (bytes[i * 4 + 3].to_u32 << 0)
    end
    @register = Array(UInt32).new(8, 0_u32)
    @arrays = Hash(UInt32, Array(UInt32)).new
    @arrays[0_u32] = @program
    @finger = 0_u32
    @rng = Random.new(42)
    # @dump = false
    # @dump_file = File.new("dump.um", "w")
    @input_str = "guest\n" # "(\\b.bb)(\\v.vv)06FHPVboundvarHRAk"
    @input_pos = 0
    @logger = Logger.new(STDERR)
    @logger.level = DEBUG ? Logger::INFO : Logger::WARN
    @logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
      label = severity.unknown? ? "ANY" : severity.to_s
      io << label[0] << ", " << message
    end
  end

  def start
    while step()
    end
    # @dump_file.close
  end

  def step
    platter = @program[@finger]
    reg_a = (platter >> 6) & 7
    reg_b = (platter >> 3) & 7
    reg_c = (platter >> 0) & 7
    opcode = platter >> 28
    case opcode
    when 0 # Conditional Move
      @logger.info("r[#{reg_a}] <- r[#{reg_b}] if r[#{reg_c}] #{@register}") if DEBUG
      @register[reg_a] = @register[reg_b] if @register[reg_c] != 0
    when 1 # Array Index
      ar = @arrays[@register[reg_b]]
      if ar.size <= @register[reg_c]
        @logger.error("1: #{ar.size}  #{@register[reg_c]} at finger #{@finger}")
      end
      @logger.info("r[#{reg_a}] = arr[#{@register[reg_b]}][#{@register[reg_c]}] #{@register}") if DEBUG
      @register[reg_a] = ar[@register[reg_c]]
    when 2 # Array Amendment
      ar = @arrays[@register[reg_a]]
      if ar.size <= @register[reg_b]
        @logger.error("2: #{ar.size}  #{@register[reg_b]} at finger #{@finger}")
      end
      @logger.info("arr[#{@register[reg_a]}][#{@register[reg_b]}] = r[#{reg_c}] #{@register}") if DEBUG
      ar[@register[reg_b]] = @register[reg_c]
    when 3 # Addition
      @logger.info("r[#{reg_a}] <- r[#{reg_b}] + r[#{reg_c}] #{@register}") if DEBUG
      @register[reg_a] = @register[reg_b] + @register[reg_c]
    when 4 # Multiplication
      @logger.info("r[#{reg_a}] <- r[#{reg_b}] * r[#{reg_c}] #{@register}") if DEBUG
      @register[reg_a] = @register[reg_b] * @register[reg_c]
    when 5 # Division
      @logger.info("r[#{reg_a}] <- r[#{reg_b}] / r[#{reg_c}] #{@register}") if DEBUG
      @register[reg_a] = @register[reg_b] / @register[reg_c]
    when 6 # Not-And
      @logger.info("r[#{reg_a}] <- ~(r[#{reg_b}] & r[#{reg_c})] #{@register}") if DEBUG
      @register[reg_a] = ~(@register[reg_b] & @register[reg_c])
    when 7 # Halt
      return false
    when 8 # Allocation
      size = @register[reg_c]
      while true
        @register[reg_b] = (@rng.next_u & 0xFFFFFFF) + 1
        if !@arrays.has_key?(@register[reg_b])
          break
        end
      end
      @logger.info("alloc:arr[#{@register[reg_b]}] = new array[#{size}]") if DEBUG
      @arrays[@register[reg_b]] = Array.new(size, 0_u32)
    when 9 # Abandonment
      @logger.info("abandon:#{@register[reg_c]}") if DEBUG
      raise @register[reg_c].to_s if !@arrays.has_key?(@register[reg_c])
      @arrays.delete(@register[reg_c])
    when 10 # Output
      # if @dump
      #   @dump_file.write_byte(@register[reg_c].to_u8)
      # else
      print @register[reg_c].unsafe_chr
      @logger.info(@register[reg_c].unsafe_chr) if DEBUG
      # end
    when 11 # Input
      if @input_pos < @input_str.size
        input = @input_str[@input_pos].ord
        @input_pos += 1
      else
        input = STDIN.read_byte
      end
      @register[reg_c] = input ? input.to_u32 : UInt32::MAX
      # @dump = @register[reg_c] == 'p'.ord
    when 12 # Load Program
      if @register[reg_b] != 0
        @logger.info("load array:#{@register[reg_b]} finger:#{@register[reg_c]}") if DEBUG
        @program = @arrays[@register[reg_b]].clone
        @arrays[0_u32] = @program
      else
        @logger.info("jump finger:#{@finger}(#{@finger.to_s(16)})->#{@register[reg_c]}(#{@register[reg_c].to_s(16)})") if DEBUG
      end
      @finger = @register[reg_c]
    when 13 # Orthography
      reg_a = (platter >> 25) & 7
      value = platter & 0x01FF_FFFF
      @logger.info("r[#{reg_a}] <- #{value}") if DEBUG
      @register[reg_a] = value
    end
    @finger += 1 unless opcode == 12
    @finger < @program.size
  end
end

um = UniversalMachine.new(ARGV[0])
um.start
