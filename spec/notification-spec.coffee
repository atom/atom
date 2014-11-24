Notification = require '../src/notification'

describe "Notification", ->
  [notification] = []

  describe "::getTimestamp()", ->
    it "returns a Date object", ->
      notification = new Notification('error', 'message!')
      expect(notification.getTimestamp() instanceof Date).toBe true

  describe "::getIcon()", ->
    it "returns a default when no icon specified", ->
      notification = new Notification('error', 'message!')
      expect(notification.getIcon()).toBe 'flame'

    it "returns the icon specified", ->
      notification = new Notification('error', 'message!', icon: 'my-icon')
      expect(notification.getIcon()).toBe 'my-icon'
