const { Emitter } = require('event-kit');
const Notification = require('../src/notification');

// Public: A notification manager used to create {Notification}s to be shown
// to the user.
//
// An instance of this class is always available as the `atom.notifications`
// global.
module.exports = class NotificationManager {
  constructor() {
    this.notifications = [];
    this.emitter = new Emitter();
  }

  /*
  Section: Events
  */

  // Public: Invoke the given callback after a notification has been added.
  //
  // * `callback` {Function} to be called after the notification is added.
  //   * `notification` The {Notification} that was added.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddNotification(callback) {
    return this.emitter.on('did-add-notification', callback);
  }

  // Public: Invoke the given callback after the notifications have been cleared.
  //
  // * `callback` {Function} to be called after the notifications are cleared.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidClearNotifications(callback) {
    return this.emitter.on('did-clear-notifications', callback);
  }

  /*
  Section: Adding Notifications
  */

  // Public: Add a success notification.
  //
  // * `message` A {String} message
  // * `options` (optional) An options {Object} with the following keys:
  //    * `buttons` (optional) An {Array} of {Object} where each {Object} has
  //      the following options:
  //      * `className` (optional) {String} a class name to add to the button's
  //        default class name (`btn btn-success`).
  //      * `onDidClick` (optional) {Function} callback to call when the button
  //        has been clicked. The context will be set to the
  //        {NotificationElement} instance.
  //      * `text` {String} inner text for the button
  //    * `description` (optional) A Markdown {String} containing a longer
  //      description about the notification. By default, this **will not**
  //      preserve newlines and whitespace when it is rendered.
  //    * `detail` (optional) A plain-text {String} containing additional
  //      details about the notification. By default, this **will** preserve
  //      newlines and whitespace when it is rendered.
  //    * `dismissable` (optional) A {Boolean} indicating whether this
  //      notification can be dismissed by the user. Defaults to `false`.
  //    * `icon` (optional) A {String} name of an icon from Octicons to display
  //      in the notification header. Defaults to `'check'`.
  //
  // Returns the {Notification} that was added.
  addSuccess(message, options) {
    return this.addNotification(new Notification('success', message, options));
  }

  // Public: Add an informational notification.
  //
  // * `message` A {String} message
  // * `options` (optional) An options {Object} with the following keys:
  //    * `buttons` (optional) An {Array} of {Object} where each {Object} has
  //      the following options:
  //      * `className` (optional) {String} a class name to add to the button's
  //        default class name (`btn btn-info`).
  //      * `onDidClick` (optional) {Function} callback to call when the button
  //        has been clicked. The context will be set to the
  //        {NotificationElement} instance.
  //      * `text` {String} inner text for the button
  //    * `description` (optional) A Markdown {String} containing a longer
  //      description about the notification. By default, this **will not**
  //      preserve newlines and whitespace when it is rendered.
  //    * `detail` (optional) A plain-text {String} containing additional
  //      details about the notification. By default, this **will** preserve
  //      newlines and whitespace when it is rendered.
  //    * `dismissable` (optional) A {Boolean} indicating whether this
  //      notification can be dismissed by the user. Defaults to `false`.
  //    * `icon` (optional) A {String} name of an icon from Octicons to display
  //      in the notification header. Defaults to `'info'`.
  //
  // Returns the {Notification} that was added.
  addInfo(message, options) {
    return this.addNotification(new Notification('info', message, options));
  }

  // Public: Add a warning notification.
  //
  // * `message` A {String} message
  // * `options` (optional) An options {Object} with the following keys:
  //    * `buttons` (optional) An {Array} of {Object} where each {Object} has
  //      the following options:
  //      * `className` (optional) {String} a class name to add to the button's
  //        default class name (`btn btn-warning`).
  //      * `onDidClick` (optional) {Function} callback to call when the button
  //        has been clicked. The context will be set to the
  //        {NotificationElement} instance.
  //      * `text` {String} inner text for the button
  //    * `description` (optional) A Markdown {String} containing a longer
  //      description about the notification. By default, this **will not**
  //      preserve newlines and whitespace when it is rendered.
  //    * `detail` (optional) A plain-text {String} containing additional
  //      details about the notification. By default, this **will** preserve
  //      newlines and whitespace when it is rendered.
  //    * `dismissable` (optional) A {Boolean} indicating whether this
  //      notification can be dismissed by the user. Defaults to `false`.
  //    * `icon` (optional) A {String} name of an icon from Octicons to display
  //      in the notification header. Defaults to `'alert'`.
  //
  // Returns the {Notification} that was added.
  addWarning(message, options) {
    return this.addNotification(new Notification('warning', message, options));
  }

  // Public: Add an error notification.
  //
  // * `message` A {String} message
  // * `options` (optional) An options {Object} with the following keys:
  //    * `buttons` (optional) An {Array} of {Object} where each {Object} has
  //      the following options:
  //      * `className` (optional) {String} a class name to add to the button's
  //        default class name (`btn btn-error`).
  //      * `onDidClick` (optional) {Function} callback to call when the button
  //        has been clicked. The context will be set to the
  //        {NotificationElement} instance.
  //      * `text` {String} inner text for the button
  //    * `description` (optional) A Markdown {String} containing a longer
  //      description about the notification. By default, this **will not**
  //      preserve newlines and whitespace when it is rendered.
  //    * `detail` (optional) A plain-text {String} containing additional
  //      details about the notification. By default, this **will** preserve
  //      newlines and whitespace when it is rendered.
  //    * `dismissable` (optional) A {Boolean} indicating whether this
  //      notification can be dismissed by the user. Defaults to `false`.
  //    * `icon` (optional) A {String} name of an icon from Octicons to display
  //      in the notification header. Defaults to `'flame'`.
  //    * `stack` (optional) A preformatted {String} with stack trace
  //      information describing the location of the error.
  //      Requires `detail` to be set.
  //
  // Returns the {Notification} that was added.
  addError(message, options) {
    return this.addNotification(new Notification('error', message, options));
  }

  // Public: Add a fatal error notification.
  //
  // * `message` A {String} message
  // * `options` (optional) An options {Object} with the following keys:
  //    * `buttons` (optional) An {Array} of {Object} where each {Object} has
  //      the following options:
  //      * `className` (optional) {String} a class name to add to the button's
  //        default class name (`btn btn-error`).
  //      * `onDidClick` (optional) {Function} callback to call when the button
  //        has been clicked. The context will be set to the
  //        {NotificationElement} instance.
  //      * `text` {String} inner text for the button
  //    * `description` (optional) A Markdown {String} containing a longer
  //      description about the notification. By default, this **will not**
  //      preserve newlines and whitespace when it is rendered.
  //    * `detail` (optional) A plain-text {String} containing additional
  //      details about the notification. By default, this **will** preserve
  //      newlines and whitespace when it is rendered.
  //    * `dismissable` (optional) A {Boolean} indicating whether this
  //      notification can be dismissed by the user. Defaults to `false`.
  //    * `icon` (optional) A {String} name of an icon from Octicons to display
  //      in the notification header. Defaults to `'bug'`.
  //    * `stack` (optional) A preformatted {String} with stack trace
  //      information describing the location of the error.
  //      Requires `detail` to be set.
  //
  // Returns the {Notification} that was added.
  addFatalError(message, options) {
    return this.addNotification(new Notification('fatal', message, options));
  }

  add(type, message, options) {
    return this.addNotification(new Notification(type, message, options));
  }

  addNotification(notification) {
    this.notifications.push(notification);
    this.emitter.emit('did-add-notification', notification);
    return notification;
  }

  /*
  Section: Getting Notifications
  */

  // Public: Get all the notifications.
  //
  // Returns an {Array} of {Notification}s.
  getNotifications() {
    return this.notifications.slice();
  }

  /*
  Section: Managing Notifications
  */

  // Public: Clear all the notifications.
  clear() {
    this.notifications = [];
    this.emitter.emit('did-clear-notifications');
  }
};
