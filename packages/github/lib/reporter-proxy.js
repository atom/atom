const pjson = require('../package.json');

export const FIVE_MINUTES_IN_MILLISECONDS = 1000 * 60 * 5;

// this class allows us to call reporter methods
// before the reporter is actually loaded, since we don't want to
// assume that the metrics package will load before the GitHub package.
class ReporterProxy {
  constructor() {
    this.reporter = null;
    this.events = [];
    this.timings = [];
    this.counters = [];
    this.gitHubPackageVersion = pjson.version;

    this.timeout = null;
  }

  // function that is called after the reporter is actually loaded, to
  // set the reporter and send any data that have accumulated while it was loading.
  setReporter(reporter) {
    this.reporter = reporter;

    this.events.forEach(customEvent => {
      this.reporter.addCustomEvent(customEvent.eventType, customEvent.event);
    });
    this.events = [];

    this.timings.forEach(timing => {
      this.reporter.addTiming(timing.eventType, timing.durationInMilliseconds, timing.metadata);
    });
    this.timings = [];

    this.counters.forEach(counterName => {
      this.reporter.incrementCounter(counterName);
    });
    this.counters = [];
  }

  incrementCounter(counterName) {
    if (this.reporter === null) {
      this.startTimer();
      this.counters.push(counterName);
      return;
    }

    this.reporter.incrementCounter(counterName);
  }

  addTiming(eventType, durationInMilliseconds, metadata = {}) {
    if (this.reporter === null) {
      this.startTimer();
      this.timings.push({eventType, durationInMilliseconds, metadata});
      return;
    }

    this.reporter.addTiming(eventType, durationInMilliseconds, metadata);
  }

  addEvent(eventType, event) {
    if (this.reporter === null) {
      this.startTimer();
      this.events.push({eventType, event});
      return;
    }

    this.reporter.addCustomEvent(eventType, event);
  }

  startTimer() {
    if (this.timeout !== null) {
      return;
    }

    // if for some reason a user disables the metrics package, we don't want to
    // just keep accumulating events in memory until the heat death of the universe.
    // Use a no-op class, clear all queues, move on with our lives.
    this.timeout = setTimeout(FIVE_MINUTES_IN_MILLISECONDS, () => {
      if (this.reporter === null) {
        this.setReporter(new FakeReporter());
        this.events = [];
        this.timings = [];
        this.counters = [];
      }
    });
  }
}

export const reporterProxy = new ReporterProxy();

export class FakeReporter {
  addCustomEvent() {}

  addTiming() {}

  incrementCounter() {}
}

export function incrementCounter(counterName) {
  reporterProxy.incrementCounter(counterName);
}

export function addTiming(eventType, durationInMilliseconds, metadata = {}) {
  metadata.gitHubPackageVersion = reporterProxy.gitHubPackageVersion;
  reporterProxy.addTiming(eventType, durationInMilliseconds, metadata);
}

export function addEvent(eventType, event) {
  event.gitHubPackageVersion = reporterProxy.gitHubPackageVersion;
  reporterProxy.addEvent(eventType, event);
}
