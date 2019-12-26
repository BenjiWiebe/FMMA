#!/usr/bin/ruby
require 'base64'
require 'yaml'
require_relative 'lib.rb'

puts "Content-Type: text/plain"
puts ""

#TODO if this months entries are < 3, check if this month has any entries in the db yet. if not, then download last months before inserting this months. maybe save this months in a temporary hash
outfile = "/tmp/fmma.txt"
cfgfile = 'fmma.config'

cfg = YAML.load(File.open(cfgfile).read)

fmma = FMMA.new(outfile, cfg["dbpath"])
fmma.login(cfg["username"], Base64.decode64(cfg["password"]))
fmma.download(Base64.decode64(cfg["docpassword"]))
data = fmma.process_txt
fmma.cleanup
inserted = fmma.insert_data
if inserted
	puts "Data updated."
else
	puts "No change."
end
