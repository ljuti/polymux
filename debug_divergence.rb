#!/usr/bin/env ruby

stock_prices = [
  {timestamp: 1704067200000, price: 150.00},
  {timestamp: 1704153600000, price: 158.00},
  {timestamp: 1704240000000, price: 155.00},
  {timestamp: 1704326400000, price: 162.00},
  {timestamp: 1704412800000, price: 160.00},
  {timestamp: 1704499200000, price: 165.00},
  {timestamp: 1704585600000, price: 163.00},
  {timestamp: 1704672000000, price: 150.00},
  {timestamp: 1704758400000, price: 155.00},
  {timestamp: 1704844800000, price: 152.00}
]

rsi_values = [45.0, 68.5, 65.0, 74.3, 67.0, 70.0, 50.0, 18.4, 31.2, 28.6]

puts "Stock prices length: #{stock_prices.length}"
puts "RSI values length: #{rsi_values.length}"

# Simulate the loop condition
stock_prices.each_with_index do |price_point, index|
  puts "Index: #{index}, Price: #{price_point[:price]}, RSI: #{rsi_values[index] || "nil"}"

  if index > 0 && index < stock_prices.length - 1
    puts "  Processing peak detection for index #{index}"
    puts "  Accessing index+1=#{index + 1} for RSI: #{rsi_values[index + 1] || "nil"}"
  else
    puts "  Skipping peak detection for boundary index #{index}"
  end
end
