require "json"
require "log"
require "random"
require "http/client"


DISCORD_URL = "discord.com"
PORT = 443
USER_AGENT = "diskhaos/1.0"

module Diskhaos
  module Opcodes
     DISPATCH = 0
     HEARTBEAT = 1
     IDENTIFY = 2
     PRESENCE_UPDATE = 3
     VOICE_STATE_UPDATE = 4
     RESUME = 6
     RECONNECT = 7
     REQUEST_GUILD_MEMBERS = 8
     INVALID_SESSION = 9
     HELLO = 10
     HEART_BEAT_ACK = 11

    def self.to_string(op_code)
      case op_code
      when Opcodes::DISPATCH then "DISPATCH"
      when Opcodes::HEARTBEAT then "HEARTBEAT"
      when Opcodes::IDENTIFY then "IDENTIFY"
      when Opcodes::PRESENCE_UPDATE then "PRESENCE_UPDATE"
      when Opcodes::VOICE_STATE_UPDATE then "VOICE_STATE_UPDATE"
      when Opcodes::RESUME then "RESUME"
      when Opcodes::RECONNECT then "RECONNECT"
      when Opcodes::REQUEST_GUILD_MEMBERS then "REQUEST_GUILD_MEMBERS"
      when Opcodes::INVALID_SESSION then "INVALID_SESSION"
      when Opcodes::HELLO then "HELLO"
      when Opcodes::HEART_BEAT_ACK then "HEART_BEAT_ACK"
      else raise "OpCode não reconhecido: #{op_code}"
      end
    end
  end

  class Session
    def initialize(session_id : String)
      @suspended = false
      @pipe_broken = false
      @invalid = false
    end
  end

  class Gateway
      @@interval : Int32 = 0
      @@indentified : Bool = false

    def initialize(token : String)
      Log.setup(:debug)
      @token = token
      @client = HTTP::Client.new(DISCORD_URL, PORT, tls: true)
      @headers = HTTP::Headers.new
      @headers.add("Authorization", "Bot " + token)
      @headers.add("User-Agent", USER_AGENT)
    end

    private def handle_websocket_message(msg)
        response = JSON.parse(msg).as_h
        Log.debug{"Received a ws ping: #{Opcodes.to_string(response["op"])}"}
        Log.debug{"#{response}"}
        if @@interval == 0
          @@interval = response["d"]["heartbeat_interval"].to_s.to_i
        end
        real_interval = (Random.rand(0.0..1.0) * @@interval) / 1000.0
        sleep(real_interval)
        if @@interval != 0 && @@indentified == false
          send = {
            op: Opcodes::IDENTIFY,
            d: {
              token: @token,
              intents: 513,
              properties: {
              os: "linux",
              browser: "Diskhaos",
              device: "Diskhaos"
              }
            }
          }
        else
          send = {
            op: Opcodes::HEARTBEAT,
            d: nil
        }
        end
        send.to_json
    end

    def connect
      response = get_gateway_url()
      Log.debug{"Getting discord websocket gateway"}
      if response.success?
        Log.debug{"Discord gatewaay #{response.body}"}
        gateway_url = JSON.parse(response.body)["url"].to_s.sub("wss://", "")
        start_websocket(gateway_url)
      else
        puts "Failed to get gateway URL: #{response.status_code} - #{response.body}"
      end
    end

    private def get_gateway_url
      @client.get("/api/v10/gateway/bot", @headers)
    end

    # TODO: Stop using HTTP::WebSocket and implement new way to deal with this
    private def start_websocket(gateway_url)
      Log.debug{"Registering ws handlers!"}
      ws = HTTP::WebSocket.new(host: gateway_url, path: "/?v=10&encoding=json", port: 443, tls: true, headers: @headers)
      ws.on_message do |msg|
        Log.debug{"Received a websocket message"}
        message = handle_websocket_message(msg)
        Log.debug{"Sending op code: #{message}"}
        ws.send(message.to_s)
      end
      ws.on_close do |msg|
        puts "CLOSED: #{msg}"
      end
      ws.on_ping do |msg|
        puts "PINGED: #{msg}"
      end
      Log.debug{"Running WS"}
      ws.run
    end
  end
end
