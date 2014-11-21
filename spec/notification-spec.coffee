Notification = require '../src/notification'

describe "Notification", ->
  [notification] = []

  describe "::getIcon()", ->
    it "returns a default when no icon specified", ->
      notification = new Notification('error', 'message!')
      expect(notification.getIcon()).toBe 'bug'

    it "returns the icon specified", ->
      notification = new Notification('error', 'message!', icon: 'my-icon')
      expect(notification.getIcon()).toBe 'my-icon'
