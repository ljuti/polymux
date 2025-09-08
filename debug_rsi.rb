#!/usr/bin/env ruby

rsi_values = [45.2, 52.8, 68.5, 74.3, 71.9, 65.1, 33.7, 28.4, 31.2, 48.6]

puts "Debugging RSI strength calculation:"
rsi_values.each do |value|
  strength = case value
  when 0..20 then "extremely_oversold"
  when 21..30 then "oversold"
  when 31..45 then "weak"
  when 46..55 then "neutral"
  when 56..70 then "strong"
  when 71..80 then "overbought"
  when 81..100 then "extremely_overbought"
  end
  puts "RSI: #{value} -> strength: #{strength.inspect} (#{strength.class})"
end
