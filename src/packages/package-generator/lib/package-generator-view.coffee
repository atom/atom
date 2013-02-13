{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'

module.exports =
class PackageGeneratorView extends View
  previouslyFocusedElement: null

  @content: ->
    @div class: 'package-generator overlay from-top', =>
      @subview 'miniEditor', new Editor(mini: true)
      @div class: 'error', outlet: 'error'
      @div class: 'message', outlet: 'message'

  initialize: ->
    rootView.command "package-generator:generate", => @attach()
    @miniEditor.on 'focusout', => @detach()
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()

  attach: ->
    @previouslyFocusedElement = $(':focus')
    @message.text("Enter package path")
    placeholderName = "package-name"
    @miniEditor.setText(fs.join(config.userPackagesDirPath, placeholderName));
    pathLength = @miniEditor.getText().length
    @miniEditor.setSelectedBufferRange([[0, pathLength - placeholderName.length], [0, pathLength]])

    rootView.append(this)
    @miniEditor.focus()

  detach: ->
    return unless @hasParent()
    @previouslyFocusedElement?.focus()
    super

  confirm: ->
    if @validPackagePath()
      @createPackageFiles()
      atom.open(@getPackagePath())
      @detach()

  getPackagePath: ->
    packagePath = @miniEditor.getText()
    packageName = _.dasherize(fs.base(packagePath))
    fs.join(fs.directory(packagePath), packageName)

  validPackagePath: ->
    if fs.exists(@getPackagePath())
      @error.text("Path already exists at '#{@getPackagePath()}'")
      @error.show()
      false
    else
      true

  createPackageFiles: ->
    templatePath = require.resolve(fs.join("package-generator", "template"))
    packageName = fs.base(@getPackagePath())

    for path in fs.listTree(templatePath)
      relativePath = path.replace(templatePath, "")
      relativePath = relativePath.replace(/^\//, '')
      relativePath = @replacePackageNamePlaceholders(relativePath, packageName)

      sourcePath = fs.join(@getPackagePath(), relativePath)
      if fs.isDirectory(path)
        fs.makeTree(sourcePath)
      if fs.isFile(path)
        fs.makeTree(fs.directory(sourcePath))
        content = @replacePackageNamePlaceholders(fs.read(path), packageName)
        fs.write(sourcePath, content)

  replacePackageNamePlaceholders: (string, packageName) ->
    placeholderRegex = /##(?:(package-name)|([pP]ackageName)|(package_name))##/g
    string = string.replace placeholderRegex, (match, dash, camel, underscore) ->
      if dash
        _.dasherize(packageName)
      else if camel
        if /[a-z]/.test(camel[0])
          packageName = packageName[0].toLowerCase() + packageName[1...]
        else if /[A-Z]/.test(camel[0])
          packageName = packageName[0].toUpperCase() + packageName[1...]
        _.camelize(packageName)

      else if underscore
        _.underscore(packageName)
