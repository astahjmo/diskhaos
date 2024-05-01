
require "./diskhaos/discord/*"
# TODO: Write documentation for `Diskhaos`
TOKEN = ENV["DISCORD_TOKEN"]
module Diskhaos
  VERSION = "0.1.0"

  client = Gateway.new(TOKEN)
  client.connect
end
