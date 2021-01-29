const { Emitter } = require('event-kit');
const _ = require('underscore-plus');

// Public: A notification to the user containing a message and type.
module.exports = class Notification {
  constructor(type, message, options = {}) {
    this.type = type;
    this.message = message;
    this.options = options;
    this.emitter = new Emitter();
    this.timestamp = new Date();
    this.dismissed = true;
    if (this.isDismissable()) this.dismissed = false;
    this.displayed = false;
    this.validate();
  }

  validate() {
    if (typeof this.message !== 'string') {
      throw new Error(
        `Notification must be created with string message: ${this.message}`
      );
    }

    if (!_.isObject(this.options) || Array.isArray(this.options)) {
      throw new Error(
        `Notification must be created with an options object: ${this.options}`
      );
    }
  }

  /*
  Section: Event Subscription
  */

  // Public: Invoke the given callback when the notification is dismissed.
  //
  // * `callback` {Function} to be called when the notification is dismissed.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDismiss(callback) {
    return this.emitter.on('did-dismiss', callback);
  }

  // Public: Invoke the given callback when the notification is displayed.
  //
  // * `callback` {Function} to be called when the notification is displayed.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDisplay(callback) {
    return this.emitter.on('did-display', callback);
  }

  getOptions() {
    return this.options;
  }

  /*
  Section: Methods
  */

  // Public: Returns the {String} type.
  getType() {
    return this.type;
  }

  // Public: Returns the {String} message.
  getMessage() {
    return this.message;
  }

  getTimestamp() {
    return this.timestamp;
  }

  getDetail() {
    return this.options.detail;
  }

  isEqual(other) {
    return (
      this.getMessage() === other.getMessage() &&
      this.getType() === other.getType() &&
      this.getDetail() === other.getDetail()
    );
  }

  // Extended: Dismisses the notification, removing it from the UI. Calling this
  // programmatically will call all callbacks added via `onDidDismiss`.
  dismiss() {
    if (!this.isDismissable() || this.isDismissed()) return;
    this.dismissed = true;
    this.emitter.emit('did-dismiss', this);
  }

  isDismissed() {
    return this.dismissed;
  }

  isDismissable() {
    return !!this.options.dismissable;
  }

  wasDisplayed() {
    return this.displayed;
  }

  setDisplayed(displayed) {
    this.displayed = displayed;
    this.emitter.emit('did-display', this);
  }

  getIcon() {
    if (this.options.icon != null) return this.options.icon;
    switch (this.type) {
      case 'fatal':
        return 'bug';
      case 'error':
        return 'flame';
      case 'warning':
        return 'alert';
      case 'info':
        return 'info';
      case 'success':
        return 'check';
    }
  }
};
