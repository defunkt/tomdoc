module Butter
  class Something
  end
end

module GitHub
  # Sings you a poem.
  #
  # name - Your name as a String.
  #
  # Returns a String poem.
  def self.poem(name)
    "Roses are red, " +
      "violets are blue, " +
        "#{name}'s a sucker, " +
          "and now you are, too."
  end

  # Chimney is the API for getting and setting Smoke routes.
  #
  # Setup
  # -----
  #
  # In order for Chimney to function, some setup keys are required to exist in the
  # routing Redis. This sections shows you how to enter the required
  # information. Start by connecting to the routing Redis:
  #
  #     require 'chimney'
  #     chimney = Chimney.new('router.example.com:21201')
  #
  # The routing Redis must contain one or more storage host values.
  #
  #     chimney.add_storage_server('s1.example.com')
  #     chimney.add_storage_server('s2.example.com')
  #
  # Each storage host is expected to have disk usage information (percent of disk
  # used) that is kept up to date (via cron or similar). If these are not set, the
  # host that will be chosen for new routes is arbitrary, but will always be the
  # same. This is a simple example of a cron script that is responsible for
  # updating the usage keys:
  #
  #     (0..15).map { |num| num.to_s(16) }.each do |part|
  #       host = get_current_host # => 's1.example.com'
  #       percent_used = get_partition_usage(part) # => 17.23
  #       chimney.set_partition_usage(host, part, percent_used)
  #     end
  #
  # Usage
  # -----
  #
  # Make sure you require this sucker.
  #
  #     require 'chimney'
  #
  # Chimney must be initialized with the host:port of the routing Redis server.
  #
  #     chimney = Chimney.new('router.example.com:21201')
  #
  # Looking up a route for a user is simple. This command simply finds the host
  # upon which the user is stored. If the router Redis is unreachable, Chimney
  # will check its internal cache. If that is a miss, it will try to reconnect to
  # the router. If that fails, it will fallback on making calls to Smoke and
  # checking each storage server for the user. Subsequent lookups will then be
  # able to find the route in the cache. This mechanism should ensure high
  # tolerance to failures of the routing server.
  #
  #     chimney.get_user_route('mojombo')
  #     # => 'domU-12-31-38-01-C8-F1.compute-1.internal'
  #
  # Setting a route for a new user is also a simple call. This command will first
  # refresh the cached list of available storage hosts, then figure out which one
  # of them is least loaded. This host will be set as the route for the user and
  # returned. If the user already exists in the routing table, the host is
  # returned and the routing table is unaffected.
  #
  #     chimney.set_user_route('franko')
  #     # => domU-12-31-38-01-C8-F1.compute-1.internal
  #
  # If you need to change the name of the user, but keep the host the same:
  #
  #     chimney.rename_user_route('oldname', 'newname')
  #
  # If you need to remove a route for a user:
  #
  #     chimney.delete_user_route('mojombo')
  #
  # If you need the absolute path to a user on disk (class or instance method):
  #
  #     Chimney.shard_user_path('mojombo')
  #     chimney.shard_user_path('mojombo')
  #     # => "/data/repositories/2/a8/e2/95/mojombo"
  #
  # If you need the absolute path to a repo on disk (class or instance method):
  #
  #     Chimney.shard_repo_path('mojombo', 'god')
  #     chimney.shard_repo_path('mojombo', 'god')
  #     # => "/data/repositories/2/a8/e2/95/mojombo/god.git"
  #
  # Getting and setting routes for gists is similar to that for users:
  #
  #     chimney.get_gist_route('1234')
  #     # => 'domU-12-31-38-01-C8-F1.compute-1.internal'
  #
  #     chimney.set_gist_route('4e460bfd6c184058c7a3')
  #     # => 'domU-12-31-38-01-C8-F1.compute-1.internal'
  #
  # If you need the absolute path to a gist on disk (class or instance method):
  #
  #     Chimney.shard_gist_path('1234')
  #     chimney.shard_gist_path('1234')
  #     # => "/data/repositories/0/81/dc/9b/gist/1234.git"
  #
  # If you need the unix user that has access to the repository data (class or
  # instance method):
  #
  #     Chimney.unix_user
  #     chimney.unix_user
  #     # => 'root'
  #
  # That's it!
  class Chimney
    SMOKE_HOSTS_FILE = '/tmp/smoke_hosts'
    REPO_DIR = ENV['REPO_ROOT'] || '/data/repositories'
    UNIX_USER = 'git'

    attr_accessor :host, :port
    attr_accessor :client, :hosts, :cache, :verbose, :logger

    # Instantiate a new Chimney object.
    #
    # server - The host:port of the routing redis instance.
    # logger - An optional Logger object. If none is given, Chimney
    #          writes to /dev/null.
    #
    # Returns a configured Chimney instance.
    def initialize(server, logger = nil)
      self.cache = {}
      self.hosts = []
      self.logger = logger || Logger.new('/dev/null')

      self.host = server.split(':').first
      self.port = server.split(':').last.to_i
      ensure_client_connection
    end

    # Add a storage server to the list.
    #
    # host - The String hostname to add.
    #
    # Returns the Array of String hostnames after the addition.
    def self.add_storage_server(host)
      if current_servers = self.client.get('gh.storage.servers')
        new_servers = [current_servers, host].join(',')
      else
        new_servers = host
      end
      self.client.set('gh.storage.servers', new_servers)
      new_servers.split(',')
    end

    # Remove a storage server from the list.
    #
    # host - The String hostname to remove.
    #
    # Returns the Array of String hostnames after the removal.
    # Raises Chimney::NoSuchStorageServer if the storage server is not currently
    #   in the list.
    def remove_storage_server(host)
      if current_servers = self.client.get('gh.storage.servers')
        servers = current_servers.split(',')
        if servers.delete(host)
          self.client.set('gh.storage.servers', servers.join(','))
          return servers
        else
          raise NoSuchStorageServer.new(host)
        end
      else
        raise NoSuchStorageServer.new(host)
      end
    end

    # The list of storage server hostnames.
    #
    # Returns an Array of String hostnames.
    def storage_servers
      self.client.get('gh.storage.servers').split(',')
    end

    # Checks if the storage server is currently online.
    #
    # host - The String hostname to check.
    #
    # Returns true if the server is online, false if not.
    def storage_server_online?(host)
      !self.client.exists("gh.storage.server.offline.#{host}")
    rescue Errno::ECONNREFUSED
      # If we can't connect to Redis, check to see if the BERTRPC
      # server is alive manually.
      begin
        smoke(host).alive?
      rescue BERTRPC::ReadTimeoutError
        false
      end
    end

    # Sets a storage server as being online.
    #
    # host - The String hostname to set.
    #
    # Returns nothing.
    def set_storage_server_online(host)
      self.client.delete("gh.storage.server.offline.#{host}")
    end

    # Sets a storage server as being offline.
    #
    # host     - The String hostname to set.
    # duration - An optional number of seconds after which the
    #            server will no longer be considered offline; with
    #            no duration, servers are kept offline until marked
    #            online manually.
    #
    # Returns true if the server was not previously offline, nil otherwise.
    def set_storage_server_offline(host, duration=nil)
      key = "gh.storage.server.offline.#{host}"
      if self.client.set_unless_exists(key, Time.now.to_i)
        self.client.expire(key, duration) if duration
        true
      end
    end

    # If a server is offline, tells us when we first noticed.
    #
    # host - The String hostname to check.
    #
    # Returns nothing if the storage server is online.
    # Returns an instance of Time representing the moment we set the
    #   server as offline if it is offline.
    def self.storage_server_offline_since(host)
      if time = self.client.get("gh.storage.server.offline.#{host}")
        Time.at(time.to_i)
      end
    rescue Errno::ECONNREFUSED
      # If we can't connect to Redis and we're wondering when the
      # storage server went offline, return whatever.
      Time.now
    end

    # Maximum number of network failures that can occur with a file server
    # before it's marked offline.
    DISRUPTION_THRESHOLD = 10

    # The window of time, in seconds, under which no more than
    # DISRUPTION_THRESHOLD failures may occur.
    DISRUPTION_WINDOW = 5

    # Called when some kind of network disruption occurs when communicating
    # with a file server. When more than DISRUPTION_THRESHOLD failures are
    # reported within DISRUPTION_WINDOW seconds, the server is marked offline
    # for two minutes.
    #
    # The return value can be used to determine the action taken:
    #   nil when the storage server is already marked offline.
    #   > 0 when the number of disruptions is under the threshold.
    #   -1 when the server has been marked offline due to too many disruptions.
    def storage_server_disruption(host)
      return if !self.storage_server_online?(host)
      key = "gh.storage.server.disrupt.#{host}"
      if counter_suffix = self.client.get(key)
        count = self.client.incr("#{key}.#{counter_suffix}")
        if count > DISRUPTION_THRESHOLD
          if self.set_storage_server_offline(host, 30)
            self.client.del(key, "#{key}.#{counter_suffix}")
            -1
          end
        else
          count
        end
      else
        if self.client.set_unless_exists(key, Time.now.to_f * 1000)
          self.client.expire(key, DISRUPTION_WINDOW)
          self.storage_server_disruption(host)
        else
          # we raced to set first and lost, wrap around and try again
          self.storage_server_disruption(host)
        end
      end
    end

    # Lookup a route for the given user.
    #
    # user - The String username.
    #
    # Returns the hostname of the storage server.
    def get_user_route(user)
      try_route(:user, user)
    end

    # Lookup a route for the given gist.
    #
    # gist - The String gist ID.
    #
    # Returns the hostname of the storage server.
    def get_gist_route(gist)
      try_route(:gist, gist)
    end

    # Find the least loaded storage server and set a route there for
    # the given +user+. If the user already exists, do nothing and
    # simply return the host that user is on.
    #
    # user - The String username.
    #
    # Returns the chosen hostname.
    def set_user_route(user)
      set_route(:user, user)
    end

    # Explicitly set the user route to the given host.
    #
    # user - The String username.
    # host - The String hostname.
    #
    # Returns the new String hostname.
    # Raises Chimney::NoSuchStorageServer if the storage server is not currently
    #   in the list.
    def set_user_route!(user, host)
      unless self.storage_servers.include?(host)
        raise NoSuchStorageServer.new(host)
      end
      set_route(:user, user, host)
    end

    # Find the least loaded storage server and set a route there for
    # the given +gist+. If the gist already exists, do nothing and
    # simply return the host that gist is on.
    #
    # gist - The String gist ID.
    #
    # Returns the chosen hostname.
    def set_gist_route(gist)
      set_route(:gist, gist)
    end

    # Change the name of the given user without changing the associated host.
    #
    # old_user - The old user name.
    # new_user - The new user name.
    #
    # Returns the hostname on success, or nil if the old user was not found
    #   or if the new user already exists.
    def rename_user_route(old_user, new_user)
      if (host = get_user_route(old_user)) && !get_user_route(new_user)
        delete_user_route(old_user)
        set_route(:user, new_user, host)
      else
        nil
      end
    end

    # Delete the route for the given user.
    #
    # user - The String username.
    #
    # Returns nothing.
    def delete_user_route(user)
      self.client.delete("gh.storage.user.#{user}")
    end

    # Delete the route for the given gist.
    #
    # gist - The String gist ID.
    #
    # Returns nothing.
    def delete_gist_route(gist)
      self.client.delete("gh.storage.gist.#{gist}")
    end

    # Set the partition usage for a given host.
    #
    # host      - The String hostname.
    # partition - The single lowercase hex digit partition String.
    # usage     - The percent of disk space used as a Float [0.0-100.0].
    #
    # Returns nothing.
    def set_partition_usage(host, partition, usage)
      self.client.set("gh.storage.server.usage.percent.#{host}.#{partition}", usage.to_s)
    end

    # The list of partition usage percentages.
    #
    # host - The optional String hostname to restrict the response to.
    #
    # Returns an Array of [partition:String, percentage:Float].
    def partition_usage(host = nil)
      pattern = "gh.storage.server.usage.percent."
      pattern += host ? "#{host}.*" : "*"
      self.client.keys(pattern).map do |x|
        [x, self.client.get(x).to_f]
      end
    end

    # Calculate the absolute path of the user's storage directory.
    #
    # user - The String username.
    #
    # Returns the String path:
    #   e.g. '/data/repositories/2/a8/e2/95/mojombo'.
    def self.shard_user_path(user)
      hex = Digest::MD5.hexdigest(user)
      partition = partition_hex(user)
      shard = File.join(partition, hex[0..1], hex[2..3], hex[4..5])
      File.join(REPO_DIR, shard, user)
    end

    def shard_user_path(user)
      Chimney.shard_user_path(user)
    end

    # Calculate the absolute path of the repo's storage directory.
    #
    # user - The String username.
    # repo - The String repo name.
    #
    # Returns the String path:
    #   e.g. '/data/repositories/2/a8/e2/95/mojombo/god.git'.
    def self.shard_repo_path(user, repo)
      hex = Digest::MD5.hexdigest(user)
      partition = partition_hex(user)
      shard = File.join(partition, hex[0..1], hex[2..3], hex[4..5])
      File.join(REPO_DIR, shard, user, "#{repo}.git")
    end

    def shard_repo_path(user, repo)
      Chimney.shard_repo_path(user, repo)
    end

    # Calculate the absolute path of the gist's storage directory.
    #
    # gist - The String gist ID.
    #
    # Returns String path:
    #   e.g. '/data/repositories/0/81/dc/9b/gist/1234.git'.
    def self.shard_gist_path(gist)
      hex = Digest::MD5.hexdigest(gist)
      partition = partition_hex(gist)
      shard = File.join(partition, hex[0..1], hex[2..3], hex[4..5])
      File.join(REPO_DIR, shard, 'gist', "#{gist}.git")
    end

    def shard_gist_path(gist)
      Chimney.shard_gist_path(gist)
    end

    # Calculate the partition hex digit.
    #
    # name - The String username or gist.
    #
    # Returns a single lowercase hex digit [0-9a-f] as a String.
    def self.partition_hex(name)
      Digest::MD5.hexdigest(name)[0].chr
    end

    def partition_hex(name)
      Chimney.partition_hex(name)
    end

    # The unix user account that has access to the repository data.
    #
    # Returns the String user e.g. 'root'.
    def self.unix_user
      UNIX_USER
    end

    def unix_user
      Chimney.unix_user
    end

    # The short name of the server currently executing this code. If this is a
    # front end and we're on fe2.rs.github.com, this will return "fe2".
    #
    # Returns a String host short name e.g. "fe2".
    def self.current_server
      if hostname =~ /github\.com/
        hostname.split('.').first
      else
        "localhost"
      end
    end

    def current_server
      Chimney.current_server
    end

    # The full hostname of the current server.
    #
    # Returns a String hostname e.g. "fe2.rs.github.com".
    def self.hostname
      `hostname`.chomp
    end

    private

    # Ensure that a valid connection to the routing server has been made
    # and that the list of hosts has been fetched.
    #
    # Returns nothing.
    def ensure_client_connection
      logger.info "Starting Chimney..."
      self.client = Redis.new(:host => self.host, :port => self.port)
      if hosts = self.client.get('gh.storage.servers')
        self.hosts = hosts.split(',')
        write_hosts_to_file
        logger.info "Found #{self.hosts.size} hosts from Router."
      else
        read_hosts_from_file
        raise InvalidRoutingServer.new("Hosts could not be loaded.") if self.hosts.empty?
        logger.warn "Router does not contain hosts list; loaded #{self.hosts.size} hosts from file."
      end
    rescue Errno::ECONNREFUSED
      read_hosts_from_file
      raise InvalidRoutingServer.new("Hosts could not be loaded.") if self.hosts.empty?
      logger.warn "Unable to connect to Router; loaded #{self.hosts.size} hosts from file."
    end

    # Write the hosts list to a file.
    #
    # Returns nothing.
    def write_hosts_to_file
      File.open(SMOKE_HOSTS_FILE, 'w') do |f|
        f.write(self.hosts.join(','))
      end
    end

    # Read the hosts from a file.
    #
    # Returns nothing.
    def read_hosts_from_file
      if File.exists?(SMOKE_HOSTS_FILE)
        self.hosts = File.read(SMOKE_HOSTS_FILE).split(',')
      end
    end

    # Reload the hosts list from the router.
    #
    # Returns nothing.
    def reload_hosts_list
      self.hosts = self.storage_servers
      write_hosts_to_file
    end

    # Find the storage server with the least disk usage for the target partition.
    #
    # type - Either :user or :gist.
    # name - The String username or gist.
    #
    # Returns a hostname.
    def find_least_loaded_host(name)
      partition = partition_hex(name)
      self.hosts.select { |h| storage_server_online?(h) }.map do |host|
        [self.client.get("gh.storage.server.usage.percent.#{host}.#{partition}").to_f, host]
      end.sort.first.last
    end

    # Set the route for a given user or gist.
    #
    # type - Either :user or :gist.
    # name - The String username or gist.
    # host - The String hostname that will be set if it is present (optional).
    #
    # Returns the String hostname that was set.
    def set_route(type, name, host = nil)
      if !host && existing_host = self.client.get("gh.storage.#{type}.#{name}")
        return existing_host
      end

      unless host
        reload_hosts_list
        host = find_least_loaded_host(name)
      end

      self.client.set("gh.storage.#{type}.#{name}", host)
      host
    end

    # Try to find a route using a variety of different fallbacks.
    #
    # type - Either :user or :gist.
    # name - The String username or gist.
    #
    # Returns the hostname of the storage server.
    def try_route(type, name)
      try_route_with_redis(type, name)
    end

    # Try the lookup from redis. If redis is unavailable, try
    # to do the lookup from internal cache.
    #
    # type - Either :user or :gist.
    # name - The String username or gist.
    #
    # Returns the hostname of the storage server.
    def try_route_with_redis(type, name)
      if host = self.client.get("gh.storage.#{type}.#{name}")
        logger.debug "Found host '#{host}' for #{type} '#{name}' from Router."
        self.cache[name] = host
      else
        self.cache.delete(name)
      end
      host
    rescue Errno::ECONNREFUSED
      logger.warn "No connection to Router..."
      try_route_with_internal_cache(type, name)
    end

    # Try the lookup from the internal route cache. If the key is not
    # in internal cache, try to reconnect to redis and redo the lookup.
    #
    # type - Either :user or :gist.
    # name - The String username or gist.
    #
    # Returns the hostname of the storage server.
    def try_route_with_internal_cache(type, name)
      if host = self.cache[name]
        logger.debug "Found '#{host}' for #{type} '#{name}' from Internal Cache."
        host
      else
        logger.warn "No entry in Internal Cache..."
        try_route_with_new_redis_connection(type, name)
      end
    end

    # Try the lookup with a new redis connection. If redis is still
    # unavailable, try each storage server in turn to look for the user/gist.
    #
    # type - Either :user or :gist.
    # name - The String username or gist.
    #
    # Returns the hostname of the storage server.
    def try_route_with_new_redis_connection(type, name)
      self.client.connect_to_server
      host = self.client.get("gh.storage.#{type}.#{name}")
      logger.debug "Found host '#{host}' for #{type} '#{name}' from Router after reconnect."
      host
    rescue Errno::ECONNREFUSED
      logger.warn "Still no connection to Router..."
      try_route_with_individual_storage_checks(type, name)
    end

    # Try the lookup by asking each storage server if the user or gist dir exists.
    #
    # type - Either :user or :gist.
    # name - The String username or gist.
    #
    # Returns the hostname of the storage server or nil.
    def try_route_with_individual_storage_checks(type, name)
      self.hosts.each do |host|
        logger.debug "Trying host '#{host}' via Smoke for existence of #{type} '#{name}'..."

        svc = smoke(host)
        exist =
          case type
          when :user
            svc.user_dir_exist?(name)
          when :gist
            svc.gist_dir_exist?(name)
          else false
          end

        if exist
          self.cache[name] = host
          logger.debug "Found host '#{host}' for #{type} '#{name}' from Smoke."
          return host
        end
      end
      logger.warn "No host found for #{type} '#{name}'."
      nil
    rescue Object => e
      logger.error "No host found for #{type} '#{name}' because of '#{e.message}'."
      nil
    end

    def smoke(host)
      BERTRPC::Service.new(host, 8149, 2).call.store
    end
  end

  class Math
    # Duplicate some text an abitrary number of times.
    #
    # text  - The String to be duplicated.
    # count - The Integer number of times to duplicate the text.
    #
    # Examples
    #   multiplex('Tom', 4)
    #   # => 'TomTomTomTom'
    #
    # Returns the duplicated String.
    def multiplex(text, count)
      text * count
    end
  end
end

module GitHub
  class Jobs
    # Performs a job.
    #
    # Returns nothing.
    def perform
    end
  end
end
