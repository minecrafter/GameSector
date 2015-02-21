readProperties = require('../../util/java_properties').deserialize
minecraft = require 'minecraft-protocol'
path = require 'path'
fs = require 'fs'
imageSize = require 'image-size'
imageType = require 'image-type'

reason = JSON.stringify text: 'This server is now waking up. Please wait one minute for the server to come online.'

loadAndValidateFavicon = (location, callback) ->
  faviconStream = fs.createReadStream location
  faviconChunks = []

  faviconStream.on 'error', (e) ->
    # Just proceed with setup - we don't care
    callback e, null

  faviconStream.on 'data', (chunk) ->
    faviconChunks.push chunk

  faviconStream.on 'end', () ->
    # If the favicon is less than 64KB, use it.
    faviconStream.close()
    faviconBuffer = Buffer.concat faviconChunks

    if faviconBuffer.length < 65536
      try
        type = imageType faviconBuffer
        dimensions = imageSize faviconBuffer, null

        if type.ext == 'png' and dimensions.width == 64 and dimensions.height == 64
          callback null, faviconBuffer.toString 'base64'
      catch e
        callback e, null

    callback new Error("Image was over 64KB (65,536 bytes) or was not a PNG file"), null

startServer = (server) ->
  properties = readProperties path.join server.directory, "server.properties"

  setUp = (favicon) ->
    idleServer = minecraft.createServer port: server.properties.port, 'online-mode': false
    idleServer.maxPlayers = properties['max-players']
    idleServer.motd = properties['motd']

    if favicon?
      idleServer.favicon = favicon

    idleServer.once 'login', (client) ->
      # Mojang is retarded so we delay the actual disconnect and clean up in hopes that the client gets the right stuff.
      disconnect = ->
        client.end reason

        # But then we have minecraft-protocol in the way. Get it out of the way.
        cleanUp = ->
          idleServer.close()
          server.run()

        setTimeout cleanUp, 50

      setTimeout disconnect, 250

  # If a favicon exists, load it
  loadAndValidateFavicon path.join(server.directory, 'server-icon.png'), (err, result) ->
    setUp result

module.exports = startServer

# Test object
test = {
  directory: 'tmp'
  properties: port: 25566
  run: -> console.log "If I were a real server, I'd be running right now."
}

startServer test