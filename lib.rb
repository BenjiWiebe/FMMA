#!/usr/bin/ruby
require 'mechanize'
require 'nokogiri'
require 'pry'
require 'sqlite3'

class FMMA
	def initialize(config)
		@txtdoc = config["outfile"]
		@login_init = 'https://secure.fmmacentral.com/Login.asp'
		@login_post = 'https://secure.fmmacentral.com/login_validate.asp'
		@download_url = 'https://secure.fmmacentral.com/File_Download.asp'
		@csrftoken = ''
		@data = []
		@mech = Mechanize.new
		@mainpage = nil
		@config = config
	end
	
	def get_password
		Base64.decode64(@config["password"])
	end
	def get_docpassword
		Base64.decode64(@config["docpassword"])
	end
	private :get_password, :get_docpassword

	def login()
		loginpage = @mech.get(@login_init)
		nl = Nokogiri::HTML(loginpage.body)
		@csrftoken = nl.at_xpath('//input[@name=\'hiddCSRFToken\']')['value']
		resp = @mech.post(@login_post,  {'txbxUsername' => @config["username"], 'txbxPassword' => get_password(), 'hiddCSRFToken' => @csrftoken, 'btnSubmit' => 'submit'})
		@mainpage = Nokogiri::HTML(resp.body)
	end
	def download(reportform)
		inputs = {}
		reportform.css('input').each do |input|
			inputs[input["name"]] = input["value"]
		end
		dl = @mech.post(@download_url, inputs)
		File.open(@txtdoc + '.pdf', "wb") do |f|
			f.write(dl.body)
		end

		docpass = get_docpassword()
		`pdftotext -nopgbrk -opw #{docpass} -upw #{docpass} -layout #{@txtdoc + '.pdf'} #{@txtdoc}`
		raise "PDFtoText failure" unless $?.success? 

		File.unlink(@txtdoc + '.pdf')
		return @txtdoc
	end
	def download_latest
		avail = list_available
		download(avail.first[1])
	end

	# Get list of producer reports that are currently available
	# @return [Hash] Chronologically reverse-sorted list of reports, date => report
	def list_available
		all = @mainpage.xpath('//input[@type=\'submit\']')
		if all.length < 1
			raise "No reports found"
		end
		reports = {}
		all.each do |r|
			# Out of "Producer Component Tests 201912 PDF", get the first part of it that is digits only
			date = r["value"].split.select{|x| x =~ /\d+/ }.first

			# Add to the results a mapping of date => parent form element, to pass to #download
			reports[date] = r.parent
		end
		
		# Sort the reports such that newest is first
		return reports.sort.reverse.to_h
	end
	def process_txt
		monthnames = %w{january february march april may june july august september october november december}
		monthyear = /^\s*(#{monthnames.join("|")}) (20\d\d)\s+/
		month = nil
		year = nil
		is_data = false
		File.open(@txtdoc, "r") {|f| f.each{|line|
			if line.downcase =~ monthyear
				month = monthnames.index($1) + 1
				year = $2.to_i
			elsif line =~ /_{10,}/
				is_data = true
				next
			elsif line =~ /^AVERAGE/
				break
			end
			@data << line if is_data
		}}
		if month.nil? || year.nil?
			puts "No month or year found"
			exit 1
		end
		@data.map!(&:split)
		headings = @data.shift
		@data.map! do |d|
			d.unshift month.to_s
			d.unshift year.to_s
		end
		if i = headings.index("LATOSE")
			headings[i] = "LACTOSE"
		end
		if headings != ["DATE", "BUTTERFAT", "PROTEIN", "OTH", "SLDS", "LACTOSE", "SCC", "MUN"]
			puts "Format changed."
			exit 1
		end
		File.unlink @txtdoc if File.exists? @txtdoc
		#TODO Use some sort of mktemp thing
		return @data
	end
end
