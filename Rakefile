require 'rubygems'
Bundler.require

require './env.rb'

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
