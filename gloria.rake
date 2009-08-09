require "rubygems"
require "open3"
require "logger"
require "fork_manager"
require "active_support"
require "net/smtp"

include FileUtils

RakeFileUtils.verbose(false)

# global configurations
RESUME          = (ENV["RESUME"].blank? or
                   ENV["RESUME"] =~ /true/i or
                   ENV["RESUME"].to_i == 1) ? true : false
MY_EMAIL        = ENV[:MY_EMAIL]
GLORIA_EMAIL    = ENV[:GLORIA_EMAIL]
CLEAN_BIN       = Pathname.new("/BiO/Install/hbplus/clean")
HBPLUS_BIN      = Pathname.new("/BiO/Install/hbplus/hbplus")
HBADD_BIN       = Pathname.new("/BiO/Install/hbadd/hbadd")
NACCESS_PATH    = Pathname.new("/BiO/Install/naccess")
NACCESS_BIN     = NACCESS_PATH.join("naccess")
JOY_BIN         = Pathname.new("/BiO/Install/joy/joy")
ZIPPED_PDB_DIR  = Pathname.new("/BiO/Mirror/PDB/data/structures/all/pdb")
HET_DICT_FILE   = Pathname.new("/BiO/Mirror/PDB/data/monomers/het_dictionary.txt")
TEMP_DIR        = Pathname.new("/BiO/Temp")
UNCLEAN_DIR     = Pathname.new("/BiO/Store/PDB/UNCLEAN")
CLEAN_DIR       = Pathname.new("/BiO/Store/PDB/CLEAN")
DOMAIN_DIR      = CLEAN_DIR.join("DOMAIN")
PDB_DIR         = CLEAN_DIR.join("PDB")
PDBCHAIN_DIR    = CLEAN_DIR.join("PDBCHAIN")
PDBLIG_DIR      = CLEAN_DIR.join("PDBLIG")
PDBNUC_DIR      = CLEAN_DIR.join("PDBNUC")
PICPDBCHAIN_DIR = CLEAN_DIR.join("PICPDBCHAIN")
QUAT_DIR        = CLEAN_DIR.join("QUAT")
QUATPAIR_DIR    = CLEAN_DIR.join("QUATPAIR")

# logger
$logger_formatter = Logger::Formatter.new

class Logger
  def format_message(severity, timestamp, progname, msg)
    $logger_formatter.call(severity, timestamp, progname, msg)
  end
end

$log_file     = STDOUT
$logger       = Logger.new($log_file)
$logger.level = Logger::INFO

# helper methods
def refresh_dir(dir)
  rm_rf(dir) if File.exists?(dir)
  mkdir_p(dir)
  $logger.info("RECREATE #{dir}: done")
end

def send_email(subject,
               message,
               options = {})

  opts = {  :from => MY_EMAIL,
            :from_alias => 'Semin Lee',
            :to => GLORIA_EMAIL,
            :to_alias => 'Gloria' }.merge(options)

  msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: #{opts[:to_alias]} <#{opts[:to]}>
Subject: #{subject}
  
#{message}
END_OF_MESSAGE

  Net::SMTP.start('localhost') do |smtp|
    smtp.send_message msg, opts[:from], opts[:to]
  end
end

def run_naccess(dir)
  dir       = Pathname.new(dir)
  str_dir   = dir.join("Structures")
  nac_dir   = dir.join("NACCESS")
  pdb_files = Dir[str_dir.join("*.pdb").to_s].sort

  refresh_dir(nac_dir) unless RESUME

  skipped_pdbs  = []
  tried_pdbs    = []
  failed_pdbs   = []

  pdb_files.each_with_index do |pdb_file, i|
    stem = File.basename(pdb_file, ".pdb")

    if (File.size?(File.join(nac_dir, "#{stem}.asa")) &&
        File.size?(File.join(nac_dir, "#{stem}.rsa")))
      skipped_pdbs << stem
      $logger.info "Skipped #{pdb_file}"
      next
    end

    tried_pdbs << stem

    # preprocesses
    cwd = pwd
    work_dir = nac_dir.join(stem)
    mkdir_p work_dir
    chdir work_dir
    cp pdb_file, "."
    pdb_file = stem + ".pdb"

    # run NACCESS
    pdb_code      = stem.match(/^(\S{4})/)[1]
    new_pdb_file  = stem + ".new"
    naccess_input = File.exists?(new_pdb_file) ? new_pdb_file : pdb_file
    naccess_cmd   = "#{NACCESS_BIN} #{naccess_input} -p 1.40 -r #{NACCESS_PATH}/vdw.radii -s #{NACCESS_PATH}/standard.data -z 0.05"

    File.open(stem + ".naccess.log", "w") do |log|
      IO.popen(naccess_cmd, "r") do |pipe|
        log.puts pipe.readlines
      end
    end

    if pdb_code != stem
      mv(pdb_code + ".asa", stem + ".asa") if File.exists?(pdb_code + ".asa")
      mv(pdb_code + ".rsa", stem + ".rsa") if File.exists?(pdb_code + ".rsa")
      mv(pdb_code + ".log", stem + ".log") if File.exists?(pdb_code + ".log")
    end

    rm pdb_file
    move Dir["*"], nac_dir
    rm_rf work_dir
    chdir cwd

    if (File.size?(File.join(nac_dir, "#{stem}.asa")) &&
        File.size?(File.join(nac_dir, "#{stem}.rsa")))
      $logger.info "NACCESS #{naccess_input}: done (#{i+1}/#{pdb_files.size})"
    else
      failed_pdbs << stem
      $logger.warn "NACCESS #{naccess_input}: failed (#{i+1}/#{pdb_files.size})"
    end
  end


  msg = "* No. of total structures: #{pdb_files.size}"
  msg += "\n* No. of skipped structures: #{skipped_pdbs.size}"
  msg += "\n* No. of tried structures: #{tried_pdbs.size}"
  msg += " (see a list of files below)" if tried_pdbs.size > 0
  msg += "\n* No. of failed structures: #{failed_pdbs.size}"
  msg += " (see a list of files below)" if failed_pdbs.size > 0
  msg += "\n\n(You can find more detailed log messages in /BiO/Temp/gloria.log)"

  if failed_pdbs.size > 0
    msg += "\n\n* List of NACCESS failed structures:\n"
    msg += failed_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end

  send_email("[Gloria] NACCESS with #{str_dir}", msg)
end

def run_hbplus(dir, hbadd = false)
  dir       = Pathname.new(dir)
  str_dir   = dir.join("Structures")
  hbp_dir   = dir.join("HBPLUS")
  pdb_files = Dir[str_dir.join("*.pdb").to_s].sort

  refresh_dir(hbp_dir) unless RESUME

  skipped_pdbs  = []
  tried_pdbs    = []
  failed_pdbs   = []

  pdb_files.each_with_index do |pdb_file, i|
    stem = File.basename(pdb_file, ".pdb")

    if File.size?(File.join(hbp_dir, "#{stem}.hb2"))
      skipped_pdbs << stem
      $logger.info "Skipped #{pdb_file}"
      next
    end

    tried_pdbs << stem

    # preprocesses
    cwd = pwd
    work_dir = hbp_dir.join(stem)
    mkdir_p work_dir
    chdir work_dir
    cp pdb_file, "."
    pdb_file = stem + ".pdb"

    # run NACCESS
    pdb_code      = stem.match(/^(\S{4})/)[1]
    new_pdb_file  = stem + ".new"
    naccess_input = File.exists?(new_pdb_file) ? new_pdb_file : pdb_file
    naccess_cmd   = "#{NACCESS_BIN} #{naccess_input} -p 1.40 -r #{NACCESS_PATH}/vdw.radii -s #{NACCESS_PATH}/standard.data -z 0.05"

    File.open(stem + ".naccess.log", "w") do |log|
      IO.popen(naccess_cmd, "r") do |pipe|
        log.puts pipe.readlines
      end
    end

    if pdb_code != stem
      mv(pdb_code + ".asa", stem + ".asa") if File.exists?(pdb_code + ".asa")
      mv(pdb_code + ".rsa", stem + ".rsa") if File.exists?(pdb_code + ".rsa")
      mv(pdb_code + ".log", stem + ".log") if File.exists?(pdb_code + ".log")
    end

    # HBADD
    if hbadd
      if File.exists? new_pdb_file
        hbadd_cmd = "#{HBADD_BIN} #{new_pdb_file} #{HET_DICT_FILE}"
      else
        hbadd_cmd = "#{HBADD_BIN} #{pdb_file} #{HET_DICT_FILE}"
      end

      File.open(pdb_code + ".hbadd.log", "w") do |log|
        IO.popen(hbadd_cmd, "r") do |pipe|
          log.puts pipe.readlines
        end
      end
    end

    # HBPLUS
    if File.exists? new_pdb_file
      hbplus_cmd = "#{HBPLUS_BIN} -x -R -q #{new_pdb_file} #{pdb_file}"
    else
      hbplus_cmd = "#{HBPLUS_BIN} -x -R -q #{pdb_file}"
    end

    if File.exists? "hbplus.rc"
      mv("hbplus.rc", "#{pdb_code}.rc")
      hbplus_cmd += " -f #{pdb_code}.rc"
    end

    File.open(stem + ".hbplus.log", "w") do |log|
      IO.popen(hbplus_cmd, "r") do |pipe|
        log.puts pipe.readlines
      end
    end

    rm pdb_file
    move Dir["*"], hbp_dir
    rm_rf work_dir
    chdir cwd

    if File.size?(hbp_dir.join("#{stem}.hb2"))
      $logger.info "HBPLUS with #{pdb_file}: done (#{i+1}/#{pdb_files.size})"
    else
      failed_pdbs << stem
      $logger.warn "HBPLUS with #{pdb_file}: failed (#{i+1}/#{pdb_files.size})"
    end
  end


  msg = "* No. of total structures: #{pdb_files.size}"
  msg += "\n* No. of skipped structures: #{skipped_pdbs.size}"
  msg += "\n* No. of tried structures: #{tried_pdbs.size}"
  msg += " (see a list of files below)" if tried_pdbs.size > 0
  msg += "\n* No. of failed structures: #{failed_pdbs.size}"
  msg += " (see a list of files below)" if failed_pdbs.size > 0
  msg += "\n\n(You can find more detailed log messages in /BiO/Temp/gloria.log)"

  if failed_pdbs.size > 0
    msg += "\n\n* List of HBPLUS failed structures:\n"
    msg += failed_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end

  send_email("[Gloria] HBPLUS with #{str_dir}", msg)
end

def run_joy(dir)
  dir       = Pathname.new(dir)
  str_dir   = dir.join("Structures")
  joy_dir   = dir.join("JOY")
  pdb_files = Dir[str_dir.join("*.pdb").to_s].sort

  refresh_dir(joy_dir) unless RESUME

  cwd = pwd
  chdir joy_dir

  skipped_pdbs  = []
  tried_pdbs    = []
  failed_pdbs   = []

  pdb_files.each_with_index do |pdb_file, i|
    stem = File.basename(pdb_file, '.pdb')

    if File.size? "#{stem}.tem"
      skipped_pdbs << pdb_file
      $logger.info "Skipped #{pdb_file}"
      next
    end

    tried_pdbs << pdb_file

    cp pdb_file, '.'
    system "#{JOY_BIN} #{stem}.pdb 1> #{stem}.joy.log 2>&1"
    rm "#{stem}.pdb"

    if File.size? "#{stem}.tem"
      $logger.info "JOY #{pdb_file}: done (#{i+1}/#{pdb_files.size})"
    else
      skipped_pdbs << pdb_file
      $logger.warn "JOY #{pdb_file}: failed (#{i+1}/#{pdb_files.size})"
    end
  end

  chdir cwd

  msg = "* No. of total structures: #{pdb_files.size}"
  msg += "\n* No. of skipped structures: #{skipped_pdbs.size}"
  msg += "\n* No. of tried structures: #{tried_pdbs.size}"
  msg += " (see a list of files below)" if tried_pdbs.size > 0
  msg += "\n* No. of failed structures: #{failed_pdbs.size}"
  msg += " (see a list of files below)" if failed_pdbs.size > 0
  msg += "\n\n(You can find more detailed log messages in /BiO/Temp/gloria.log)"

  if tried_pdbs.size > 0
    msg += "\n\n* List of JOY tried structures:\n"
    #msg += tried_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end
  if failed_pdbs.size > 0
    msg += "\n\n* List of JOY failed structures:\n"
    msg += failed_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end

  send_email("[Gloria] JOY with #{str_dir}", msg)
end

namespace :do do
  desc "Run chores various flavors of CLEAN PDB Structures"
  task :jobs => [
  "joy:pdb",
  "joy:pdbchain",
  "joy:picpdbchain",
  "joy:quat",
  "joy:domain",
  "hbplus:pdb",
  "hbplus:pdbchain",
  "hbplus:picpdbchain",
  "hbplus:quat",
  "hbplus:pdbnuc",
  "naccess:quatpair"
  ]
end

# tasks
namespace :joy do

  desc "JOY with clean PDB files"
  task :pdb do
    run_joy(PDB_DIR)
  end

  desc "JOY with clean PDBCHAIN files"
  task :pdbchain do
    run_joy(PDBCHAIN_DIR)
  end

  desc "JOY with clean PICPDBCHAIN files"
  task :picpdbchain do
    run_joy(PICPDBCHAIN_DIR)
  end

  desc "JOY with clean DOMAIN files"
  task :domain do
    run_joy(DOMAIN_DIR)
  end

  desc "JOY with clean QUAT files"
  task :quat do
    run_joy(QUAT_DIR)
  end

end

namespace :hbplus do

  desc "HBPLUS with clean PDB files"
  task :pdb do
    run_hbplus(PDB_DIR)
  end

  desc "HBPLUS with clean PDBCHAIN files"
  task :pdbchain do
    run_hbplus(PDBCHAIN_DIR)
  end

  desc "HBPLUS with clean PICPDBCHAIN files"
  task :picpdbchain do
    run_hbplus(PICPDBCHAIN_DIR)
  end

  desc "HBPLUS with clean PDBLIG files"
  task :pdblig do
    run_hbplus(PDBLIG_DIR, true)
  end

  desc "HBPLUS with clean DOMAIN files"
  task :domain do
    run_hbplus(DOMAIN_DIR)
  end

  desc "HBPLUS with clean QUAT files"
  task :quat do
    run_hbplus(QUAT_DIR)
  end

  desc "HBPLUS with clean PDBNUC files"
  task :pdbnuc do
    run_hbplus(PDBNUC_DIR)
  end

end

namespace :naccess do

  desc "NACCESS wich clean QUATPAIR files"
  task :quatpair do
    run_naccess(QUATPAIR_DIR)
  end

end

namespace :unzip do

  desc "Unzip original PDB files"
  task :pdb do
    str_dir = File.join(UNCLEAN_DIR, "Structures")
    refresh_dir(str_dir)

    zipped_pdb_files = FileList[File.join(ZIPPED_PDB_DIR, "*.ent.gz")].sort

    fm = ForkManager.new(MAX_FORK)
    fm.manage do
      zipped_pdb_files.each_with_index do |zipped_pdb_file, i|
        fm.fork do
          unzipped_pdb_file = File.join(str_dir, File.basename(zipped_pdb_file, '.ent.gz').sub(/pdb/, '') + '.pdb')
          system "gzip -cd #{zipped_pdb_file} 1> #{unzipped_pdb_file}"
        end
      end
    end

    ent_file = "/BiO/Mirror/PDB/derived_data/pdb_entry_type.txt"

    no_prot = `cut -f 2 #{ent_file} | grep -c -E "^prot$"`.chomp.to_i
    no_nuc  = `cut -f 2 #{ent_file} | grep -c -E "^nuc$"`.chomp.to_i
    no_pnuc = `cut -f 2 #{ent_file} | grep -c -E "^prot-nuc$"`.chomp.to_i
    no_carb = `cut -f 2 #{ent_file} | grep -c -E "^carb$"`.chomp.to_i

    msg = "Total #{zipped_pdb_files.size} PDB files have been uncompressed.\n"
    msg += "\nNo. of protein only structures: #{no_prot}"
    msg += "\nNo. of nucleic acid only structures: #{no_nuc}"
    msg += "\nNo. of protein-nucleic acid complex structures: #{no_pnuc}"
    msg += "\nNo. of carbohydrate only structures: #{no_carb}"

    send_email("[Gloria] PDB mirror update", msg,
               :to => "gloria@cryst.bioc.cam.ac.uk",
               :to_alias => "Gloria")
  end

end
