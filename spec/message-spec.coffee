Message = require '../src/message'

describe "Message", ->
  [message] = []

  describe "::getIcon()", ->
    it "returns a default when no icon specified", ->
      message = new Message('error', 'message!')
      expect(message.getIcon()).toBe 'bug'

    it "returns the icon specified", ->
      message = new Message('error', 'message!', icon: 'my-icon')
      expect(message.getIcon()).toBe 'my-icon'
