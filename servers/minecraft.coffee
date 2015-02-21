spawn = require('child_process').spawn
join_path = require('path').join
request = require 'request'
write_stream = require('fs').createWriteStream
write_file = require('fs').writeFile
read_file_sync = require('fs').readFileSync
mc_ping = require('minecraft-protocol').ping

SERVER_STARTED = /Done \([0-9.]+n?s\)! For help, type "help" or "\?"/;

# Provides the possible server types with downloads to each.
class ServerJarProvider
  # TODO: This currently loads from a local source. In the future, we would prefer to use an HTTP request.
  available = {}

  constructor: () ->
    available = JSON.parse read_file_sync 'data/minecraft_server_kinds.json'

  is_available_kind: (kind) ->
    return available[kind] != undefined

  get_uri: (kind, version) ->
    return available[kind].versions[version]

  get_latest_uri: (kind) ->
    return available[kind].versions[available[kind].latest]

# Provides provisioning of Minecraft servers.
class MinecraftServerKind
  provision: (properties, callback) ->
    jar_provider = new ServerJarProvider()

    if properties.port == undefined or properties.directory == undefined or properties.server_type == undefined or properties.memory == undefined
      callback new Error 'Invalid properties provided.'
      return

    if not jar_provider.is_available_kind properties.server_type
      callback new Error 'Invalid server type provided.'
      return

    mc_src_jar = jar_provider.get_latest_uri properties.server_type

    mc_properties_path = join_path properties.directory, 'server.properties'
    mc_dest_jar_path = join_path properties.directory, 'minecraft_server.jar'
    mc_eula_path = join_path properties.directory, 'eula.txt'

    write_file mc_properties_path, "server-port=" + properties.port
    write_file mc_eula_path, "eula=true"
    ms_jar = write_stream mc_dest_jar_path
    ms_jar.on 'close', () -> callback null, new MinecraftServer(properties.directory, properties)
    request(mc_src_jar).pipe ms_jar

# Provides the mechanism to allow servers to be run
class MinecraftServer
  child = null
  last_results = []
  server_started = false
  pinger_timeout = null

  constructor: (@directory, @properties) ->

  pinger: () ->
    mc_ping.ping port: @properties.port, (error, result) ->
      if error?
        console.log "A server did not reply to a ping request. It has likely crashed."
        # TODO: Handle this.

  emit_command: (command) ->
    child.stdout.write command + '\n'

  stop: (callback) ->
    this.emit_command 'stop'

    # Permit 30 seconds for the server to end gracefully.
    watchdog_function = () ->
      child.kill 'SIGKILL'

    watchdog_timeout = setTimeout watchdog_function, 1000 * 30

    # Add a handler here to allow clearing of the forceful watchdog and report clean exits
    child.on 'exit', (code, signal) ->
      clearTimeout watchdog_timeout
      server_started = false
      last_results.clear()
      callback signal == null

  run: (callback) ->
    # TODO: Allow "secure" spawning
    child = spawn '/usr/bin/env', ['java', '-Xmx' + @properties.memory + 'M', '-jar', 'minecraft_server.jar', 'nogui'],
      cwd: @directory

    child.stdout.on 'data', (line) ->
      if SERVER_STARTED.test line
        server_started = true
        pinger_timeout = setInterval this.pinger, 1000 * 60
        callback true

      last_results.push line

      if last_results.length > 100
        delete last_results[0]

    callback false

module.exports =
  server_kind: new MinecraftServerKind