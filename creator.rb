#!/usr/bin/env ruby

require 'logger'
require 'mysql'

$stdout.sync = true

logger = Logger.new(STDOUT)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity} creator-mysql: #{msg}\n"
end

if ENV['CREATOR_MYSQL_DATABASES']
  dbs = ENV.fetch('CREATOR_MYSQL_DATABASES').split('|')
else
  logger.info { %|=> CREATOR_MYSQL_DATABASES variable does not exist! Bailing.| }
  exit 1
end

tries ||= ENV.fetch('CREATOR_MYSQL_TRIES', 1).to_i
begin
  logger.info { %|=> Connecting to #{ENV.fetch('CREATOR_MYSQL_HOST', 'localhost')}...| }
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
      logger.info { %|=> Setting up #{db}...| }
      c.query(query)
      logger.info { %|=> ...done.| }
      c.close
    end
  end

  logger.close unless ENV['CREATOR_MARATHON']

  if ENV['CREATOR_MARATHON']
    # Hack not have the app exit under Marathon
    logger.info { %|=> CREATOR_MARATHON specified, sleeping forever.| }
    logger.close
    sleep
  end
rescue Mysql::ServerError::AccessDeniedError, Errno::ETIMEDOUT => ex
  logger.info { %|=> #{ex.message}| }
rescue SocketError => ex
  logger.warn { %|=> #{ex.message}| }
  logger.warn { %|=> Sleeping for #{ENV.fetch('CREATOR_MYSQL_SLEEP', 10)} seconds, attempts left #{tries}/#{ENV.fetch('CREATOR_MYSQL_TRIES', 1)}| }
  sleep ENV.fetch('CREATOR_MYSQL_SLEEP', 10).to_i
  retry unless (tries -= 1).zero?
ensure
  logger.close
end
