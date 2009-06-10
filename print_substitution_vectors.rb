#!/usr/bin/env ruby -w

require "rubygems"
require "narray"

matrix_file = ARGV.first

arrays = []
array_names = []
current_array = nil
tag = false

IO.foreach(matrix_file) do |line|
  line.chomp!
  if line =~ /^#/
    next
  elsif line =~ /^>Total/
    break
  elsif line =~ /^>(\S+)\s+(\d+)/
    tag = true
    current_array = []
    array_names << $1
  elsif line =~ /^J\s+(.*)$/
    tag = false
    current_array.concat($1.strip.split(/\s+/).map(&:to_f))
    arrays << NArray.to_na(current_array)
  elsif (line =~ /^\S\s+(.*)$/) && tag
    current_array.concat($1.strip.split(/\s+/).map(&:to_f))
  else
    #raise "Something wrong!: #{line}"
    next
  end
end

arrays.each_with_index do |arr, i|
  puts "#{array_names[i]} #{arr.to_a.join(' ')}"
end
