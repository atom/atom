/** @babel */

export default class MarkerObservationWindow {
  constructor (decorationManager, bufferWindow) {
    this.decorationManager = decorationManager
    this.bufferWindow = bufferWindow
  }

  setScreenRange (range) {
    return this.bufferWindow.setRange(this.decorationManager.bufferRangeForScreenRange(range))
  }

  setBufferRange (range) {
    return this.bufferWindow.setRange(range)
  }

  destroy () {
    return this.bufferWindow.destroy()
  }
}
