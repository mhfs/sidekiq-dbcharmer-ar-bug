require "sidekiq"
require "active_record"
require "db_charmer"

##
# Setup AR and establish connection
ActiveRecord::Base.logger = Logger.new('debug.log')
ActiveRecord::Base.configurations = YAML::load(IO.read('./database.yml'))
ActiveRecord::Base.establish_connection 'development'

##
# Setup Sidekiq Redis connection
Sidekiq.configure_server do |config|
  config.redis = { :url => 'redis://127.0.0.1:16379/7' }
end

Sidekiq.configure_client do |config|
  config.redis = { :url => 'redis://127.0.0.1:16379/7' }
end

##
# Create empty user table and model
class CreateUserSchema < ActiveRecord::Migration
  def change
    [:slave1, :slave2, :slave3, :default].each do |conn|
      on_db conn do
        create_table :users, force: true do |t|
          t.string :name
        end
      end
    end
  end
end
CreateUserSchema.new.change

class User < ActiveRecord::Base
end

##
# Define our worker
class HardWorker
  include Sidekiq::Worker

  def perform
    # conn = [:slave1, :slave2, :slave3, nil].sample
    User.on_db(:slave1).find(rand(1..10))
  end
end

##
# Flush sidekiq redis db to avoid outside interference
Sidekiq.redis { |conn| conn.flushdb }

##
# Create a bunch of users and sidekiq jobs
[:slave1, :slave2, :slave3, nil].each do |conn|
  10.times do
    User.on_db(conn).create!(name: "Marcelo")
  end
end

100.times { HardWorker.perform_async }
