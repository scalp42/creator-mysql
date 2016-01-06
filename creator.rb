#!/usr/bin/env ruby

require 'logger'
require 'mysql'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

if ENV['CREATOR_MYSQL_DATABASES']
  dbs = ENV.fetch('CREATOR_MYSQL_DATABASES').split('|')
else
  logger.info('creator-mysql') { %| => CREATOR_MYSQL_DATABASES variable does not exist! Bailing.| }
  exit 1
end

begin
  logger.info('creator-mysql') { %| => Connecting to #{ENV.fetch('CREATOR_MYSQL_HOST', 'localhost')}...| }
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
      logger.info('creator-mysql') { %| => Setting up #{db}...| }
      c.query(query)
      logger.info('creator-mysql') { %| => ...done.| }
    end
  end

  logger.close

  if ENV['CREATOR_MARATHON']
    # Hack not have the app exit under Marathon
    logger.info('creator-mysql') { %| => CREATOR_MARATHON specified, sleeping forever.| }
    logger.close
    sleep
  end
rescue Mysql::ServerError::AccessDeniedError, Errno::ETIMEDOUT => ex
  logger.info('creator-mysql') { %| => #{ex.message}| }
ensure
  logger.close
end
