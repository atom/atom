MessageManager = require '../src/message-manager'
{$} = require '../src/space-pen-extensions'

fdescribe "MessageManager", ->
  [manager] = []

  beforeEach ->
    manager = new MessageManager

  describe "the atom global", ->
    it "has a messages instance", ->
      expect(atom.messages instanceof MessageManager).toBe true

  describe "adding events", ->
    addSpy = null

    beforeEach ->
      addSpy = jasmine.createSpy()
      manager.onDidAddMessage(addSpy)

    it "emits an event when a message has been added", ->
      manager.add('error', 'Some error!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()

      message = addSpy.mostRecentCall.args[0]
      expect(message.getType()).toBe 'error'
      expect(message.getMessage()).toBe 'Some error!'
      expect(message.getIcon()).toBe 'someIcon'

    it "emits a fatal error ::addFatalError has been called", ->
      manager.addFatalError('Some error!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      message = addSpy.mostRecentCall.args[0]
      expect(message.getType()).toBe 'fatal'

    it "emits an error ::addError has been called", ->
      manager.addError('Some error!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      message = addSpy.mostRecentCall.args[0]
      expect(message.getType()).toBe 'error'

    it "emits a warning message ::addWarning has been called", ->
      manager.addWarning('Something!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      message = addSpy.mostRecentCall.args[0]
      expect(message.getType()).toBe 'warning'

    it "emits an info message ::addInfo has been called", ->
      manager.addInfo('Something!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      message = addSpy.mostRecentCall.args[0]
      expect(message.getType()).toBe 'info'

    it "emits a success message ::addSuccess has been called", ->
      manager.addSuccess('Something!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      message = addSpy.mostRecentCall.args[0]
      expect(message.getType()).toBe 'success'
