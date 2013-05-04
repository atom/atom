require 'underscore-extensions'
_ = require 'underscore'
fs = require 'fs'
fsUtils = require 'fs-utils'

module.exports =
  isObjectPath: (path) ->
    extension = fsUtils.extension(path)
    extension is '.cson' or extension is '.json'

  readObject: (path) ->
    @parseObject(path, fsUtils.read(path))

  readObjectAsync: (path, done) ->
    fs.readFile path, 'utf8', (err, contents) =>
      return done(err) if err?
      try
        done(null, @parseObject(path, contents))
      catch err
        done(err)

  parseObject: (path, contents) ->
    if fsUtils.extension(path) is '.cson'
      CoffeeScript = require 'coffee-script'
      CoffeeScript.eval(contents, bare: true)
    else
      JSON.parse(contents)

  writeObject: (path, object) ->
    if fsUtils.extension(path) is '.cson'
      content = @stringify(object)
    else
      content = JSON.stringify(object, undefined, 2)
    fsUtils.write(path, "#{content}\n")

  stringifyIndent: (level=0) -> _.multiplyString(' ', Math.max(level, 0))

  stringifyString: (string) ->
    string = JSON.stringify(string)
    string = string[1...-1]               # Remove surrounding double quotes
    string = string.replace(/\\"/g, '"')  # Unescape escaped double quotes
    string = string.replace(/'/g, '\\\'') # Escape single quotes
    "'#{string}'"                         # Wrap in single quotes

  stringifyBoolean: (boolean) -> "#{boolean}"

  stringifyNumber: (number) -> "#{number}"

  stringifyNull: -> 'null'

  stringifyArray: (array, indentLevel=0) ->
    return '[]' if array.length is 0

    cson = '[\n'
    for value in array
      indent = @stringifyIndent(indentLevel + 2)
      cson += indent
      if _.isString(value)
        cson += @stringifyString(value)
      else if _.isBoolean(value)
        cson += @stringifyBoolean(value)
      else if _.isNumber(value)
        cson += @stringifyNumber(value)
      else if _.isNull(value) or value is undefined
        cson += @stringifyNull(value)
      else if _.isArray(value)
        cson += @stringifyArray(value, indentLevel + 2)
      else if _.isObject(value)
        cson += "{\n#{@stringifyObject(value, indentLevel + 4)}\n#{indent}}"
      else
        throw new Error("Unrecognized type for array value: #{value}")
      cson += '\n'
    "#{cson}#{@stringifyIndent(indentLevel)}]"

  stringifyObject: (object, indentLevel=0) ->
    return '{}' if _.isEmpty(object)

    cson = ''
    prefix = ''
    for key, value of object
      continue if value is undefined
      if _.isFunction(value)
        throw new Error("Function specified as value to key: #{key}")

      cson += "#{prefix}#{@stringifyIndent(indentLevel)}'#{key}':"
      if _.isString(value)
        cson += " #{@stringifyString(value)}"
      else if _.isBoolean(value)
        cson += " #{@stringifyBoolean(value)}"
      else if _.isNumber(value)
        cson += " #{@stringifyNumber(value)}"
      else if _.isNull(value)
        cson += " #{@stringifyNull(value)}"
      else if _.isArray(value)
        cson += " #{@stringifyArray(value, indentLevel)}"
      else if _.isObject(value)
        if _.isEmpty(value)
          cson += ' {}'
        else
          cson += "\n#{@stringifyObject(value, indentLevel + 2)}"
      else
        throw new Error("Unrecognized value type for key: #{key} with value: #{value}")
      prefix = '\n'
    cson

  stringify: (object) ->
    throw new Error("Cannot stringify undefined object") if object is undefined
    throw new Error("Cannot stringify function: #{object}") if _.isFunction(object)

    return @stringifyString(object) if _.isString(object)
    return @stringifyBoolean(object) if _.isBoolean(object)
    return @stringifyNumber(object) if _.isNumber(object)
    return @stringifyNull(object) if _.isNull(object)
    return @stringifyArray(object) if _.isArray(object)
    return @stringifyObject(object) if _.isObject(object)

    throw new Error("Unrecognized type to stringify: #{object}")
