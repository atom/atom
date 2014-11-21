Notification = require '../src/notification'

fdescribe "Notification", ->
  [notification] = []

  describe "::getIcon()", ->
    it "returns a default when no icon specified", ->
      notification = new Notification('error', 'message!')
      expect(notification.getIcon()).toBe 'flame'

    it "returns the icon specified", ->
      notification = new Notification('error', 'message!', icon: 'my-icon')
      expect(notification.getIcon()).toBe 'my-icon'
