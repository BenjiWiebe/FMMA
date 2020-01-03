#!/usr/bin/ruby
require 'base64'
require 'yaml'
require_relative 'lib.rb'
require_relative 'db.rb'

puts "Content-Type: text/plain"
puts ""

#TODO if this months entries are < 3, check if this month has any entries in the db yet. if not, then download last months before inserting this months. maybe save this months in a temporary hash
cfgfile = 'fmma.config'

cfg = YAML.load(File.open(cfgfile).read)

if cfg["outfile"].nil?
	cfg["outfile"] = "/tmp/fmma.txt"
end

fmma = FMMA.new(cfg)
fmma.login
reports = fmma.list_available
fmma.download_latest
data = fmma.process_txt
write_data(cfg["dbpath"], data)
if data.nil? || data.length == 0
	raise "No data"
end

if false
	puts "Data updated."
else
	puts "No change."
end
