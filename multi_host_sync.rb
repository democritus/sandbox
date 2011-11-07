#!/usr/bin/ruby

require 'optparse'
require 'pp'
require 'yaml'
require 'socket'

class MultiHostSync

  PRIVATE_OPTIONS = [ :hostname ]
  KEY_TRANSLATION_MAP = {
    :dry_run => 'dry-run'
  }

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
    print "#{host} connectivity on port #{port}:"
    begin
      #TCPSocket.open( host, port )
    rescue SocketError => error
      print " failed! Socket error: #{error}\n";
      return false
    end
    puts " success!\n";
    true
  end

  def self.get_options( args, options = {} )
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: multi_host_sync.rb [options]"
      
      opts.separator ''

      opts.separator 'Specific options:'

      opts.on( '-n', '--dry-run',
               'show what would have been transferred' ) do |dry|
        options[:dry_run] = true
      end

      opts.on( '--exclude=[LIST]', Array,
               'exclude files matching PATTERN' ) do |excl|
        options[ :exclude ] = excl
      end

      opts.on( '--hostname=[HOSTNAME]',
               'specify the hostname of the source machine' ) do |hst|
        options[:hostname] = hst
      end

      opts.on( '--progress', 'show progress during transfer' ) do |prg|
        options[:progress] = prg
      end

      opts.on( '-r', '--recursive', 'recurse into directories' ) do |rec|
        options[:recursive] = rec
      end

      opts.on( '-e', '--rsh=[COMMAND]',
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

    # Replace default values with those from the command line
    options.each_pair do |key, value|
      if value.is_a?(Array) && options[key] # Merge arrays that already exist
        options[key] | value  # union
      else  # Replace scalars and copy arrays that don't yet exist
        options[key] = value
      end
    end

    options
  end

  def initialize( filename = nil )
    
    @configuration = MultiHostSync.symbolize_keys(
      YAML.load_file( filename) )

    # Merge configuration options with command line options
    @configuration[:options] = MultiHostSync.get_options( ARGV,
      @configuration[:options] )

    # Get list of hosts from configuration file
    @hosts = @configuration[:hosts]

    # Get hostname of local server
    hostname = options[:hostname] || Socket.gethostname

    # Remove local host from list of hosts and set it as current host
    @local_host = nil
    @hosts.each_pair do |key, value|
      @hosts[key][:protocol] = 'ssh' unless value[:protocol]
      @hosts[key][:port] = 22 unless value[:port]
      if value[:domain] == hostname
        @local_host = value
        @hosts.delete( key )
      end
    end

    # Throw error if current_host could not be determined
    unless @local_host
      raise StandardError, 'The local host could not be determined or it did' +
        ' not match any of the hosts listed in the configuration file:' +
        " #{configuration_file_path}. You can specify the local host via the" +         ' option "--hostname=NAME"'
    end
  end

  def configuration
    @configuration
  end

  def local_host
    @local_host
  end

  def hosts
    @hosts
  end

  def options
    configuration[:options]
  end

  def files
    configuration[:files]
  end

  def local_directory
    local_host[:directory]
  end

  def local_hostname
    local_host[:domain]
  end

  def options_list
    list = []
    options.each do |key, value|
      # Skip options that are should not be passed to rsync command
      next if PRIVATE_OPTIONS.include?( key )
      if KEY_TRANSLATION_MAP.keys.include?( key )
        key = KEY_TRANSLATION_MAP[key].to_s
      else
        key = key.to_s
      end
      instances = []
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
            list.push( "--#{key}" )
          else
            list.push( "--#{key}=\"#{instance}\"" )
          end
        end
      end
    end
    list.join( ' ' )
  end

  def sync
    commands = []
    # TODO: change to :put, :get, :put to sync files once this is tested
    #[ :put, :get, :put ].each do |type|
    [ :put ].each do |type|
      hosts.each_pair do |key, host|
        if MultiHostSync::host_reachable?( host[:domain], host[:port] )
          commands << send( "#{type}_command", host )
        end
      end
    end
    commands_string = commands.join( "; \\\n" )
    puts commands_string
    #IO.popen( commands_string ) { |f| puts f.gets }
  end


  private

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
end
