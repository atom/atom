module.exports = {
  initialize() {},
  activate () {},

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
