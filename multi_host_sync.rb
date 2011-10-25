#!/usr/bin/ruby

require 'optparse'
require 'ostruct'
require 'yaml'

class MultiHostSync

  attr_accessor :options
  attr_accessor :configuration
  attr_accessor :targets

  def self.get_options(args)
    options = OpenStruct.new
    options.compress = true
    options.dry_run = false
    options.exclude_pattern = []
    options.progress = true
    options.recursive = true
    options.rsh = '"ssh -p22"'
    options.update_files = true
    options.verbose = false

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: multi_host_sync.rb [options]"
      
      opts.separator ''

      opts.separator 'Specific options:'

      opts.on( '-z', '--compress',
               'compress file data during the transfer' ) do |comp|
      opts.on( '-n', '--dry-run',
               'show what would have been transferred' ) do |dry|
        options.dry_run = true
      end

      opts.on( '--exclude=[PATTERN]',
               'exclude files matching PATTERN' ) do |excl|
        options.exclude_pattern << excl
      end

      opts.on( '--progress', 'show progress during transfer' ) do |prg|
        options.prg = prg
      end

      opts.on( '-r', '--recursive', 'recurse into directories' ) do |rec|
        options.rec = rec
      end

      opts.on( '-e', '--rsh=COMMAND',
               'specify the remote shell to use' ) do |rsh|
        options.rsh = rsh
      end

      opts.on( '-u', '--update',
               'skip files that are newer on the receiver' ) do |updt|
        options.update_files = updt
      end

      opts.on( '-v', '--verbose', 'increase verbosity' ) do |vrb|
        options.verbose = vrb
      end

      opts.separator ''
      opts.separator 'Common options:'

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      # Another typical switch to print the version.
      opts.on_tail("--version", "Show version") do
        puts OptionParser::Version.join('.')
        exit
      end
    end
  end

  def initialize( configuration_file = nil )
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: example.rb [options]"

      opts.on("-v", "--[no-]verbose", "Run verbosely") do
        options[:verbose] = v
      end
    end.parse!

    p options
    p ARGV

    @configuration = configuration_from_file( configuration_file )
    # TODO: allow overriding configuration via command line arguments
    options = {}
    $*.each do |arg|
      pair = arg.split('=')
      options.merge!( pair[0].sub('--', '').to_sym => pair[1] )
    end
    @options = default_options.merge( options )
  end

  def sync
    puts sync_command @configuration['targets']
    #IO.popen( "#{sync_command(@configuration['targets'])}" ) { |f| puts f.gets }
  end

  def default_options
    {
      'update' => nil,
      'recursive' => nil,
      'compress' => nil,
      'verbose' => nil,
      'progress' => nil,
      'rsh' => '"ssh -p22"'
      #'dry-run' => nil
    }
  end


  private

  def configuration_from_file( file )
    YAML.load_file file
  end

  def options_list
    @options.map { |key, value|
      "--#{key.to_s}" + (value ? "=#{value}" : '') }.join(' ')
  end

  def source_file
    File.new( @configuration['source_path'] )
  end

  def source_path
    source_file.path
  end

  def base_name
    File.basename( source_path ) 
  end

  def source_directory
    Dir.new( File.dirname( source_path ) )
  end

  def source_directory_path
    source_directory.path
  end

  def target_directory( target )
    "#{target['user']}@#{target['host']}:#{target['directory']}"
  end

  def target_path( target )
    target_directory( target ) + '/' + base_name
  end

  def put_command( target )
    "rsync #{options_list} #{source_path} #{target_directory(target)}"
  end

  def get_command( target )
    "rsync #{options_list} #{target_path(target)} #{source_directory_path}"
  end

  def sync_command( targets )
    commands = []
    # TODO: change to :put, :get, :put to sync files once this is tested
    #[ :put, :get, :put ].each do |type|
    [ :put ].each do |type|
      targets.each_pair do |key, target|
        commands << send( "#{type}_command", target )
      end
    end
    commands.join("; \\\n")
  end
end
