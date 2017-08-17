require "./um"

WORDS = "airplane alphabet aviator bidirectional changeme creosote cyclone december dolphin elephant ersatz falderal functional future guitar gymnast hello imbroglio january joshua kernel kingfish (\b.bb)(\v.vv) millennium monday nemesis oatmeal october paladin pass password penguin polynomial popcorn qwerty sailor swordfish symmetry system tattoo thursday tinman topography unicorn vader vampire viper warez xanadu xyzzy zephyr zeppelin zxcvbnm".split
username = ARGV[0]

WORDS.each do |w|
  um = UniversalMachine.new("decompressed.um")
  puts w + " ..."
  um.input_str = username + "\n" + w + "\n"
  um.start
end
