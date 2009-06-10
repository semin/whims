require "rubygems"
require "open3"
require "logger"
require "fileutils"
require "fork_manager"
require "active_support"

include FileUtils

# global configurations
RESUME          = (ENV["RESUME"].blank? || ENV["RESUME"] =~ /true/) ? true : false
MAX_FORK        = ENV["MAX_FORK"].blank? ? 1 : ENV["MAX_FORK"].to_i
CLEAN_BIN       = "/BiO/Install/hbplus/clean"
HBPLUS_BIN      = "/BiO/Install/hbplus/hbplus"
HBADD_BIN       = "/BiO/Install/hbadd/hbadd"
NACCESS_PATH    = "/BiO/Install/naccess"
NACCESS_BIN     = File.join(NACCESS_PATH, "naccess")
JOY_BIN         = "/BiO/Install/joy/joy"
ZIPPED_PDB_DIR  = "/BiO/Mirror/PDB/data/structures/all/pdb"
HET_DICT_FILE   = "/BiO/Mirror/PDB/data/monomers/het_dictionary.txt"
TEMP_DIR        = "/BiO/Temp"
UNCLEAN_DIR     = "/BiO/Store/PDB/UNCLEAN"
CLEAN_DIR       = "/BiO/Store/PDB/CLEAN"
DOMAIN_DIR      = File.join(CLEAN_DIR, "DOMAIN")
PDB_DIR         = File.join(CLEAN_DIR, "PDB")
PDBCHAIN_DIR    = File.join(CLEAN_DIR, "PDBCHAIN")
PDBLIG_DIR      = File.join(CLEAN_DIR, "PDBLIG")
PDBNUC_DIR      = File.join(CLEAN_DIR, "PDBNUC")
PICPDBCHAIN_DIR = File.join(CLEAN_DIR, "PICPDBCHAIN")
QUAT_DIR        = File.join(CLEAN_DIR, "QUAT")
QUATPAIR_DIR    = File.join(CLEAN_DIR, "QUATPAIR")

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

def send_mail(opts={})
  opts = {
    :to           => "semin@cryst.bioc.cam.ac.uk",
    :from         => "semin@cryst.bioc.cam.ac.uk",
    :subject      => "[Gloria] HBPLUS and JOY on spunky",
    :message      => "Please find attached log files",
    :attachement  => nil
  }.merge(opts)

  cmd =  %Q"mail -s '#{opts[:subject]}'"
  cmd += %Q" -a #{opts[:attachement]}" if opts[:attachement]
  cmd += %Q" -r #{opts[:from]}"
  cmd += %Q" #{opts[:to]}"
  cmd += %Q" <<EOT\n"
  cmd += %Q"#{opts[:message]}\n"
  cmd += %Q"EOT\n"

  sh cmd
end

def run_naccess(ori_dir)
  str_dir   = File.join(ori_dir, "Structures")
  nac_dir   = File.join(ori_dir, "NACCESS")
  pdb_files = Dir[File.join(str_dir, "*.pdb")].sort

  refresh_dir(nac_dir) unless RESUME

  skipped_pdbs  = []
  tried_pdbs    = []
  failed_pdbs   = []

  fmanager = ForkManager.new(MAX_FORK)
  fmanager.manage do

    pdb_files.each_with_index do |pdb_file, i|
      pdb_stem = File.basename(pdb_file, ".pdb")

      if (File.size?(File.join(nac_dir, "#{pdb_stem}.asa")) &&
          File.size?(File.join(nac_dir, "#{pdb_stem}.rsa")))
        skipped_pdbs << pdb_stem
        $logger.info("SKIP #{pdb_file}: done (#{i+1}/#{pdb_files.size})")
        next
      end

      tried_pdbs << pdb_stem

      fmanager.fork do
        # preprocesses
        cwd = pwd
        work_dir = File.join(nac_dir, pdb_stem)
        mkdir_p(work_dir)
        chdir(work_dir)
        cp(pdb_file, ".")
        pdb_file = pdb_stem + ".pdb"

        # CLEAN
#        File.open(pdb_stem + ".clean.log", "w") do |log|
#          IO.popen(CLEAN_BIN, "r+") do |pipe|
#            pipe.puts pdb_file
#            log.puts pipe.readlines
#          end
#        end

        $logger.info("CLEAN #{pdb_file}: done (#{i+1}/#{pdb_files.size})")

        # NACCESS
        pdb_code      = pdb_stem.match(/(\S{4})/)[1]
        new_pdb_file  = pdb_stem + ".new"
        naccess_input = File.exists?(new_pdb_file) ? new_pdb_file : pdb_file
        naccess_cmd   = "#{NACCESS_BIN} #{naccess_input} -p 1.40 -r #{NACCESS_PATH}/vdw.radii -s #{NACCESS_PATH}/standard.data -z 0.05"

        File.open(pdb_stem + ".naccess.log", "w") do |log|
          IO.popen(naccess_cmd, "r") do |pipe|
            log.puts pipe.readlines
          end
        end

        if pdb_code != pdb_stem
          mv(pdb_code + ".asa", pdb_stem + ".asa") if File.exists?(pdb_code + ".asa")
          mv(pdb_code + ".rsa", pdb_stem + ".rsa") if File.exists?(pdb_code + ".rsa")
          mv(pdb_code + ".log", pdb_stem + ".log") if File.exists?(pdb_code + ".log")
        end

        rm(pdb_file)
        move(Dir["*"], nac_dir)
        rm_rf(work_dir)
        chdir(cwd)
      end

      if (File.size?(File.join(nac_dir, "#{pdb_stem}.asa")) &&
          File.size?(File.join(nac_dir, "#{pdb_stem}.rsa")))
        $logger.info("NACCESS #{naccess_input}: done (#{i+1}/#{pdb_files.size})")
      else
        failed_pdbs << pdb_stem
        $logger.warn("NACCESS #{naccess_input}: failed (#{i+1}/#{pdb_files.size})")
      end
    end
  end

  msg = "* No. of total structures: #{pdb_files.size}"
  msg += "\n* No. of skipped structures: #{skipped_pdbs.size}"
  msg += "\n* No. of tried structures: #{tried_pdbs.size}"
  msg += " (see a list of files below)" if tried_pdbs.size > 0
  msg += "\n* No. of failed structures: #{failed_pdbs.size}"
  msg += " (see a list of files below)" if failed_pdbs.size > 0
  msg += "\n\n(You can find more detailed log messages in /BiO/Temp/gloria.log)"

  if tried_pdbs.size > 0
    msg += "\n\n* List of NACCESS tried structures:\n"
    msg += tried_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end
  if failed_pdbs.size > 0
    msg += "\n\n* List of NACCESS failed structures:\n"
    msg += failed_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end

  send_mail(:subject => "[Gloria] NACCESS with #{str_dir}", :message => msg)
end

def run_hbplus(ori_dir, hbadd = false)
  str_dir   = File.join(ori_dir, "Structures")
  hbp_dir   = File.join(ori_dir, "HBPLUS")
  pdb_files = Dir[File.join(str_dir, "*.pdb")].sort

  refresh_dir(hbp_dir) unless RESUME

  skipped_pdbs  = []
  tried_pdbs    = []
  failed_pdbs   = []

  fmanager = ForkManager.new(MAX_FORK)
  fmanager.manage do

    pdb_files.each_with_index do |pdb_file, i|
      pdb_stem = File.basename(pdb_file, ".pdb")

      if File.size?(File.join(hbp_dir, "#{pdb_stem}.hb2"))
        skipped_pdbs << pdb_stem
        $logger.info("SKIP #{pdb_file}: done (#{i+1}/#{pdb_files.size})")
        next
      end

      tried_pdbs << pdb_stem

      fmanager.fork do
        # preprocesses
        cwd = pwd
        work_dir = File.join(hbp_dir, pdb_stem)
        mkdir_p(work_dir)
        chdir(work_dir)
        cp(pdb_file, ".")
        pdb_file = pdb_stem + ".pdb"

        # CLEAN
#        File.open(pdb_stem + ".clean.log", "w") do |log|
#          IO.popen(CLEAN_BIN, "r+") do |pipe|
#            pipe.puts pdb_file
#            log.puts pipe.readlines
#          end
#        end
#
#        $logger.info("CLEAN #{pdb_file}: done (#{i+1}/#{pdb_files.size})")

        # NACCESS
        pdb_code      = pdb_stem.match(/(\S{4})/)[1]
        new_pdb_file  = pdb_stem + ".new"
        naccess_input = File.exists?(new_pdb_file) ? new_pdb_file : pdb_file
        naccess_cmd   = "#{NACCESS_BIN} #{naccess_input} -p 1.40 -r #{NACCESS_PATH}/vdw.radii -s #{NACCESS_PATH}/standard.data -z 0.05"

        File.open(pdb_stem + ".naccess.log", "w") do |log|
          IO.popen(naccess_cmd, "r") do |pipe|
            log.puts pipe.readlines
          end
        end

        if pdb_code != pdb_stem
          mv(pdb_code + ".asa", pdb_stem + ".asa") if File.exists?(pdb_code + ".asa")
          mv(pdb_code + ".rsa", pdb_stem + ".rsa") if File.exists?(pdb_code + ".rsa")
          mv(pdb_code + ".log", pdb_stem + ".log") if File.exists?(pdb_code + ".log")
        end

        $logger.info("NACCESS #{naccess_input}: done (#{i+1}/#{pdb_files.size})")

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

        File.open(pdb_stem + ".hbplus.log", "w") do |log|
          IO.popen(hbplus_cmd, "r") do |pipe|
            log.puts pipe.readlines
          end
        end

        rm(pdb_file)
        move(Dir["*"], hbp_dir)
        rm_rf(work_dir)
        chdir(cwd)
      end

      # post processes
      if File.size?(File.join(hbp_dir, "#{pdb_stem}.hb2"))
        $logger.info("HBPLUS #{pdb_file}: done (#{i+1}/#{pdb_files.size})")
      else
        failed_pdbs << pdb_stem
        $logger.warn("HBPLUS #{pdb_file}: failed (#{i+1}/#{pdb_files.size})")
      end
    end
  end

  msg = "* No. of total structures: #{pdb_files.size}"
  msg += "\n* No. of skipped structures: #{skipped_pdbs.size}"
  msg += "\n* No. of tried structures: #{tried_pdbs.size}"
  msg += " (see a list of files below)" if tried_pdbs.size > 0
  msg += "\n* No. of failed structures: #{failed_pdbs.size}"
  msg += " (see a list of files below)" if failed_pdbs.size > 0
  msg += "\n\n(You can find more detailed log messages in /BiO/Temp/gloria.log)"

  if tried_pdbs.size > 0
    msg += "\n\n* List of HBPLUS tried structures:\n"
    msg += tried_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end
  if failed_pdbs.size > 0
    msg += "\n\n* List of HBPLUS failed structures:\n"
    msg += failed_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end

  send_mail(:subject => "[Gloria] HBPLUS with #{str_dir}", :message => msg)
end

def run_joy(ori_dir)
  str_dir   = File.join(ori_dir, "Structures")
  joy_dir   = File.join(ori_dir, "JOY")
  pdb_files = Dir[File.join(str_dir, "*.pdb")].sort

  refresh_dir(joy_dir) unless RESUME

  cwd = pwd
  chdir(joy_dir)

  skipped_pdbs  = []
  tried_pdbs    = []
  failed_pdbs   = []

  fmanager = ForkManager.new(MAX_FORK)
  fmanager.manage do

    pdb_files.each_with_index do |pdb_file, i|
      pdb_stem = File.basename(pdb_file, '.pdb')

      if File.size? "#{pdb_stem}.tem"
        skipped_pdbs << pdb_stem
        $logger.info("SKIP #{pdb_file}: done (#{i+1}/#{pdb_files.size})")
        next
      end

      tried_pdbs << pdb_stem

      fmanager.fork do
        cp(pdb_file, '.')
        joy_cmd = "#{JOY_BIN} #{pdb_stem}.pdb"
        sh(joy_cmd + " 1> #{pdb_stem}.joy.log 2>&1")
        rm("#{pdb_stem}.pdb")
      end

      if File.size? "#{pdb_stem}.tem"
        $logger.info("JOY #{pdb_file}: done (#{i+1}/#{pdb_files.size})")
      else
        failed_pdbs << pdb_stem
        $logger.warn("JOY #{pdb_file}: failed (#{i+1}/#{pdb_files.size})")
      end
    end
  end
  chdir(cwd)

  msg = "* No. of total structures: #{pdb_files.size}"
  msg += "\n* No. of skipped structures: #{skipped_pdbs.size}"
  msg += "\n* No. of tried structures: #{tried_pdbs.size}"
  msg += " (see a list of files below)" if tried_pdbs.size > 0
  msg += "\n* No. of failed structures: #{failed_pdbs.size}"
  msg += " (see a list of files below)" if failed_pdbs.size > 0
  msg += "\n\n(You can find more detailed log messages in /BiO/Temp/gloria.log)"

  if tried_pdbs.size > 0
    msg += "\n\n* List of JOY tried structures:\n"
    msg += tried_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end
  if failed_pdbs.size > 0
    msg += "\n\n* List of JOY failed structures:\n"
    msg += failed_pdbs.each_with_index.map { |p, i| "#{i+1}: #{p}" }.join("\n")
  end

  send_mail(:subject => "[Gloria] JOY with #{str_dir}", :message => msg)
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

    zipped_pdb_files = Dir[File.join(ZIPPED_PDB_DIR, "*.ent.gz")].sort

    #fmanager = ForkManager.new(MAX_FORK)
    #fmanager.manage do
      zipped_pdb_files.each_with_index do |zipped_pdb_file, i|
        #fmanager.fork do
          unzipped_pdb_file = File.join(str_dir, File.basename(zipped_pdb_file, '.ent.gz').sub(/pdb/, '') + '.pdb')
          sh("gzip -cd #{zipped_pdb_file} 1> #{unzipped_pdb_file}")
        #end
      end
    #end

    ent_file = "/BiO/Mirror/PDB/derived_data/pdb_entry_type.txt"

    no_prot = `cut -f 2 #{ent_file} | grep -c -E "^prot$"`.chomp.to_i
    no_nuc  = `cut -f 2 #{ent_file} | grep -c -E "^nuc$"`.chomp.to_i
    no_pnuc = `cut -f 2 #{ent_file} | grep -c -E "^prot-nuc$"`.chomp.to_i
    no_carb = `cut -f 2 #{ent_file} | grep -c -E "^carb$"`.chomp.to_i

    message = "Total #{zipped_pdb_files.size} PDB files have been uncompressed\n"
    message += "\nNo. of protein only structures: #{no_prot}"
    message += "\nNo. of nucleic acid only structures: #{no_nuc}"
    message += "\nNo. of protein-nucleic acid complex structures: #{no_pnuc}"
    message += "\nNo. of carbohydrate only structures: #{no_carb}"

    send_mail(:to => "gloria@cryst.bioc.cam.ac.uk",
              :subject => "[Gloria] PDB mirror update",
              :message => message)
  end

end
