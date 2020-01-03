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

def write_data(dbpath, data)
	require 'pry';binding.pry
	sql = "INSERT OR IGNORE INTO DATA(YEAR,MONTH,DATE,BUTTERFAT,PROTEIN,OTHSLDS,LACTOSE,SCC,MUN) VALUES(?,?,?,?,?,?,?,?,?)"
	changes = 0
	db = SQLite3::Database.new dbpath
	db.execute Schema if File.empty? dbpath
	begin
		stm = db.prepare sql
		rs = nil
		db.transaction
		data.each do |d|
			if d.last == '*'
				d.pop
			end
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

