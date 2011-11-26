# tdoc is a bite sized library for generating HTML documentation
# from CoffeeScript source code and Markdown files.
#
# It pairs finely with TomDoc, but really doesn't care which
# documentation format you use. As long as your class, module, and
# method definitions are preceded by a comment, tdoc will do its job.

File = require 'fs'
cdoc = require './cdoc'
hbar = require 'handlebars'
require './helpers'

# The tdoc module is our main interface. Using it we can turn CoffeeScript
# or Markdown into HTML using a template.
module.exports = tdoc =
  # Theme to use. Set using setTheme()
  theme: 'default'

  # Turns code into HTML docs.
  #
  # code - String of source code.
  # options -
  #   path: The path to the file this code is from.
  #
  # Returns a String of HTML.
  html: (code, options={}) ->
    options.path ?= ''
    options.paths = options.paths ? []
    options.sourceURL = "https://github.com/github/hubot/tree/master/"
    options.code = code

    if /\.(md|markdown|mdown|txt)$/.test options.path
      @render @template('markdown'), options

    else if options.path is '' or /\.coffee$/.test options.path
      context = cdoc.parse code
      context[key] = value for key, value of options
      @render @template(), context

    else
      "Don't know how to parse #{options.path}."

  # Sets the current theme.
  #
  # theme - String name of the theme you want to use.
  #
  # Returns nothing.
  setTheme: (name) ->
    @theme = name

  # Finds a template.
  #
  # name - String name of the template you want.
  #
  # Returns a String template
  template: (name='module') ->
    # lame require.resolve hack :(
    layout = @read require.resolve "docs/themes/#{@theme}/layout.html"
    file   = @read require.resolve "docs/themes/#{@theme}/#{name}.html"
    layout.replace /{{{\s*yield\s*}}}/, file

  # Renders a template using Handlebars.js.
  #
  # template - String template to render.
  # context - Object to use as context of the template.
  #
  # Returns the fully rendered template.
  render: (template, context) ->
    compiled = hbar.compile template
    compiled context

  # Reads a file synchronously using either CommonJS or node.
  #
  # path - String path to the file you want to read.
  # encoding - String encoding to use when reading the file.
  #
  # Returns a String.
  read: (path, encoding="utf8") ->
    if File.readFileSync?
      File.readFileSync path, encoding
    else if File.read?
      File.read path
