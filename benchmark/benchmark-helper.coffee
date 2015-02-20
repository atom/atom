require '../spec/spec-helper'

path = require 'path'
{$} = require '../src/space-pen-extensions'
{Point} = require 'atom'
_ = require 'underscore-plus'
fs = require 'fs-plus'
Project = require '../src/project'
TokenizedBuffer = require '../src/tokenized-buffer'

defaultCount = 100
window.pbenchmark = (args...) -> window.benchmark(args..., profile: true)
window.fbenchmark = (args...) -> window.benchmark(args..., focused: true)
window.fpbenchmark = (args...) -> window.benchmark(args..., profile: true, focused: true)
window.pfbenchmark = window.fpbenchmark

window.benchmarkFixturesProject = new Project(path.join(__dirname, 'fixtures'))

beforeEach ->
  window.project = window.benchmarkFixturesProject
  jasmine.unspy(window, 'setTimeout')
  jasmine.unspy(window, 'clearTimeout')
  jasmine.unspy(TokenizedBuffer::, 'tokenizeInBackground')

window.benchmark = (args...) ->
  description = args.shift()
  if typeof args[0] is 'number'
    count = args.shift()
  else
    count = defaultCount
  [fn, options] = args
  { profile, focused } = (options ? {})

  method = if focused then fit else it
  method description, ->
    total = measure ->
      console.profile(description) if profile
      _.times count, fn
      console.profileEnd(description) if profile
    avg = total / count

    fullname = @getFullName().replace(/\s|\.$/g, "")
    report = "#{fullname}: #{total} / #{count} = #{avg}ms"
    console.log(report)

    if atom.getLoadSettings().exitWhenDone
      url = "https://github.com/_stats"
      data = [type: 'timing', metric: "atom.#{fullname}", ms: avg]
      $.ajax url,
        async: false
        data: JSON.stringify(data)
        error: (args...) ->
          console.log "Failed to send atom.#{fullname}\n#{JSON.stringify(args)}"

window.measure = (fn) ->
  start = new Date().getTime()
  fn()
  new Date().getTime() - start

window.waitsForPromise = (fn) ->
  window.waitsFor (moveOn) ->
    fn().done(moveOn)

window.keyIdentifierForKey = (key) ->
  if key.length > 1 # named key
    key
  else
    charCode = key.toUpperCase().charCodeAt(0)
    "U+00" + charCode.toString(16)

window.keydownEvent = (key, properties={}) ->
  $.Event "keydown", _.extend({originalEvent: { keyIdentifier: keyIdentifierForKey(key) }}, properties)

window.clickEvent = (properties={}) ->
  $.Event "click", properties

window.mouseEvent = (type, properties) ->
  if properties.point
    {point, editorView} = properties
    {top, left} = @pagePixelPositionForPoint(editorView, point)
    properties.pageX = left + 1
    properties.pageY = top + 1
  properties.originalEvent ?= {detail: 1}
  $.Event type, properties

window.mousedownEvent = (properties={}) ->
  window.mouseEvent('mousedown', properties)

window.mousemoveEvent = (properties={}) ->
  window.mouseEvent('mousemove', properties)

window.pagePixelPositionForPoint = (editorView, point) ->
  point = Point.fromObject point
  top = editorView.lines.offset().top + point.row * editorView.lineHeight
  left = editorView.lines.offset().left + point.column * editorView.charWidth - editorView.lines.scrollLeft()
  { top, left }

window.seteditorViewWidthInChars = (editorView, widthInChars, charWidth=editorView.charWidth) ->
  editorView.width(charWidth * widthInChars + editorView.lines.position().left)

$.fn.resultOfTrigger = (type) ->
  event = $.Event(type)
  this.trigger(event)
  event.result

$.fn.enableKeymap = ->
  @on 'keydown', (e) -> window.keymap.handleKeyEvent(e)

$.fn.attachToDom = ->
  $('#jasmine-content').append(this)

$.fn.textInput = (data) ->
  event = document.createEvent 'TextEvent'
  event.initTextEvent('textInput', true, true, window, data)
  this.each -> this.dispatchEvent(event)
