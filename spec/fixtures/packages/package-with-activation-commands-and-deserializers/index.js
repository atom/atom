module.exports = {
  activateCallCount: 0,
  activationCommandCallCount: 0,

  initialize() {},
  activate () {
    this.activateCallCount++

    atom.commands.add('atom-workspace', 'activation-command-2', () => this.activationCommandCallCount++)
  },

  deserializeMethod1 (state) {
    return {
      wasDeserializedBy: 'deserializeMethod1',
      state: state
    }
  },

  deserializeMethod2 (state) {
    return {
      wasDeserializedBy: 'deserializeMethod2',
      state: state
    }
  }
}
