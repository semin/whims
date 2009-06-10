require "rubygems"
require "logger"
require "fileutils"
require "date"

include FileUtils

$config = {
  :mmcif_mirror_dir         => "/BiO/Mirror/PDB/data/structures/all/mmCIF",
  :schema_map_file          => "/BiO/Install/db-loader/db-loader-v4.0/test/schema_map_pdbx_na.cif",
  :db_loader_bin            => "/BiO/Install/db-loader/db-loader-v4.0/bin/db-loader",
  :db_host                  => ENV["DB_HOST"],
  :db_name                  => "MMCIF",
  :db_dbms                  => "mysql",
  :db_user                  => ENV["DB_USER"],
  :db_pass                  => ENV["DB_PASS"],
  :db_manager               => ENV["DB_USER"],
  :schema_load_sql_file     => "DB_LOADER_SCHEMA.sql",
  :schema_load_mod_sql_file => "DB_LOADER_SCHEMA_MOD.sql",
  :schema_drop_sql_file     => "DB_LOADER_SCHEMA_DROP.sql",
  :data_load_sql_file       => "DB_LOADER_LOAD.sql",
  :field_delimeter          => "'@\\t'",
  :row_delimeter            => "'#\\n'",
  :temp_dir                 => "/BiO/Temp/MMCIF",
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

desc "Simply just build MMCIF database!"
task :default => [
#  "check:week",
  "prepare:temp_dir",
  "prepare:files",
  "create:list",
  "create:schema",
  "create:dumps",
  "drop:tables",
  "create:tables",
#  "modify:load_sql",
  "import:dumps",
#  "send:log"
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

    zipped_files = Dir[$config[:mmcif_mirror_dir] + "/*.gz"]

    zipped_files.each_with_index do |zipped_file, i|
      unzipped_file = File.join($config[:temp_dir], File.basename(zipped_file, ".gz"))
      sh "gzip -cd #{zipped_file} > #{unzipped_file}"

      $logger.debug "Uncompressing '#{zipped_file}' to '#{unzipped_file}': done (#{i+1}/#{zipped_files.size})"
    end

    $logger.info "Uncompressing #{zipped_files.size} PDB mmCIF files to #{$config[:temp_dir]}: done"
  end

end


namespace :create do

  desc "Create a LIST file"
  task :list do

    File.open($config[:temp_dir] + "/LIST", 'w') do |file|
      file.puts Dir[File.join($config[:temp_dir], "*.cif")].map { |f| File.basename(f) }
    end
    $logger.info "Creating a LIST file: done"
  end


  desc "Create MMCIF RDB schema"
  task :schema do

    cwd = pwd
    chdir $config[:temp_dir]

    sh("#{$config[:db_loader_bin]} " +
       "-map #{$config[:schema_map_file]} " +
       "-server #{$config[:db_dbms]} " +
       "-db #{$config[:db_name]} " +
       "-schema")

    $logger.info "Creating MMCIF schema: done"
    chdir cwd
  end


  desc "Create MMCIF tables"
  task :tables do

    sh("mysql -f " +
       "-h #{$config[:db_host]} " +
       "-u #{$config[:db_user]} " +
       "-p#{$config[:db_pass]} " +
       "< #{File.join($config[:temp_dir], $config[:schema_load_sql_file])}")

    $logger.info "Creating MMCIF tables: done"
  end


  desc "Create MMCIF dump files"
  task :dumps do

    cwd = pwd
    chdir $config[:temp_dir]

    sh("#{$config[:db_loader_bin]} " +
       "-map #{$config[:schema_map_file]} " +
       "-server #{$config[:db_dbms]} " +
       "-db #{$config[:db_name]} " +
       "-ft #{$config[:field_delimeter]} " +
       "-rt #{$config[:row_delimeter]} " +
       "-bcp " +
       "-list LIST " +
       "-revise revised_schema_mapping.cif")

    $logger.info "Creating MMCIF dump files: done"

    chdir cwd
  end
end

namespace :drop do

  desc "Drop MMCIF tables"
  task :tables do

    sh("mysql -f " +
       "-h #{$config[:db_host]} " +
       "-u #{$config[:db_user]} " +
       "-p#{$config[:db_pass]} " +
       "< #{File.join($config[:temp_dir], $config[:schema_drop_sql_file])}")

    $logger.info "Dropping MMCIF tables: done"
  end

end


namespace :import do

  desc "Import MMCIF dump files to database"
  task :dumps do

    cwd = pwd
    chdir $config[:temp_dir]

    sh("mysql -f " +
       "-h #{$config[:db_host]} " +
       "-u #{$config[:db_user]} " +
       "-p#{$config[:db_pass]} " +
       "< #{$config[:data_load_sql_file]}")

    $logger.info "Importing mmCIF dump files to #{$config[:db_host]}.#{$config[:db_name]}: done"
    chdir cwd
  end
end


namespace :modify do

  desc "Modify DB_LOADER_LOAD.sql"
  task :load_sql do
    sql_file      = File.join($config[:temp_dir], $config[:data_load_sql_file])
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
  task :log do

    email_cmd =  %Q^mail -s "[Gloria] MMCIF database update"^
    email_cmd += %Q^ -a #{$log_file} ^ if File.size? $log_file
    email_cmd += %Q^ -r semin@cryst.bioc.cam.ac.uk^
    email_cmd += %Q^ gloria@cryst.bioc.cam.ac.uk^
    email_cmd += %Q^ <<EOT\n^
    email_cmd += %Q^MMCIF database has been updated.\n^
    email_cmd += %Q^EOT\n^

    sh email_cmd
  end

end