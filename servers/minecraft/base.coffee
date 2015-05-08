spawn = require('child_process').spawn
joinPath = require('path').join
request = require 'request'
writeStream = require('fs').createWriteStream
writeFile = require('fs').writeFile
readFileSync = require('fs').readFileSync
ping = require('minecraft-protocol').ping
EventEmitter = require('events').EventEmitter

SERVER_STARTED = /Done \([0-9.]+n?s\)! For help, type "help" or "\?"/;

# Provides the possible server types with downloads to each.
class ServerJarProvider
  # TODO: This currently loads from a local source. In the future, we would prefer to use an HTTP request.
  available = {}

  constructor: () ->
    available = JSON.parse readFileSync 'data/minecraft_server_kinds.json'

  isAvailableKind: (kind) ->
    return available[kind] != undefined

  getUri: (kind, version) ->
    return available[kind].versions[version]

  getLatest: (kind) ->
    return available[kind].versions[available[kind].latest]

# Provides provisioning of Minecraft servers.
class MinecraftServerKind
  provision: (properties, callback) ->
    jarProvider = new ServerJarProvider

    if properties.port == undefined or properties.directory == undefined or properties.server_type == undefined or properties.memory == undefined
      callback new Error 'Invalid properties provided.'
      return

    if not jarProvider.isAvailableKind properties.server_type
      callback new Error 'Invalid server type provided.'
      return

    serverJarUri = jarProvider.getLatest properties.server_type

    propertiesPath = joinPath properties.directory, 'server.properties'
    destinationJarPath = joinPath properties.directory, 'minecraft_server.jar'
    eulaPath = joinPath properties.directory, 'eula.txt'

    writeFile propertiesPath, "server-port=" + properties.port
    writeFile eulaPath, "eula=true"

    ms_jar = writeStream destinationJarPath
    ms_jar.on 'close', () -> callback null, new MinecraftServer(properties.directory, properties)
    request(serverJarUri).pipe ms_jar

# Provides the mechanism to allow servers to be run
class MinecraftServer extends EventEmitter
  child = null
  serverStarted = false
  pingerTimeout = null
  self = null

  constructor: (@directory, @properties) ->
    self = this

  pinger: () ->
    ping port: @properties.port, (error, result) ->
      if error?
        console.log "A server did not reply to a ping request. It has likely crashed."
        self.emit 'ping_failure'

  emitCommand: (command) ->
    this.emit 'command', command
    child.stdin.write command + '\n'

  stop: ->
    this.emit 'stop'
    this.emitCommand 'stop'

    # Permit 30 seconds for the server to end gracefully.
    watchdogFunction = () ->
      child.kill 'SIGKILL'

    watchdogTimeout = setTimeout watchdogFunction, 1000 * 30

    # Add a handler here to allow clearing of the forceful watchdog and report clean exits
    child.on 'exit', (code, signal) ->
      clearTimeout watchdogTimeout
      serverStarted = false
      self.emit 'stop', kind: signal == null ? "graceful" : "forceful"

  run: (callback) ->
    # TODO: Allow "secure" spawning
    child = spawn '/usr/bin/env', ['java', '-Xmx' + @properties.memory + 'M', '-jar', 'minecraft_server.jar', 'nogui'],
      cwd: @directory

    this.emit "start", false

    child.stdout.on 'data', (line) ->
      if SERVER_STARTED.test line
        serverStarted = true
        pingerTimeout = setInterval this.pinger, 1000 * 60
        self.emit "start", true

      self.emit "message", line

    callback()

module.exports = new MinecraftServerKind
