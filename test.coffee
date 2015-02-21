minecraft = require './servers/minecraft'

kind = minecraft.server_kind
kind.provision {directory: 'tmp', port: 25565, server_type: 'vanilla', memory: 1024}, (error, server) ->
  if error
    console.log error
  else
    console.log 'provisioned, running server...'
    console.log server
    server.run (state) ->
      if not state
        console.log 'server first started'
      else
        console.log 'server is up'