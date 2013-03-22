ImageView = require 'image-view'
ImageEditSession = require 'image-edit-session'

describe "ImageView", ->
  [view, path] = []

  beforeEach ->
    path = project.resolve('binary-file.png')
    view = new ImageView()
    view.attachToDom()

  it "displays the image for a path", ->
    view.setModel(new ImageEditSession(path))
    expect(view.image.attr('src')).toBe path

  it "centers the image in the editor", ->
    imageLoaded = false
    view.image.load =>
      imageLoaded = true
    view.setModel(new ImageEditSession(path))

    waitsFor ->
      imageLoaded

    runs ->
      expect(view.image.width()).toBe 10
      expect(view.image.height()).toBe 10
      expect(view.image.css('margin-left')).toBe "-5px"
      expect(view.image.css('margin-top')).toBe "-5px"
