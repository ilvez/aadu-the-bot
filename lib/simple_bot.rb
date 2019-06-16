#!/usr/bin/env ruby

require 'matrix_sdk'
require 'psych'

class SimpleBot < MatrixSdk::Client
  # A filter to only retrieve messages from rooms
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

  def self.run
    new.run
  end

  def initialize
    super(config[:homeserver_url], sync_filter_limit: 10)

    @tracked_rooms = []
    @filter = ROOM_STATE_FILTER.dup
  end

  def run
    initialize_bot

    puts 'Logging in'
    login(config[:user], config[:password], no_sync: true)

    # Only retrieve list of joined room in first sync
    filter = sync_filter.merge(ROOM_DISCOVERY_FILTER)
    filter[:room][:state][:senders] << mxid
    listen_for_events(filter: filter.to_json)

    config[:room_ids].each { |room_id| initialize_room(room_id) }

    puts 'Starting listener'
    start_listener_thread(filter: @filter.to_json, sync_interval: 1)

    loop {}
  rescue Interrupt
    puts 'Interrupted, exiting...'
  ensure
    if logged_in?
      logout
      puts 'Logged out'
    end
  end

  private

  def initialize_bot
    puts 'Initializing bot'
    if config[:debug] == true
      Thread.abort_on_exception = true
      MatrixSdk.debug!
    end
  end

  def initialize_room(room_id)
    room = find_room(room_id)
    room ||= begin
      puts "Join room: #{room_id}"
      join_room(room_id)
    end

    add_listener(room)
    room
  end

  def add_listener(room)
    room.on_event.add_handler do |ev|
      on_message(ev)
    end

    @tracked_rooms << room.id

    # Only track messages from the listened rooms
    @filter[:room][:rooms] = @tracked_rooms
  end

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

  def config
    @config = begin
      config = Psych.load(IO.read('config.yml'), symbolize_names: true)
      assert_config(config)
      config
    end
  end

  def assert_config(config)
    config.keys.each { |key|
      unless %i[homeserver_url room_ids user password debug].include?(key)
        raise Exception.new("Configuration missing key: #{key}")
      end
    }
  end
end
