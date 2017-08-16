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
    @arrays = Hash(UInt32, Array(Array(UInt32))).new
    @arrays[0_u32] = [@program]
    @finger = 0_u32
    @dump = false
    @dump_file = File.new("decompressed.um", "w")
    @input_str = "(\\b.bb)(\\v.vv)06FHPVboundvarHRAk"
    @input_pos = 0
  end

  def start
    while step()
    end
    @dump_file.close
  end

  def step
    platter = @program[@finger]
    reg_a = (platter >> 6) & 7
    reg_b = (platter >> 3) & 7
    reg_c = (platter >> 0) & 7
    opcode = platter >> 28
    case opcode
    when 0 # Conditional Move
      STDERR.puts("r[#{reg_a}] <- r[#{reg_b}] if r[#{reg_c}] #{@register}")
      @register[reg_a] = @register[reg_b] if @register[reg_c] != 0
    when 1 # Array Index
      ar = @arrays[@register[reg_b]][0]
      if ar.size <= @register[reg_c]
        STDERR.puts("#{ar.size}  #{@register[reg_c]}")
      end
      STDERR.puts("r[#{reg_a}] = arr[#{@register[reg_b]}][#{@register[reg_c]}] #{@register}")
      @register[reg_a] = ar[@register[reg_c]]
    when 2 # Array Amendment
      STDERR.puts("arr[#{@register[reg_a]}][#{@register[reg_b]}] = r[#{reg_c}] #{@register}")
      @arrays[@register[reg_a]][0][@register[reg_b]] = @register[reg_c]
    when 3 # Addition
      STDERR.puts("r[#{reg_a}] <- r[#{reg_b}] + r[#{reg_c}] #{@register}")
      @register[reg_a] = @register[reg_b] + @register[reg_c]
    when 4 # Multiplication
      STDERR.puts("r[#{reg_a}] <- r[#{reg_b}] * r[#{reg_c}] #{@register}")
      @register[reg_a] = @register[reg_b] * @register[reg_c]
    when 5 # Division
      STDERR.puts("r[#{reg_a}] <- r[#{reg_b}] / r[#{reg_c}] #{@register}")
      @register[reg_a] = @register[reg_b] / @register[reg_c]
    when 6 # Not-And
      STDERR.puts("r[#{reg_a}] <- ~(r[#{reg_b}] & r[#{reg_c})] #{@register}")
      @register[reg_a] = ~(@register[reg_b] & @register[reg_c])
    when 7 # Halt
      return false
    when 8 # Allocation
      # raise @register[reg_b].to_s if @arrays.has_key?(@register[reg_b])
      if !@arrays.has_key?(@register[reg_b])
        @arrays[@register[reg_b]] = [] of Array(UInt32)
      end
      STDERR.puts("alloc:#{@register[reg_b]} #{@register[reg_c]}")
      @arrays[@register[reg_b]] << Array(UInt32).new(@register[reg_c], 0_u32)
    when 9 # Abandonment
      STDERR.puts("abandon:#{@register[reg_c]}")
      raise @register[reg_c].to_s if !@arrays.has_key?(@register[reg_c])
      @arrays[@register[reg_c]].shift
    when 10 # Output
      if @dump
        @dump_file.write_byte(@register[reg_c].to_u8)
      else
        print @register[reg_c].unsafe_chr
        STDERR.puts(@register[reg_c].unsafe_chr)
      end
    when 11 # Input
      if @input_pos < @input_str.size
        input = @input_str[@input_pos].ord
        @input_pos += 1
      else
        input = STDIN.read_byte
      end
      @register[reg_c] = input ? input.to_u32 : UInt32::MAX
      @dump = @register[reg_c] == 'p'.ord
    when 12 # Load Program
      if @register[reg_b] != 0
        STDERR.puts("load array:#{@register[reg_b]} finger:#{@register[reg_c]}")
        @program = @arrays[@register[reg_b]][0].clone
        @arrays[0_u32] = [@program]
      end
      STDERR.puts("load program: size:#{@program.size} finger:#{@finger}(#{@finger.to_s(16)})->#{@register[reg_c]}(#{@register[reg_c].to_s(16)})")
      @finger = @register[reg_c]
    when 13 # Orthography
      reg_a = (platter >> 25) & 7
      value = platter & 0x01FF_FFFF
      STDERR.puts("r[#{reg_a}] <- #{value}")
      @register[reg_a] = value
    end
    @finger += 1 unless opcode == 12
    @finger < @program.size
  end
end

um = UniversalMachine.new(ARGV[0])
um.start
