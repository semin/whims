#!/usr/bin/env ruby -w

require 'rubygems'
require 'rmagick'

include Magick

images = Dir["*.pdf"]
images.sort! { |a, b| a.match(/^(\d+)/)[1].to_i <=> b.match(/^(\d+)/)[1].to_i }
grouped_images = images.group_by { |i| i.match(/^(\d+)/)[1].to_i % 24 }

grouped_images.each_key do |k|
  rimages = ImageList.new(*grouped_images[k])
  appended_image = rimages.append(true)
  appended_image.write("app#{k}.pdf")
end

app_images = Dir["app*.pdf"]
raimages = ImageList.new(*app_images)
appraimage = raimages.append(false)
appraimage.write("NA-ESSTs.pdf")

