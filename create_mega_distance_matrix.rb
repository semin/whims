#!/usr/bin/env ruby -w

require "rubygems"
require "narray"

matrix_file = ARGV.first

raise "must provide file to read!" if matrix_file.nil?

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
    next
    #raise "Something wrong!: #{line}"
  end
end

puts <<MEGA
#mega
!Format
  DataType=distance
  NTaxa=64
  DataFormat=upperright;

MEGA

array_names.each_with_index do |name, index|
  puts "\##{name}(#{index})"
end

prev = arrays.first

j = 0
arrays.combination(2) do |v1, v2|
  if prev == v1
    print "#{j == 0 ? '' : ' '}" + "%.3f" % NMath.sqrt(((v1-v2)**2).sum).to_s
  else
    puts
    prev = v1
    print "%.3f" % NMath.sqrt(((v1-v2)**2).sum).to_s
  end
  j += 1
end
puts
