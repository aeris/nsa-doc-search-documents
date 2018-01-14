#!/usr/bin/env ruby
require 'open3'
require 'fileutils'
require 'tempfile'
require 'parallel'
require 'colorize'

ENV['MAGICK_TEMPORARY_PATH'] = 'tmp'

def execute(*args)
	#puts *args.join(' '), "\n"
	o, e, s = Open3.capture3 *args
	raise StandardError, e unless s.success?
	#puts o, e, s
	[o, e, s]
end

pdf = Dir['todo/*.pdf'].sort
Parallel.each(pdf, in_threads: 16,
	progress: 'OCRising',
	start: -> (pdf, *_) { puts pdf.colorize :yellow },
	finish: -> (pdf, *_) { puts pdf.colorize :green }
) do |pdf|
	doc = File.basename(pdf, '.pdf').gsub(/[^a-zA-z0-9\-_]/, '_').gsub /_+/, '_'

	# puts "Converting #{pdf}"
	o, _ = execute 'pdfinfo', pdf
	pages = o.split(/$/).find { |l| l =~ /^Pages:/ }.split(/\s+/).last.to_i
	# puts "  #{pages} pages found"

	FileUtils.mkdir_p File.join doc
	FileUtils.mkdir_p File.join doc, 'png', 'thumbnails'
	FileUtils.mkdir_p File.join doc, 'txt'

	pages.times do |n|
		# puts "  Converting page #{n}/#{pages}"
		name = "#{n+1}"
		page = "#{pdf}[#{n}]"
		png = File.join doc, 'png', "#{name}.png"
		png_thumbnail = File.join doc, 'png', 'thumbnails', "#{name}.png"
		txt = File.join doc, 'txt', name

		Tempfile.create [name, '.tif'], 'tmp' do |tif|
			# puts "    Extract TIF : #{page} -> #{tif.to_path}"
			execute 'convert', '-density', '300', '-depth', '8', '-background', 'white', '-flatten', '+matte', page, tif.to_path
			# puts "    Extract TXT : #{tif.to_path} -> #{txt}"
			execute 'tesseract', '-l', 'eng', '-psm', '1', tif.to_path, txt
			# puts "    Extract PNG : #{tif.to_path} -> #{png}"
			execute 'convert', '-resize', '1024x', '-density', '120', tif.to_path, png
			execute 'optipng', '-o7', png
			# puts "    Extract thumbnail PNG : #{png} -> #{png_thumbnail}"
			execute 'convert', '-resize', '400x', png, png_thumbnail
			execute 'optipng', '-o7', png_thumbnail
		end
	end

	FileUtils.mv pdf, 'pdf'
end
