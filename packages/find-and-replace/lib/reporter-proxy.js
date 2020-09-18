module.exports = class ReporterProxy {
  constructor () {
    this.reporter = null
    this.timingsQueue = []

     this.eventType = 'find-and-replace-v1'
  }

   setReporter (reporter) {
    this.reporter = reporter
    let timingsEvent

     while ((timingsEvent = this.timingsQueue.shift())) {
      this.reporter.addTiming(this.eventType, timingsEvent.duration, timingsEvent.metadata)
    }
  }

   unsetReporter () {
    delete this.reporter
  }

   sendSearchEvent (duration, numResults, crawler) {
    const metadata = {
      ec: 'time-to-search',
      ev: numResults,
      el: crawler
    }

     this._addTiming(duration, metadata)
  }

   _addTiming (duration, metadata) {
    if (this.reporter) {
      this.reporter.addTiming(this.eventType, duration, metadata)
    } else {
      this.timingsQueue.push({duration, metadata})
    }
  }
}
