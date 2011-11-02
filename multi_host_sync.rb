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

  def self.host_reachable?( host, port )
    puts "Verifying connectivity to #{host} on port #{port}"
    begin
      TCPSocket.open( host, port )
    rescue
      return false
    end
    true
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

      opts.on( '--exclude=PATTERN',
               'exclude files matching PATTERN' ) do |excl|
        options[ :exclude_pattern ] << excl
      end

      opts.on( '--hostname=NAME',
               'specify the hostname of the source machine' ) do |hst|
        options[:hostname] = hst
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
  end

  def options_from_command_line
    MultiHostSync.get_options( ARGV )
  end

  def configuration
    config = configuration_from_file.dup
    config[:options] = configuration_from_file[:options].merge(
      options_from_command_line
    )
    config
  end

  def files
    configuration[:files]
  end

  def hosts_from_configuration_file
    configuration[:hosts]
  end

  def remote_hosts_and_local_host
    hostname = options[:hostname] || Socket.gethostname
    hosts = hosts_from_configuration_file.dup
    my_host = nil
    hosts.each_pair do |key, value|
      hosts[key][:protocol] = 'ssh' unless value[:protocol]
      hosts[key][:port] = 22 unless value[:port]
      if value[:domain] == hostname
        my_host = value
        hosts.delete( key )
      end
    end
    local_host_must_be_known( my_host )
    [ hosts, my_host ]
  end

  def local_host_must_be_known( host )
    unless host
      raise StandardError, 'The local host could not be determined or it did' +
        ' not match any of the hosts listed in the configuration file:' +
        " #{configuration_file_path}. You can specify the local host via the" +         ' option "--hostname=NAME"'
    end
  end

  def remote_hosts
    remote_hosts_and_local_host[0]
  end

  def local_directory
    remote_hosts_and_local_host[1][:directory]
  end

  def local_hostname
    remote_hosts_and_local_host[1][:domain]
  end

  def options
    configuration[:options]
  end

  def configuration_file_path
    Dir.pwd + '/' + @configuration_file
  end

  def configuration_from_file
     MultiHostSync.symbolize_keys( YAML.load_file( configuration_file_path ) )
  end

  def options_list
    list = []
    options.each do |key, value|
      instances = []
      next unless value
      if value.is_a? Array
        value.each do |instance|
          instances.push( instance )
        end
      else
        instances.push( value )
      end
      instances.each do |instance|
        if instance
          if instance === true 
            list.push( '--' + key.to_s )
          else
            list.push( '--' + key.to_s + '=' + instance.to_s )
          end
        end
      end
    end
    list.join( ' ' )
  end

  def remote_directory( host )
    "#{host[:user]}@#{host[:domain]}:#{host[:directory]}"
  end

  def put_command( host )
    rsync_command( local_directory, remote_directory(host), files,
                   options_list )
  end

  def get_command( host )
    rsync_command( remote_directory(host), local_directory, files,
                   options_list )
  end

  def rsync_command( source_directory, target_directory, files, options_list )
    paths = []
    files.each do |file|
      paths.push( source_directory + '/' + file )
    end
    path_list = paths.join(' ')
    "rsync #{options_list} #{path_list} #{target_directory}"
  end

  def sync
    commands = []
    # TODO: change to :put, :get, :put to sync files once this is tested
    #[ :put, :get, :put ].each do |type|
    [ :put ].each do |type|
      remote_hosts.each_pair do |key, host|
        if MultiHostSync::host_reachable?( host[:domain], host[:port] )
          commands << send( "#{type}_command", host )
        end
      end
    end
    commands_string = commands.join( "; \\\n" )
    puts commands_string
    #IO.popen( commands_string ) { |f| puts f.gets }
  end
end
