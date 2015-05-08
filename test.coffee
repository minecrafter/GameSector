minecraft = require './servers/minecraft/base'

minecraft.provision {directory: 'tmp', port: 25565, server_type: 'vanilla', memory: 1024}, (error, server) ->
  if error
    console.log error
  else
    console.log 'provisioned, running server...'
    server.run () ->
      server.on 'message', (msg) -> console.log msg.toString()
      console.log 'server started'

      stopper = () ->
        console.log 'stopping server'
        server.stop()

      commandTest = () ->
        server.emitCommand 'help'

      setTimeout commandTest, 1000 * 7
      setTimeout stopper, 1000 * 20
