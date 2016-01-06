#!/usr/bin/env ruby

require 'mysql'

if ENV['CREATOR_MYSQL_DATABASES']
  dbs = ENV.fetch('CREATOR_MYSQL_DATABASES').split('|')
else
  puts %|#{__method__.to_s} => CREATOR_MYSQL_DATABASES variable does not exist! Bailing.|
  exit 1
end

c = Mysql.connect(
  ENV.fetch('CREATOR_MYSQL_HOST', 'localhost'),
      ENV.fetch('CREATOR_MYSQL_USER', 'root'),
      ENV.fetch('CREATOR_MYSQL_PASS', nil)
)

dbs.each do |db|
  mysql_create = [%|CREATE DATABASE IF NOT EXISTS #{db}|]
  mysql_create << '  CHARACTER SET utf8'
  mysql_create << '  DEFAULT CHARACTER SET utf8'
  mysql_create << '  COLLATE utf8_general_ci'
  mysql_create << '  DEFAULT COLLATE utf8_general_ci;'

  mysql_grant = [%|GRANT ALL PRIVILEGES ON #{db}.* TO '#{db.gsub(/\d\s?/, '')}user'@'%' IDENTIFIED BY 'dev';|]

  mysql_flush = ['FLUSH PRIVILEGES;']

  %W|#{mysql_create.join("\n")} #{mysql_grant.join("\n")} #{mysql_flush.join("\n")}|.each do |query|
    c.query(query)
  end
end

if ENV['CREATOR_MARATHON']
  # Hack not have the app exit under Marathon
  puts %|#{__method__.to_s} => CREATOR_MARATHON specified, sleeping forever.|
  sleep
end
