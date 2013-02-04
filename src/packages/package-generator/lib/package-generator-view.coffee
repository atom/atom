{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
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
    @miniEditor.focus()
    rootView.append(this)

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
    @miniEditor.getText()

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
      relativePath = relativePath.replace("__packageName__", packageName)

      sourcePath = fs.join(@getPackagePath(), relativePath)
      if fs.isDirectory(path)
        fs.makeTree(sourcePath)
      if fs.isFile(path)
        fs.makeTree(fs.directory(sourcePath))
        fs.write(sourcePath, fs.read(path))
