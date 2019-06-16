#!/usr/bin/env ruby

require 'matrix_sdk'
require 'psych'

# A filter to only discover joined rooms
ROOM_DISCOVERY_FILTER = {
  event_fields: %w[sender membership],
  presence: { senders: [], types: [] },
  account_data: { senders: [], types: [] },
  room: {
    ephemeral: { senders: [], types: [] },
    state: {
      senders: [],
      types: [
        'm.room.aliases',
        'm.room.canonical_alias',
        'm.room.member',
      ],
      lazy_load_members: true,
    },
    timeline: { senders: [], types: [] },
    account_data: { senders: [], types: [] },
  },
}.freeze

# A filter to only retrieve messages from rooms

class SimpleClient < MatrixSdk::Client
  ROOM_STATE_FILTER = {
    presence: { senders: [], types: [] },
    account_data: { senders: [], types: [] },
    room: {
      ephemeral: { senders: [], types: [] },
      state: {
        types: ['m.room.member'],
        lazy_load_members: true,
      },
      timeline: {
        types: ['m.room.message'],
      },
      account_data: { senders: [], types: [] },
    },
  }.freeze
  def initialize(hs_url)
    super hs_url, sync_filter_limit: 10

    @pls = {}
    @tracked_rooms = []
    @filter = ROOM_STATE_FILTER.dup
  end

  def add_listener(room)
    room.on_event.add_handler do |ev|
      on_message(ev)
    end

    @tracked_rooms << room.id
  end

  def run
    # Only track messages from the listened rooms
    @filter[:room][:rooms] = @tracked_rooms
    start_listener_thread(filter: @filter.to_json, sync_interval: 1)
  end

  private

  def on_message(event)
    case event.type
    when 'm.room.member'
      puts "[#{Time.now.strftime '%H:%M'}] #{event[:content][:displayname]} joined." if event.membership == 'join'
    when 'm.room.message'
      handle_message(event)
    end
  end

  def handle_message(event)
    puts "#{get_user(event.sender).display_name} -> #{event.content[:body]}"
  end
end

class Bot
  def self.run
    Bot.new.run
  end

  def run
    if $PROGRAM_NAME == __FILE__

      begin
        if config[:debug] == true
          Thread.abort_on_exception = true
          MatrixSdk.debug!
        end

        fetch_room(config[:room_id])
        puts 'Starting listener'
        client.run
        loop {}
      rescue Interrupt
        puts 'Interrupted, exiting...'
      ensure
        if client&.logged_in?
          client.logout
          puts 'Logged out'
        end
      end
    end
  end

  private

  def fetch_room(room_id)
    room = client.find_room(room_id)
    room ||= begin
      client.join_room(room_id)
    end

    client.add_listener(room)
    room
  end

  def client
    @client ||= begin
      client = SimpleClient.new(config[:homeserver_url])
      puts 'Logging in...'
      client.login(config[:user], config[:password], no_sync: true)

      # Only retrieve list of joined room in first sync
      sync_filter = client.sync_filter.merge(ROOM_DISCOVERY_FILTER)
      sync_filter[:room][:state][:senders] << client.mxid
      client.listen_for_events(filter: sync_filter.to_json)

      client
    end
  end

  def config
    @config = begin
      config = Psych.load(IO.read('config.yml'), symbolize_names: true)
      assert_config(config)
      config
    end
  end

  def assert_config(config)
    config.keys.each { |key|
      unless %i[homeserver_url room_id user password debug].include?(key)
        raise Exception.new("Configuration missing key: #{key}")
      end
    }
  end
end

Bot.run
