#!/usr/bin/env ruby -w

require "rubygems"
require "narray"

amino_acids = "ACDEFGHIKLMNPQRSTVWYJ".split("")
matrix_file = "egor60.prob.mat"
#matrix_file = "egor60.logo.mat"
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
    #raise "Something is wrong!: #{line}"
  end
end

(0..arrays.first.size-1).each do |ci|
  val1 = ci.to_i / 21
  val2 = ci.to_i % 21
  aa1 = amino_acids[val1]
  aa2 = amino_acids[val2]
  stem = aa1 + aa2

  f2 = File.open("#{stem}.R", "w")
  f2.puts <<R_CODE
mydata <- read.table("#{stem}.txt",header=TRUE)
mydata.aov <- aov(PRB~SSE+SA+HB+WHB+VDW,data=mydata)
summary(mydata.aov)
R_CODE
  f2.close

  f1 = File.open("#{stem}.txt", "w")
  f1.puts "PRB SSE SA HB WHB VDW"

  arrays.each_with_index do |arr, ai|
    row_arr = []
    row_arr << arr[ci]
    name = array_names[ai]

    if name =~ /^H/
      row_arr << 'H'
    elsif name =~ /^E/
      row_arr << 'E'
    elsif name =~ /^P/
      row_arr << 'P'
    elsif name =~ /^C/
      row_arr << 'C'
    else
      raise "Something is wrong!: #{name}"
    end

    if name =~ /^\wA/
      row_arr << "T"
    elsif name =~ /^\wa/
      row_arr << "F"
    else
      raise "Something is wrong!: #{name}"
    end

    if name =~ /^\w\wH/
      row_arr << "T"
    elsif name =~ /^\w\wh/
      row_arr << "F"
    else
      raise
    end

    if name =~ /^\w\w\wW/
      row_arr << "T"
    elsif name =~ /^\w\w\ww/
      row_arr << "F"
    else
      raise
    end

    if name =~ /^\w\w\w\wV/
      row_arr << "T"
    elsif name =~ /^\w\w\w\wv/
      row_arr << "F"
    else
      raise
    end

    f1.puts row_arr.join(" ")
  end
  f1.close

  system "R CMD BATCH #{stem}.R #{stem}.Rout"
end

f3 = File.open("PRB-Restraints-ANOVA-DNA.txt", "w")
f3.puts %w[AA1 AA2 SSE_F SSE_PR SA_F SA_PR HB_F HB_PR WHB_F WHB_PR VDW_F VDW_PR].join(" ")

Dir["./*.Rout"].each do |file|
  std_line = []

  if file =~ /(\w)(\w)\.Rout/
    std_line << $1 << $2
  else
    raise "#{file}"
  end

  IO.foreach(file) do |line|
    line.strip!.chomp!
    if line =~ /^SSE/ or line =~ /^SA/ or line =~ /^HB/ or line =~ /^WHB/ or line =~ /^VDW/
      elems = line.gsub(/[<\*]/, "").chomp.split(/\s+/)
      std_line << elems[4] << elems[5]
    end
  end

  f3.puts std_line.join(" ")
end
f3.close

