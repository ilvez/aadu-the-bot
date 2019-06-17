#!/usr/bin/env ruby

require_relative '../lib/simple_bot'
require 'subprocess'

class Aadu < SimpleBot
  def handle_message(event)
    return if mxid == event.sender

    message = event.content[:body].strip

    scripts.each do |regex, file|
      next unless message =~ /#{regex}/i

      response = Subprocess.check_output([file, message])
      event_room(event.room_id).send_text(response)
      break
    end
  end

  private

  def initialize_bot
    super

    raise 'No scripts to run' if scripts.empty?
  end

  def scripts
    @scripts ||=
      begin
        scripts = {}
        Dir.glob("#{config[:scripts_path]}/*") do |file|
          regex_key = `CONFIG=1 #{file}`
          scripts = scripts.merge(
            regex_key.strip => file
          )
        end

        scripts
      end
  end

  def event_room(room_id)
    rooms.select { |r| r.id == room_id }.first
  end

  def configuration_keys
    super + [:scripts_path]
  end
end

Aadu.run
