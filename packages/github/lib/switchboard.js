import {Emitter} from 'event-kit';

/*
 * Register callbacks and construct Promises to wait for the next occurrence of specific events that occur throughout
 * the data refresh and rendering cycle.
 */
export default class Switchboard {
  constructor() {
    this.promises = new Map();
    this.emitter = new Emitter();
  }

  /*
   * Invoke a callback each time that a desired event is observed. Return a Disposable that can be used to
   * unsubscribe from events.
   *
   * In general, you should use the more specific `onDidXyz` methods.
   */
  onDid(eventName, callback) {
    return this.emitter.on(`did-${eventName}`, callback);
  }

  /*
   * Indicate that a named event has been observed, firing any callbacks and resolving any Promises that were created
   * for this event. Optionally provide a payload with more information.
   *
   * In general, you should prefer the more specific `didXyz()` methods.
   */
  did(eventName, payload) {
    this.emitter.emit(`did-${eventName}`, payload);
  }

  /*
   * Retrieve a Promise that will be resolved the next time a desired event is observed.
   *
   * In general, you should prefer the more specific `getXyzPromise()` methods.
   */
  getPromise(eventName) {
    const existing = this.promises.get(eventName);
    if (existing !== undefined) {
      return existing;
    }

    const created = new Promise((resolve, reject) => {
      const subscription = this.onDid(eventName, payload => {
        subscription.dispose();
        this.promises.delete(eventName);
        resolve(payload);
      });
    });
    this.promises.set(eventName, created);
    return created;
  }
}

[
  'UpdateRepository',
  'BeginStageOperation',
  'FinishStageOperation',
  'ChangePatch',
  'ScheduleActiveContextUpdate',
  'BeginActiveContextUpdate',
  'FinishActiveContextUpdate',
  'FinishRender',
  'FinishContextChangeRender',
  'FinishRepositoryRefresh',
].forEach(eventName => {
  Switchboard.prototype[`did${eventName}`] = function(payload) {
    this.did(eventName, payload);
  };

  Switchboard.prototype[`get${eventName}Promise`] = function() {
    return this.getPromise(eventName);
  };

  Switchboard.prototype[`onDid${eventName}`] = function(callback) {
    return this.onDid(eventName, callback);
  };
});
