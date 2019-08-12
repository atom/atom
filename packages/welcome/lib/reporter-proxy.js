/** @babel */

export default class ReporterProxy {
  constructor() {
    this.reporter = null;
    this.queue = [];
    this.eventType = 'welcome-v1';
  }

  setReporter(reporter) {
    this.reporter = reporter;
    let customEvent;

    while ((customEvent = this.queue.shift())) {
      this.reporter.addCustomEvent(this.eventType, customEvent);
    }
  }

  sendEvent(action, label, value) {
    const event = { ea: action, el: label, ev: value };
    if (this.reporter) {
      this.reporter.addCustomEvent(this.eventType, event);
    } else {
      this.queue.push(event);
    }
  }
}
