# cdoc is a bite sized library which scans CoffeeScript
# source code and returns a js object containing class, module
# and method names, along with the comments and line numbers
# associated with them.
#
# It pairs finely with TomDoc, but really doesn't care which
# documentation format you use. As long as your class, module, and
# method definitions are preceded by a comment, cdoc will do its job.
module.exports = cdoc =
  # Parses CoffeeScript source code into an object describing
  # the class names and modules defined therein. Method names,
  # comments, and line numbers are also included.
  #
  # text - The String CoffeeScript source code to parse into a js object.
  #
  # Returns an object like this:
  #
  #     [
  #       name: "App"
  #       comment:"Singleton object representing the application.",
  #       line: 5,
  #       methods: [
  #         name: "setTitle"
  #         signature: "setTitle: (title) ->"
  #         params: [
  #           name: "title"
  #         ]
  #         comment: "Sets the title of the app."
  #         line: 7
  #       ,
  #         name: "title"
  #         signature: "title: ->"
  #         params: []
  #         comment: "Returns the String title of the app."
  #         line: 11
  #       ]
  #       name: "class Robot"
  #       comment: "A Robot that can walk and talk, just like a real boy."
  #       line: 15
  #       methods: [
  #         name: "constructor"
  #         signature: "constructor: (path) ->"
  #         params: [
  #           name: "path"
  #         ]
  #         comment: "Robots receive messages from a..."
  #         line: 20
  #       ]
  #     ]
  #
  # In the above, App is an object while Robot is a class.
  parse: (text) ->
    scopes       = []
    lastComment  = ''
    methodIndent = null
    moduleIsFn   = false

    text.split("\n").forEach (line, lineno) =>
      return if moduleIsFn

      lineno++

      # Skip empty lines and lines containing only a comment symbol.
      return if not line.trim()

      # If this line is a comment, record it and move on.
      if line.trim()[0] is '#'
        lastComment += line.trim().match(/^\s*\#\s?(.*)$/)[1] + "\n"
        return

      # detect:
      # 1. module.exports = (params) ->
      # 2. module.exports = (params) =>
      if match = line.match /^\s*module.exports\s*=\s*((?:\((.+)\))?\s*(-|=)>)/
        moduleIsFn = true
        [ signature, params ] = match[1..2]
        params = for param in params?.split(',') or []
          { name: param.trim() }
        scopes.push
          name: 'module'
          signature: signature
          params: params
          comment: lastComment.trim()
          line: lineno

      # detect:
      # 1. module.exports =
      # 2. module.exports = MyModule =
      # 3. module.exports = class MyClass
      # 4. exports.MyClass = class MyClass
      else if match = line.match /^\s*(?:module.exports|exports\.[\w\.]+)\s*=\s*(?:(class [\w\.]+)(?:\s+extends [\w.]+)?|([\w\.]+)\s*=)\s*$/
        methodIndent = null
        scopes.push
          name: match[1] or match[2] or 'module'
          comment: lastComment.trim()
          line: lineno
          methods: []

      # detect: class Window
      else if newScope = line.match(/^\s*class ([\w\.]+)/)?[0]
        methodIndent = null
        scopes.push
          name: newScope
          comment: lastComment.trim()
          line: lineno
          methods: []

      # detect:
      # 1. hear: ->
      # 2. hear: (regex, args...) ->
      # 3. hear = ->
      # 4. hear = (regex, args...) ->
      # also detect `@hear` and `=>` forms of the above
      # as well as `exports.head = (regex, args...) ->` form
      else if match = line.match /^\s*(@|exports\.)?(([\w\.]+)\s*(:|=)\s*(?:\((.*?)\))?\s*(-|=)>)\s*/

        # If the indentation of this method is deeper than the
        # previous method definition, and we're still in the same
        # scope, bail out. Probably an inner function.
        indent = line.match(/^(\s*)/)[0].length
        return if methodIndent? and methodIndent < indent
        methodIndent = indent

        [ prefix, fn, name, type, params ] = match[1..-1]

        # floating function
        if type is '=' and prefix isnt 'exports.'
          return

        # Normalize the method signature.
        # 1. exports.method = (param) ->
        #    exports.method: (param) ->
        # 2. method: () ->
        #    method: ->
        fn = fn.trim()
        fn = fn.replace /\s+=\s+((\(|-|=))/, ': $1'
        fn = fn.replace /\s*\(\)/, ''

        params = for param in params?.split(',') or []
          { name: param.trim() }

        if prefix is 'exports.'
          modules = scopes.filter (scope) -> scope?.name is 'module'
          scope   = modules[0]

          if not scope
            scopes.push scope =
              name: 'module'
              comment: ""
              line: 0
              methods: []
        else
          scope = scopes[scopes.length - 1]

        scope.methods ?= []
        scope.methods.push
          name: name
          signature: fn
          params: params
          comment: lastComment.trim()
          line: lineno

      # Clear the last comment, we're done with it.
      lastComment = ''

    scopes
