require 'rubygems'
Bundler.require

require './env.rb'

namespace :db do
  task :setup do
    DB.create_table :stats do
      primary_key [:client_id, :date, :key, :value]
      String :client_id
      DateTime :date
      String :key
      String :value
      Integer :num
      index [:client_id, :date, :key]
      index [:date, :key]
      index [:key]
    end
  end
end
