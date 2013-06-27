SettingsPanel = require '../lib/settings-panel'
Editor = require 'editor'

describe "SettingsPanel", ->
  panel = null

  getValueForId = (id) ->
    element = panel.find("##{id.replace('.', '\\.')}")
    if element.is("input")
      element.attr('checked')?
    else
      element.view().getText()

  setValueForId = (id, value) ->
    element = panel.find("##{id.replace('.', '\\.')}")
    if element.is("input")
      element.attr('checked', if value then 'checked' else '')
      element.change()
    else
      element.view().setText(value?.toString())
      window.advanceClock(10000) # wait for contents-modified to be triggered


  beforeEach ->
    config.set('foo.int', 22)
    config.set('foo.float', 0.1)
    config.set('foo.boolean', true)
    config.set('foo.string', 'hey')

    panel = new SettingsPanel()
    spyOn(panel, "showSettings").andCallThrough()
    window.advanceClock(10000)
    waitsFor ->
      panel.showSettings.callCount > 0

  it "automatically binds named fields to their corresponding config keys", ->
    expect(getValueForId('foo.int')).toBe '22'
    expect(getValueForId('foo.float')).toBe '0.1'
    expect(getValueForId('foo.boolean')).toBeTruthy()
    expect(getValueForId('foo.string')).toBe 'hey'

    config.set('foo.int', 222)
    config.set('foo.float', 0.11)
    config.set('foo.boolean', false)
    config.set('foo.string', 'hey again')
    expect(getValueForId('foo.int')).toBe '222'
    expect(getValueForId('foo.float')).toBe '0.11'
    expect(getValueForId('foo.boolean')).toBeFalsy()
    expect(getValueForId('foo.string')).toBe 'hey again'

    setValueForId('foo.int', 90)
    setValueForId('foo.float', 89.2)
    setValueForId('foo.string', "oh hi")
    setValueForId('foo.boolean', true)
    expect(config.get('foo.int')).toBe 90
    expect(config.get('foo.float')).toBe 89.2
    expect(config.get('foo.boolean')).toBe true
    expect(config.get('foo.string')).toBe 'oh hi'

    setValueForId('foo.int', '')
    setValueForId('foo.float', '')
    setValueForId('foo.string', '')
    expect(config.get('foo.int')).toBeUndefined()
    expect(config.get('foo.float')).toBeUndefined()
    expect(config.get('foo.string')).toBeUndefined()

  it "does not save the config value until it has been changed to a new value", ->
    observeHandler = jasmine.createSpy("observeHandler")
    config.observe "foo.int", observeHandler
    observeHandler.reset()

    window.advanceClock(10000) # wait for contents-modified to be triggered
    expect(observeHandler).not.toHaveBeenCalled()

    setValueForId('foo.int', 2)
    expect(observeHandler).toHaveBeenCalled()
    observeHandler.reset()

    setValueForId('foo.int', 2)
    expect(observeHandler).not.toHaveBeenCalled()
