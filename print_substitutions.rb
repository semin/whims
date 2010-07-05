#!/usr/bin/env ruby -w

require "rubygems"
require "facets/enumerable"

matrix_file   = ARGV[0]
aas           = nil
envs          = []
arrays        = []
array_names   = []
current_array = nil
tag           = false

IO.foreach(matrix_file) do |line|
  line.chomp!
  if line =~ /^#\s+(ACDEFGHIKLMNPQRSTV\w+)/
    aas = $1.split('')
  elsif line =~ /^#\s+(.*);(\w+);(\w+);[T|F];[T|F]/
    envs << [$1, $2, $3.split('')]
  elsif line =~ /^#/
    next
  elsif line =~ /^>Total/i
    break
  elsif line =~ /^>(\S+)\s+(\d+)/
    tag = true
    current_array = []
    array_names << $1
  elsif line =~ /^#{aas[-1]}\s+(.*)$/
    tag = false
    current_array.concat($1.strip.split(/\s+/).map(&:to_f))
    arrays << current_array
  elsif (line =~ /^\S\s+(.*)$/) && tag
    current_array.concat($1.strip.split(/\s+/).map(&:to_f))
  else
    raise "Something wrong!: #{line}"
  end
end

arrays.each_with_index do |arr, i|
  env = array_names[i].split('').map_with_index { |c, id| envs[id][2].index(c) }
  (0...aas.length).each do |ii|
    (0...aas.length).each do |jj|
      index = ii * aas.length + jj
      #aa_x = aas[jj]
      #aa_y = aas[ii]
      freq = arr[index]
      line = [jj, ii, env.flatten].join(', ') + "\n"
      puts line * freq.ceil if freq.ceil > 0
    end
  end
end
