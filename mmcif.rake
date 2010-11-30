require "rubygems"
require "logger"
require "date"
require "pathname"
require "net/smtp"

include FileUtils

$config = {
  :mmcif_mirror_dir         => Pathname.new("/BiO/Mirror/PDB/data/structures/all/mmCIF"),
  :schema_map_file          => Pathname.new("/BiO/Install/db-loader/db-loader-v4.0/test/schema_map_pdbx_na.cif"),
  :db_loader_bin            => Pathname.new("/BiO/Install/db-loader/db-loader-v4.0/bin/db-loader"),
  :db_host                  => '192.168.1.2',
  :db_name                  => "MMCIF",
  :db_dbms                  => "mysql",
  :db_user                  => "alicia",
  :db_pass                  => "scissors7",
  :db_manager               => "alicia",
  :my_email                 => "alicia@cryst.bioc.cam.ac.uk",
  :gloria_email             => "gloria@cryst.bioc.cam.ac.uk",
  :schema_load_sql_file     => "DB_LOADER_SCHEMA.sql",
  :schema_load_mod_sql_file => "DB_LOADER_SCHEMA_MOD.sql",
  :schema_drop_sql_file     => "DB_LOADER_SCHEMA_DROP.sql",
  :data_load_sql_file       => "DB_LOADER_LOAD.sql",
  #:field_delimeter          => "'@\\t'",
  :field_delimeter          => "'\\t'",
  #:row_delimeter            => "'#\\n'",
  :row_delimeter            => "'\\n'",
  :temp_dir                 => Pathname.new("/BiO/Temp/MMCIF"),
}

$logger_formatter = Logger::Formatter.new

class Logger
  def format_message(severity, timestamp, progname, msg)
    $logger_formatter.call(severity, timestamp, progname, msg)
  end
end

$log_file     = STDOUT
$logger       = Logger.new($log_file)
$logger.level = Logger::INFO

def send_email(from       = $config[:my_email],
               from_alias = 'Alicia Higueruelo',
               to         = $config[:gloria_email],
               to_alias   = 'Gloria',
               subject    = "[Gloria] MMCIF on spunky updated",
               message    = "MMCIF database has been updated.")
  msg = <<END_OF_MESSAGE
From: #{from_alias} <#{from}>
To: #{to_alias} <#{to}>
Subject: #{subject}
  
#{message}
END_OF_MESSAGE

  Net::SMTP.start('localhost') do |smtp|
    smtp.send_message msg, from, to
  end
end


# Tasks

desc "Simply just build MMCIF database!"
task :default => [
  #"check:week",
  "prepare:temp_dir",
  "prepare:files",
  "create:list",
  "create:revised_schema_mapping",
  "create:updated_schema_mapping",
  "create:schema",
  "create:dumps",
  "drop:tables",
  "create:tables",
  "modify:load_sql",
  "import:dumps",
  "send:email"
]


namespace :check do

  desc "Check if this week is for MMCIF"
  task :week do
    if Date.today.cweek % 2 == 0
      $logger.debug "This week is not mine."
      puts "This week is not mine."
      exit
    else
      $logger.debug "This week is mine"
      puts "This week is mine."
    end
  end
end


namespace :prepare do

  desc "Prepare a scratch directory"
  task :temp_dir do

    dir = $config[:temp_dir]

    if File.exists? dir
      rm_rf dir
      $logger.info "Removing #{dir}: done"
    end

    mkdir_p dir

    $logger.info "Creating #{dir}: done"
  end


  desc "Uncompress and copy mmCIF files to working directory"
  task :files do

    zipped_files = Dir[$config[:mmcif_mirror_dir].join("*.gz").to_s]

    zipped_files.each_with_index do |zipped_file, i|
      unzipped_file = $config[:temp_dir].join(File.basename(zipped_file, ".gz"))
      system "gzip -cd #{zipped_file} > #{unzipped_file}"

      $logger.debug "Uncompressing '#{zipped_file}' to '#{unzipped_file}': done (#{i+1}/#{zipped_files.size})"
    end

    $logger.info "Uncompressing #{zipped_files.size} PDB mmCIF files to #{$config[:temp_dir]}: done"
  end

end


namespace :create do

  desc "Create a LIST file"
  task :list do

    File.open($config[:temp_dir].join("LIST"), 'w') do |file|
      file.puts Dir[$config[:temp_dir].join("*.cif").to_s].map { |f| File.basename(f) }
    end
    $logger.info "Creating a LIST file: done"
  end

  desc "Create a revised schema mapping file"
  task :revised_schema_mapping do

    cwd = pwd
    chdir $config[:temp_dir]

    system  "#{$config[:db_loader_bin]} " +
            "-map #{$config[:schema_map_file]} " +
            "-list LIST " +
            "-revise revised_schema_mapping.cif"

    $logger.info "Creating a revised schema mapping file: done"

    chdir cwd
  end

  desc "Create an updated schema mapping file"
  task :updated_schema_mapping do

    cwd = pwd
    chdir $config[:temp_dir]

    system  "#{$config[:db_loader_bin]} " +
            "-map #{$config[:schema_map_file]} " +
            "-update updated_schema_mapping.cif " +
            "-revise revised_schema_mapping.cif"

    $logger.info "Creating an updated schema mapping file: done"

    chdir cwd
  end

  desc "Create MMCIF RDB schema"
  task :schema do

    cwd = pwd
    chdir $config[:temp_dir]

    system  "#{$config[:db_loader_bin]} " +
            #"-map #{$config[:schema_map_file]} " +
            "-map updated_schema_mapping.cif " +
            "-server #{$config[:db_dbms]} " +
            "-db #{$config[:db_name]} " +
            "-schema"

    $logger.info "Creating MMCIF schema: done"
    chdir cwd
  end

  desc "Create MMCIF dump files"
  task :dumps do

    cwd = pwd
    chdir $config[:temp_dir]

    system  "#{$config[:db_loader_bin]} " +
            #"-map #{$config[:schema_map_file]} " +
            "-map updated_schema_mapping.cif " +
            "-server #{$config[:db_dbms]} " +
            "-db #{$config[:db_name]} " +
            "-ft #{$config[:field_delimeter]} " +
            "-rt #{$config[:row_delimeter]} " +
            "-bcp " +
            "-list LIST " +
            "-revise revised_schema_mapping.cif"

    $logger.info "Creating MMCIF dump files: done"

    chdir cwd
  end

  desc "Create MMCIF tables"
  task :tables do

    system  "mysql -f " +
            "-h #{$config[:db_host]} " +
            "-u #{$config[:db_user]} " +
            "-p#{$config[:db_pass]} " +
            "< #{$config[:temp_dir].join($config[:schema_load_sql_file])}"

    $logger.info "Creating MMCIF tables: done"
  end

end

namespace :drop do

  desc "Drop MMCIF tables"
  task :tables do

    system  "mysql -f " +
            "-h #{$config[:db_host]} " +
            "-u #{$config[:db_user]} " +
            "-p#{$config[:db_pass]} " +
            "< #{$config[:temp_dir].join($config[:schema_drop_sql_file])}"

    $logger.info "Dropping MMCIF tables: done"
  end

end


namespace :import do

  desc "Import MMCIF dump files to database"
  task :dumps do

    cwd = pwd
    chdir $config[:temp_dir]

    system  "mysql -f " +
            "-h #{$config[:db_host]} " +
            "-u #{$config[:db_user]} " +
            "-p#{$config[:db_pass]} " +
            "< #{$config[:data_load_sql_file]}"

    $logger.info "Importing mmCIF dump files to #{$config[:db_host]}.#{$config[:db_name]}: done"
    chdir cwd
  end
end


namespace :modify do

  desc "Modify DB_LOADER_LOAD.sql"
  task :load_sql do
    sql_file      = $config[:temp_dir].join($config[:data_load_sql_file])
    load_sql      = IO.readlines(sql_file)
    atom_site_sql = load_sql.slice!(3..6)

    load_sql << atom_site_sql

    File.open(sql_file, 'w') do |f|
      f.puts load_sql.join
    end
  end
end


namespace :send do

  desc "Send log to Gloria team"
  task :email do

    send_email

  end
end
