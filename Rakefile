Encoding.default_internal = 'UTF-8'
require 'rubygems'
require 'rake/testtask'
Bundler.require

require './env.rb'

Rake::TestTask.new do |t|
  t.test_files = FileList['test/rainman/*_test.rb']
  t.verbose = true
end

namespace :db do
  task :setup do
    SQL.create_table :stats do
      primary_key [:group_id, :client_id, :date, :key, :value]
      String :group_id
      String :client_id
      DateTime :date
      String :key
      String :value
      Integer :num
      index [:group_id, :client_id, :date, :key]
      index [:client_id, :date, :key]
      index [:date, :key]
      index [:key]
    end
  end
end


namespace :debug do

  class Stat < Sequel::Model; end
  EMPTY_CLIENT_ID = "-1"

  task :and_thats_why do # You always have a primary key

    drop_pk = "alter table stats drop constraint stats_pkey;"
    add_id = "ALTER TABLE stats ADD COLUMN id SERIAL;"
    update_ids = "UPDATE stats SET id = nextval(pg_get_serial_sequence('stats','id'));"
    add_pk = "ALTER TABLE stats ADD PRIMARY KEY (id);"

    SQL.run drop_pk
    SQL.run add_id
    SQL.run update_ids
    SQL.run add_pk

  end

  # Usage: be rake debug:fix_it start=2014-02-01 end=2014-03-01 verbose=1
  task :fix_it do

    # Swap client_id and group_id, cuz they backwards
    #

    def format_date when_day
      unless when_day.is_a? DateTime or when_day.is_a? Date or when_day.is_a? Time
        new_day = Date.strptime when_day, "%Y-%m-%d"
        when_day = new_day
      end
      
      "#{when_day.year}-#{when_day.month}-#{when_day.day}"
    end

    first_entry_date = Stat.order(:date).first.date
    last_entry_date = Stat.order(:date).last.date
    start_date =  ENV['start']  ? format_date(ENV['start']) : format_date(first_entry_date)
    end_date =    ENV['end']    ? format_date(ENV['end']) : format_date(last_entry_date)

    puts "Searcing for records between #{start_date} and #{end_date}"
    puts "Real Client ID\tReal Group ID\tDate" if ENV['verbose']
    puts "-----------------------------------" if ENV['verbose']
    puts

    updated = 0
    records = Stat.where(:date => start_date..end_date)
    records.each do |record|

      # -1 client_ids are correct
      unless record.client_id == EMPTY_CLIENT_ID

        real_client_id = record.group_id.dup
        real_group_id = record.client_id.dup

        puts "#{real_client_id}\t#{real_group_id}\t#{record.date}" if ENV['verbose']

        record.update(:client_id => real_client_id, :group_id => real_group_id)
        updated += 1
      end

    end

    puts "Updated #{updated} records!"

  end

end
