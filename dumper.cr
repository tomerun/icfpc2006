file = File.new(ARGV[0])
bytes = Bytes.new(file.size)
file.read(bytes)
program = Array(UInt32).new(bytes.size / 4) do |i|
  (bytes[i * 4].to_u32 << 24) +
    (bytes[i * 4 + 1].to_u32 << 16) +
    (bytes[i * 4 + 2].to_u32 << 8) +
    (bytes[i * 4 + 3].to_u32 << 0)
end
program.size.times do |i|
  platter = program[i]
  reg_a = (platter >> 6) & 7
  reg_b = (platter >> 3) & 7
  reg_c = (platter >> 0) & 7
  opcode = platter >> 28
  printf("%6d(%6x) ", i, i)
  case opcode
  when 0 # Conditional Move
    puts("Move   reg[#{reg_a}] = reg[#{reg_b}] if reg[#{reg_c}]")
  when 1 # Array Index
    puts("Index  reg[#{reg_a}] = arr[reg[#{reg_b}]][reg[#{reg_c}]]")
  when 2 # Array Amendment
    puts("Amend  arr[reg[#{reg_a}]][reg[#{reg_b}]] = reg[#{reg_c}]")
  when 3 # Addition
    puts("Add    reg[#{reg_a}] = reg[#{reg_b}] + reg[#{reg_c}]")
  when 4 # Multiplication
    puts("Multi  reg[#{reg_a}] = reg[#{reg_b}] * reg[#{reg_c}]")
  when 5 # Division
    puts("Divide reg[#{reg_a}] = reg[#{reg_b}] / reg[#{reg_c}]")
  when 6 # Not-And
    puts("NotAnd reg[#{reg_a}] = ~(reg[#{reg_b}] & reg[#{reg_c})]")
  when 7 # Halt
    puts("Halt")
  when 8 # Allocation
    puts("Alloc  arr[reg[#{reg_b}]] = new array(reg[#{reg_c}])")
  when 9 # Abandonment
    puts("Delete arr[reg[#{reg_c}]]")
  when 10 # Output
    puts("Output reg[#{reg_c}]")
  when 11 # Input
    puts("Input  reg[#{reg_c}]")
  when 12 # Load Program
    puts("Load   arr[reg[#{reg_b}]] at reg[#{reg_c}]")
  when 13 # Orthography
    reg_a = (platter >> 25) & 7
    value = platter & 0x01FF_FFFF
    puts("Assign reg[#{reg_a}] = #{value} #{value.chr if (32..127).includes?(value)}")
  else
    puts "Unknown opcode #{opcode}"
  end
end
