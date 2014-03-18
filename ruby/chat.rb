#!/usr/bin/env ruby

require './em-eventsource'
require 'thread'
require 'httparty'
require 'json'
require './display'

URL = 'https://eventsource.firebaseio-demo.com/.json'

class PostThread
  include HTTParty

  ssl_ca_file 'cacert.pem'

  def initialize(outbound_queue)
    @outbound_queue = outbound_queue
    @post_uri = URL
  end

  def run
    @thread = Thread.new do
      while true
        msg = @outbound_queue.pop
        if msg
          send_msg(msg)
        else
          break
        end
      end
    end
  end

  def join
    @thread.join
  end

  private

  def send_msg(msg)
    self.class.post(@post_uri, {:body => msg.to_json, :headers => { 'Content-Type' => 'application/json' }})
  end

end

class RemoteThread

  def initialize(message_queue)
    @message_queue = message_queue
  end

  def run
    @thread = Thread.new do
      EM.run do
        @source = EventMachine::EventSource.new(URL, headers = {"Accept" => "text/event-stream"})
        #@source.message do |message|
        #  puts "new message #{message}"
        #end
        @source.on "keep-alive" do |unused|
          # just a keep-alive, do nothing. unused message is null
        end
        @source.on "put" do |put|
          msg_data = JSON.parse(put)
          path = msg_data['path']
          data = msg_data['data']
          if path == "/"
            if data
              keys = data.keys
              keys.sort!
              keys.each do |key|
                @message_queue << data[key]
              end
            end
          else
            # Must be a Push ID
            @message_queue << data
          end
        end
        @source.on "patch" do |merge|
          msg_data = JSON.parse(merge)
          path = msg_data['path']
          data = msg_data['data']
          if path == "/"
            if data
              keys = data.keys
              keys.sort!
              keys.each do |key|
                @message_queue << data[key]
              end
            end
          else
            @message_queue << data
          end
        end
        @source.error do |error|
          puts "error: #{error}"
          @source.close
        end
        @source.open do
          #puts "opened"
        end
        @source.start
      end
    end
  end

  def close
    @source.close
    EM.schedule {
      EM.stop
    }
  end

  def join
    @thread.join
  end
end


client = if ARGV.length == 1 then
           ARGV[0]
         else
           "ruby"
         end

outbound_queue = Queue.new
inbound_queue = Queue.new

post_thread = PostThread.new(outbound_queue)
post_thread.run

remote_thread = RemoteThread.new(inbound_queue)
remote_thread.run

#disp = BasicDisplay.new(outbound_queue, client, inbound_queue)
disp = CursesDisplay.new(outbound_queue, client, inbound_queue)
disp.run

post_thread.join

remote_thread.close
remote_thread.join
