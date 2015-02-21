fs = require 'fs'

module.exports =
  deserialize: (file) ->
    contents = fs.readFileSync(file).toString()
    deserialized = {}

    currentLine = ""

    for i, line of contents.split /\r?\n/
      # Hashes and exclamation marks, no friends of mine.
      if /^\s*(!|#)+/.test line
        continue

      if line.length == 0
        continue

      currentLine += line.trim()

      if /(\\\\)*\\$/.test line
        currentLine = line.replace /\\$/, ''
      else
        matches = /^\s*((?:[^\s:=\\]|\\.)+)\s*[:=\s]\s*(.*)$/.exec currentLine
        deserialized[matches[1]] = matches[2]
        currentLine = ''

    return deserialized