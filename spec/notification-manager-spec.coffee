NotificationManager = require '../src/notification-manager'

describe "NotificationManager", ->
  [manager] = []

  beforeEach ->
    manager = new NotificationManager

  describe "the atom global", ->
    it "has a notifications instance", ->
      expect(atom.notifications instanceof NotificationManager).toBe true

  describe "adding events", ->
    addSpy = null

    beforeEach ->
      addSpy = jasmine.createSpy()
      manager.onDidAddNotification(addSpy)

    it "emits an event when a notification has been added", ->
      manager.add('error', 'Some error!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()

      notification = addSpy.mostRecentCall.args[0]
      expect(notification.getType()).toBe 'error'
      expect(notification.getMessage()).toBe 'Some error!'
      expect(notification.getIcon()).toBe 'someIcon'

    it "emits a fatal error ::addFatalError has been called", ->
      manager.addFatalError('Some error!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      notification = addSpy.mostRecentCall.args[0]
      expect(notification.getType()).toBe 'fatal'

    it "emits an error ::addError has been called", ->
      manager.addError('Some error!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      notification = addSpy.mostRecentCall.args[0]
      expect(notification.getType()).toBe 'error'

    it "emits a warning notification ::addWarning has been called", ->
      manager.addWarning('Something!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      notification = addSpy.mostRecentCall.args[0]
      expect(notification.getType()).toBe 'warning'

    it "emits an info notification ::addInfo has been called", ->
      manager.addInfo('Something!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      notification = addSpy.mostRecentCall.args[0]
      expect(notification.getType()).toBe 'info'

    it "emits a success notification ::addSuccess has been called", ->
      manager.addSuccess('Something!', icon: 'someIcon')
      expect(addSpy).toHaveBeenCalled()
      notification = addSpy.mostRecentCall.args[0]
      expect(notification.getType()).toBe 'success'
