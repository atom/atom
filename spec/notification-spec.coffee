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

  describe "dismissing notifications", ->
    describe "when the notfication is dismissable", ->
      it "calls a callback when the notification is dismissed", ->
        dismissedSpy = jasmine.createSpy()
        notification = new Notification('error', 'message', dismissable: true)
        notification.onDidDismiss dismissedSpy

        expect(notification.isDismissable()).toBe true
        expect(notification.isDismissed()).toBe false

        notification.dismiss()

        expect(dismissedSpy).toHaveBeenCalled()
        expect(notification.isDismissed()).toBe true

    describe "when the notfication is not dismissable", ->
      it "does nothing when ::dismiss() is called", ->
        dismissedSpy = jasmine.createSpy()
        notification = new Notification('error', 'message')
        notification.onDidDismiss dismissedSpy

        expect(notification.isDismissable()).toBe false
        expect(notification.isDismissed()).toBe true

        notification.dismiss()

        expect(dismissedSpy).not.toHaveBeenCalled()
        expect(notification.isDismissed()).toBe true
