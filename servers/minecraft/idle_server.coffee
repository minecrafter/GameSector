readProperties = require('../../util/java_properties').deserialize
minecraft = require 'minecraft-protocol'
path = require 'path'
fs = require 'fs'
imageSize = require 'image-size'
imageType = require 'image-type'

reason = JSON.stringify text: 'The server is now waking up. Please wait one minute for the server to come online.'

loadAndValidateFavicon = (location, callback) ->
  fs.readFile location, (err, faviconBuffer) ->
    if err
      # No favicon found or an I/O error. That's okay.
      callback err, null
    if faviconBuffer.length < 65536
      try
        type = imageType faviconBuffer
        dimensions = imageSize faviconBuffer, null

        if type.ext == 'png' and dimensions.width == 64 and dimensions.height == 64
          callback null, faviconBuffer.toString 'base64'
        else
          callback new Error("File was not an PNG file or not 64x64 in size"), null
      catch e
        callback e, null
    else
      callback new Error("Image was over 64KB (65,536 bytes)"), null

startServer = (server) ->
  setUp = (favicon) ->
    console.log "Creating server"
    idleServer = minecraft.createServer port: server.properties['server-port'], 'online-mode': false, 'max-players': server.properties['max-players'], motd: server.properties.motd

    if favicon?
      idleServer.favicon = favicon

    console.log "Server initialized"

    idleServer.once 'login', (client) ->
      # Mojang is retarded so we delay the actual disconnect and clean up in hopes that the client gets the right stuff.
      disconnect = ->
        client.end reason

        # But then we have minecraft-protocol in the way. Get it out of the way.
        setTimeout () ->
          idleServer.close()
          server.run()
        , 20

      setTimeout disconnect, 250

  # If a favicon exists, load it
  loadAndValidateFavicon path.join(server.directory, 'server-icon.png'), (err, result) ->
    console.log "Read favicon"
    setUp result

module.exports = startServer

console.log "Reading server properties"
properties = readProperties path.join 'tmp', "server.properties"

test =
  directory: 'tmp'
  properties: properties
  run: -> console.log "If I were a real server, I'd be running right now."

startServer test
