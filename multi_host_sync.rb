#!/usr/bin/ruby

require 'optparse'
require 'pp'
require 'yaml'
require 'socket'

class MultiHostSync

  attr_accessor :options
  attr_accessor :configuration
  attr_accessor :targets

  def self.symbolize_keys( hash )
    hash.inject({}) do |result, (key, value)|
      new_key   = case key
                  when String then key.to_sym
                  else key
                  end
      new_value = case value
                  when Hash then symbolize_keys(value)
                  else value
                  end
      result[new_key] = new_value
      result
    end
  end

  def self.get_options( args = {} )
    options = {}

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: multi_host_sync.rb [options]"
      
      opts.separator ''

      opts.separator 'Specific options:'

      opts.on( '-n', '--dry-run',
               'show what would have been transferred' ) do |dry|
        options[:dry_run] = true
      end

      opts.on( '--exclude=[PATTERN]',
               'exclude files matching PATTERN' ) do |excl|
        options[ :exclude_pattern ] << excl
      end

      opts.on( '--progress', 'show progress during transfer' ) do |prg|
        options[:progress] = prg
      end

      opts.on( '-r', '--recursive', 'recurse into directories' ) do |rec|
        options[:recursive] = rec
      end

      opts.on( '-e', '--rsh=COMMAND',
               'specify the remote shell to use' ) do |rsh|
        options[:rsh] = rsh
      end

      opts.on( '-u', '--update',
               'skip files that are newer on the receiver' ) do |upd|
        options[:update_files] = upd
      end

      opts.on( '-v', '--verbose', 'increase verbosity' ) do |vrb|
        options[:verbose] = vrb
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
    opts.parse!( args ) unless args.empty?
    options
  end

  def initialize( configuration_file = nil )
    @configuration_file = configuration_file
    pp options
  end

  def sync
    puts sync_command configuration['targets']
    #IO.popen( "#{sync_command(configuration['targets'])}" ) { |f| puts f.gets }
  end

  def default_options
    MultiHostSync.get_options
  end

  def configuration
    configuration = configuration_from_file.dup
    configuration[:options] = default_options
    configuration[:options].merge!(
      configuration_from_file[:options]
    ).merge(
      MultiHostSync.get_options( ARGV )
    )
    configuration[:options];
  end

  def files
    configuration[:files]
  end

  def hosts
    configuration[:hosts]
  end

  def remote_hosts_and_local_directory
    current_host = Socket.gethostname
    remote_hosts = hosts.dup
    remote_hosts.each_pair do |key, value|
      if ( value[:domain] == current_host )
        local_directory = value[:directory]
        remote_hosts.delete( key )
        break
      end
    end
    [ remote_hosts, local_directory ]
  end

  def remote_hosts
    remote_hosts_and_local_directory[0]
  end

  def local_directory
    remote_hosts_and_local_directory[1]
  end

  def options
    configuration[:options]
  end

  def configuration_from_file
     MultiHostSync.symbolize_keys( YAML.load_file( @configuration_file ) )
  end

  def options_list
    options.map { |key, value|
      "--#{key.to_s}" + (value ? "=#{value}" : '') }.join(' ')
  end

  def source_file
    File.new( configuration['source_path'] )
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
