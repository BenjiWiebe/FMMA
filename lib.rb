#!/usr/bin/ruby
require 'mechanize'
require 'nokogiri'
require 'pry'
require 'sqlite3'

class FMMA
	Schema = <<-SQL
CREATE TABLE IF NOT EXISTS data
(
	year TEXT NOT NULL,
	month TEXT NOT NULL,
	date TEXT NOT NULL,
	butterfat TEXT NOT NULL,
	protein TEXT NOT NULL,
	othslds TEXT NOT NULL,
	lactose TEXT NOT NULL,
	scc TEXT NOT NULL,
	mun TEXT NOT NULL,
	UNIQUE(year, month, date)
)
SQL
	def initialize(txtdoc = '/tmp/fmma.txt', dbpath = 'db/fmma.db')
		@txtdoc = txtdoc
		@dbpath = dbpath
		@login_init = 'https://secure.fmmacentral.com/Login.asp'
		@login_post = 'https://secure.fmmacentral.com/login_validate.asp'
		@download_url = 'https://secure.fmmacentral.com/File_Download.asp'
		@csrftoken = ''
		@data = []
		@mech = Mechanize.new
	end
	def login(username, password)
		loginpage = @mech.get(@login_init)
		nl = Nokogiri::HTML(loginpage.body)
		@csrftoken = nl.at_xpath('//input[@name=\'hiddCSRFToken\']')['value']
		@page = @mech.post(@login_post,  {'txbxUsername' => username, 'txbxPassword' => password, 'hiddCSRFToken' => @csrftoken, 'btnSubmit' => 'submit'})
	end
	def download(docpass, prevmonth=0)
		npage = Nokogiri::HTML(@page.body)
		forms = npage.css('form[action="/File_Download.asp"]')
		inputs = {}
		forms[prevmonth].css('input').each do |input|
			inputs[input["name"]] = input["value"]
		end

		dl = @mech.post(@download_url, inputs)
		File.open(@txtdoc + '.pdf', "wb") do |f|
			f.write(dl.body)
		end

		`pdftotext -nopgbrk -opw #{docpass} -upw #{docpass} -layout #{@txtdoc + '.pdf'} #{@txtdoc}`
		raise Exception unless $?.success? 

		File.unlink(@txtdoc + '.pdf')
		return @txtdoc
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
		return @data
	end
	def get_db
		@db = SQLite3::Database.new @dbpath unless @db.is_a? SQLite3::Database
		@db.execute Schema if File.empty? @dbpath
		return @db
	end
	def insert_data
		sql = "INSERT OR IGNORE INTO DATA(YEAR,MONTH,DATE,BUTTERFAT,PROTEIN,OTHSLDS,LACTOSE,SCC,MUN) VALUES(?,?,?,?,?,?,?,?,?)"
		changes = 0
		begin
			@data.map! {|d| d.pop if d.last == '*' }
			db = get_db
			stm = db.prepare sql
			rs = nil
			db.transaction
			@data.each do |d|
				rs = stm.execute *d
			end
			db.commit
			changes = db.changes
		rescue SQLite3::Exception => e
			puts "Sqlite error"
			puts e
			db.rollback
		ensure
			stm.close if stm
		end

		return changes > 0
	end
	def cleanup
		File.unlink @txtdoc if File.exists? @txtdoc
		@db.close if @db
		@db = nil
	end
end
