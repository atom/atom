/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as assert from 'assert';
import { Event, Emitter, debounceEvent, EventBufferer, once, fromPromise, stopwatch, buffer, echo, EventMultiplexer, latch, AsyncEmitter, IWaitUntil } from 'vs/base/common/event';
import { IDisposable } from 'vs/base/common/lifecycle';
import * as Errors from 'vs/base/common/errors';
import { timeout } from 'vs/base/common/async';

namespace Samples {

	export class EventCounter {

		count = 0;

		reset() {
			this.count = 0;
		}

		onEvent() {
			this.count += 1;
		}
	}

	export class Document3 {

		private _onDidChange = new Emitter<string>();

		onDidChange: Event<string> = this._onDidChange.event;

		setText(value: string) {
			//...
			this._onDidChange.fire(value);
		}

	}
}

suite('Event', function () {

	const counter = new Samples.EventCounter();

	setup(() => counter.reset());

	test('Emitter plain', function () {

		let doc = new Samples.Document3();

		document.createElement('div').onclick = function () { };
		let subscription = doc.onDidChange(counter.onEvent, counter);

		doc.setText('far');
		doc.setText('boo');

		// unhook listener
		subscription.dispose();
		doc.setText('boo');
		assert.equal(counter.count, 2);
	});


	test('Emitter, bucket', function () {

		let bucket: IDisposable[] = [];
		let doc = new Samples.Document3();
		let subscription = doc.onDidChange(counter.onEvent, counter, bucket);

		doc.setText('far');
		doc.setText('boo');

		// unhook listener
		while (bucket.length) {
			bucket.pop().dispose();
		}

		// noop
		subscription.dispose();

		doc.setText('boo');
		assert.equal(counter.count, 2);
	});

	test('onFirstAdd|onLastRemove', () => {

		let firstCount = 0;
		let lastCount = 0;
		let a = new Emitter({
			onFirstListenerAdd() { firstCount += 1; },
			onLastListenerRemove() { lastCount += 1; }
		});

		assert.equal(firstCount, 0);
		assert.equal(lastCount, 0);

		let subscription = a.event(function () { });
		assert.equal(firstCount, 1);
		assert.equal(lastCount, 0);

		subscription.dispose();
		assert.equal(firstCount, 1);
		assert.equal(lastCount, 1);

		subscription = a.event(function () { });
		assert.equal(firstCount, 2);
		assert.equal(lastCount, 1);
	});

	test('throwingListener', () => {
		const origErrorHandler = Errors.errorHandler.getUnexpectedErrorHandler();
		Errors.setUnexpectedErrorHandler(() => null);

		try {
			let a = new Emitter();
			let hit = false;
			a.event(function () {
				throw 9;
			});
			a.event(function () {
				hit = true;
			});
			a.fire(undefined);
			assert.equal(hit, true);

		} finally {
			Errors.setUnexpectedErrorHandler(origErrorHandler);
		}
	});

	test('reusing event function and context', function () {
		let counter = 0;
		function listener() {
			counter += 1;
		}
		const context = {};

		let emitter = new Emitter();
		let reg1 = emitter.event(listener, context);
		let reg2 = emitter.event(listener, context);

		emitter.fire();
		assert.equal(counter, 2);

		reg1.dispose();
		emitter.fire();
		assert.equal(counter, 3);

		reg2.dispose();
		emitter.fire();
		assert.equal(counter, 3);
	});

	test('Debounce Event', function (done: () => void) {
		let doc = new Samples.Document3();

		let onDocDidChange = debounceEvent(doc.onDidChange, (prev: string[], cur) => {
			if (!prev) {
				prev = [cur];
			} else if (prev.indexOf(cur) < 0) {
				prev.push(cur);
			}
			return prev;
		}, 10);

		let count = 0;

		onDocDidChange(keys => {
			count++;
			assert.ok(keys, 'was not expecting keys.');
			if (count === 1) {
				doc.setText('4');
				assert.deepEqual(keys, ['1', '2', '3']);
			} else if (count === 2) {
				assert.deepEqual(keys, ['4']);
				done();
			}
		});

		doc.setText('1');
		doc.setText('2');
		doc.setText('3');
	});

	test('Debounce Event - leading', async function () {
		const emitter = new Emitter<void>();
		let debounced = debounceEvent(emitter.event, (l, e) => e, 0, /*leading=*/true);

		let calls = 0;
		debounced(() => {
			calls++;
		});

		// If the source event is fired once, the debounced (on the leading edge) event should be fired only once
		emitter.fire();

		await timeout(1);
		assert.equal(calls, 1);
	});

	test('Debounce Event - leading', async function () {
		const emitter = new Emitter<void>();
		let debounced = debounceEvent(emitter.event, (l, e) => e, 0, /*leading=*/true);

		let calls = 0;
		debounced(() => {
			calls++;
		});

		// If the source event is fired multiple times, the debounced (on the leading edge) event should be fired twice
		emitter.fire();
		emitter.fire();
		emitter.fire();
		await timeout(1);
		assert.equal(calls, 2);
	});

	test('Emitter - In Order Delivery', function () {
		const a = new Emitter<string>();
		const listener2Events: string[] = [];
		a.event(function listener1(event) {
			if (event === 'e1') {
				a.fire('e2');
				// assert that all events are delivered at this point
				assert.deepEqual(listener2Events, ['e1', 'e2']);
			}
		});
		a.event(function listener2(event) {
			listener2Events.push(event);
		});
		a.fire('e1');

		// assert that all events are delivered in order
		assert.deepEqual(listener2Events, ['e1', 'e2']);
	});
});

suite('AsyncEmitter', function () {

	test('event has waitUntil-function', async function () {

		interface E extends IWaitUntil {
			foo: boolean;
			bar: number;
		}

		let emitter = new AsyncEmitter<E>();

		emitter.event(e => {
			assert.equal(e.foo, true);
			assert.equal(e.bar, 1);
			assert.equal(typeof e.waitUntil, 'function');
		});

		emitter.fireAsync(thenables => ({
			foo: true,
			bar: 1,
			waitUntil(t: Thenable<void>) { thenables.push(t); }
		}));
		emitter.dispose();
	});

	test('sequential delivery', async function () {

		interface E extends IWaitUntil {
			foo: boolean;
		}

		let globalState = 0;
		let emitter = new AsyncEmitter<E>();

		emitter.event(e => {
			e.waitUntil(timeout(10).then(_ => {
				assert.equal(globalState, 0);
				globalState += 1;
			}));
		});

		emitter.event(e => {
			e.waitUntil(timeout(1).then(_ => {
				assert.equal(globalState, 1);
				globalState += 1;
			}));
		});

		await emitter.fireAsync(thenables => ({
			foo: true,
			waitUntil(t) {
				thenables.push(t);
			}
		}));
		assert.equal(globalState, 2);
	});

	test('sequential, in-order delivery', async function () {
		interface E extends IWaitUntil {
			foo: number;
		}
		let events: number[] = [];
		let done = false;
		let emitter = new AsyncEmitter<E>();

		// e1
		emitter.event(e => {
			e.waitUntil(timeout(10).then(async _ => {
				if (e.foo === 1) {
					await emitter.fireAsync(thenables => ({
						foo: 2,
						waitUntil(t) {
							thenables.push(t);
						}
					}));
					assert.deepEqual(events, [1, 2]);
					done = true;
				}
			}));
		});

		// e2
		emitter.event(e => {
			events.push(e.foo);
			e.waitUntil(timeout(7));
		});

		await emitter.fireAsync(thenables => ({
			foo: 1,
			waitUntil(t) {
				thenables.push(t);
			}
		}));
		assert.ok(done);
	});
});

suite('Event utils', () => {

	suite('EventBufferer', () => {

		test('should not buffer when not wrapped', () => {
			const bufferer = new EventBufferer();
			const counter = new Samples.EventCounter();
			const emitter = new Emitter<void>();
			const event = bufferer.wrapEvent(emitter.event);
			const listener = event(counter.onEvent, counter);

			assert.equal(counter.count, 0);
			emitter.fire();
			assert.equal(counter.count, 1);
			emitter.fire();
			assert.equal(counter.count, 2);
			emitter.fire();
			assert.equal(counter.count, 3);

			listener.dispose();
		});

		test('should buffer when wrapped', () => {
			const bufferer = new EventBufferer();
			const counter = new Samples.EventCounter();
			const emitter = new Emitter<void>();
			const event = bufferer.wrapEvent(emitter.event);
			const listener = event(counter.onEvent, counter);

			assert.equal(counter.count, 0);
			emitter.fire();
			assert.equal(counter.count, 1);

			bufferer.bufferEvents(() => {
				emitter.fire();
				assert.equal(counter.count, 1);
				emitter.fire();
				assert.equal(counter.count, 1);
			});

			assert.equal(counter.count, 3);
			emitter.fire();
			assert.equal(counter.count, 4);

			listener.dispose();
		});

		test('once', () => {
			const emitter = new Emitter<void>();

			let counter1 = 0, counter2 = 0, counter3 = 0;

			const listener1 = emitter.event(() => counter1++);
			const listener2 = once(emitter.event)(() => counter2++);
			const listener3 = once(emitter.event)(() => counter3++);

			assert.equal(counter1, 0);
			assert.equal(counter2, 0);
			assert.equal(counter3, 0);

			listener3.dispose();
			emitter.fire();
			assert.equal(counter1, 1);
			assert.equal(counter2, 1);
			assert.equal(counter3, 0);

			emitter.fire();
			assert.equal(counter1, 2);
			assert.equal(counter2, 1);
			assert.equal(counter3, 0);

			listener1.dispose();
			listener2.dispose();
		});
	});

	suite('fromPromise', () => {

		test('should emit when done', async () => {
			let count = 0;

			const event = fromPromise(Promise.resolve(null));
			event(() => count++);

			assert.equal(count, 0);

			await timeout(10);
			assert.equal(count, 1);
		});

		test('should emit when done - setTimeout', async () => {
			let count = 0;

			const promise = timeout(5);
			const event = fromPromise(promise);
			event(() => count++);

			assert.equal(count, 0);
			await promise;
			assert.equal(count, 1);
		});
	});

	suite('stopwatch', () => {

		test('should emit', () => {
			const emitter = new Emitter<void>();
			const event = stopwatch(emitter.event);

			return new Promise((c, e) => {
				event(duration => {
					try {
						assert(duration > 0);
					} catch (err) {
						e(err);
					}

					c(null);
				});

				setTimeout(() => emitter.fire(), 10);
			});
		});
	});

	suite('buffer', () => {

		test('should buffer events', () => {
			const result: number[] = [];
			const emitter = new Emitter<number>();
			const event = emitter.event;
			const bufferedEvent = buffer(event);

			emitter.fire(1);
			emitter.fire(2);
			emitter.fire(3);
			assert.deepEqual(result, []);

			const listener = bufferedEvent(num => result.push(num));
			assert.deepEqual(result, [1, 2, 3]);

			emitter.fire(4);
			assert.deepEqual(result, [1, 2, 3, 4]);

			listener.dispose();
			emitter.fire(5);
			assert.deepEqual(result, [1, 2, 3, 4]);
		});

		test('should buffer events on next tick', async () => {
			const result: number[] = [];
			const emitter = new Emitter<number>();
			const event = emitter.event;
			const bufferedEvent = buffer(event, true);

			emitter.fire(1);
			emitter.fire(2);
			emitter.fire(3);
			assert.deepEqual(result, []);

			const listener = bufferedEvent(num => result.push(num));
			assert.deepEqual(result, []);

			await timeout(10);
			emitter.fire(4);
			assert.deepEqual(result, [1, 2, 3, 4]);
			listener.dispose();
			emitter.fire(5);
			assert.deepEqual(result, [1, 2, 3, 4]);
		});

		test('should fire initial buffer events', () => {
			const result: number[] = [];
			const emitter = new Emitter<number>();
			const event = emitter.event;
			const bufferedEvent = buffer(event, false, [-2, -1, 0]);

			emitter.fire(1);
			emitter.fire(2);
			emitter.fire(3);
			assert.deepEqual(result, []);

			bufferedEvent(num => result.push(num));
			assert.deepEqual(result, [-2, -1, 0, 1, 2, 3]);
		});
	});

	suite('echo', () => {

		test('should echo events', () => {
			const result: number[] = [];
			const emitter = new Emitter<number>();
			const event = emitter.event;
			const echoEvent = echo(event);

			emitter.fire(1);
			emitter.fire(2);
			emitter.fire(3);
			assert.deepEqual(result, []);

			const listener = echoEvent(num => result.push(num));
			assert.deepEqual(result, [1, 2, 3]);

			emitter.fire(4);
			assert.deepEqual(result, [1, 2, 3, 4]);

			listener.dispose();
			emitter.fire(5);
			assert.deepEqual(result, [1, 2, 3, 4]);
		});

		test('should echo events for every listener', () => {
			const result1: number[] = [];
			const result2: number[] = [];
			const emitter = new Emitter<number>();
			const event = emitter.event;
			const echoEvent = echo(event);

			emitter.fire(1);
			emitter.fire(2);
			emitter.fire(3);
			assert.deepEqual(result1, []);
			assert.deepEqual(result2, []);

			const listener1 = echoEvent(num => result1.push(num));
			assert.deepEqual(result1, [1, 2, 3]);
			assert.deepEqual(result2, []);

			emitter.fire(4);
			assert.deepEqual(result1, [1, 2, 3, 4]);
			assert.deepEqual(result2, []);

			const listener2 = echoEvent(num => result2.push(num));
			assert.deepEqual(result1, [1, 2, 3, 4]);
			assert.deepEqual(result2, [1, 2, 3, 4]);

			emitter.fire(5);
			assert.deepEqual(result1, [1, 2, 3, 4, 5]);
			assert.deepEqual(result2, [1, 2, 3, 4, 5]);

			listener1.dispose();
			listener2.dispose();
			emitter.fire(6);
			assert.deepEqual(result1, [1, 2, 3, 4, 5]);
			assert.deepEqual(result2, [1, 2, 3, 4, 5]);
		});
	});

	suite('EventMultiplexer', () => {

		test('works', () => {
			const result: number[] = [];
			const m = new EventMultiplexer<number>();
			m.event(r => result.push(r));

			const e1 = new Emitter<number>();
			m.add(e1.event);

			assert.deepEqual(result, []);

			e1.fire(0);
			assert.deepEqual(result, [0]);
		});

		test('multiplexer dispose works', () => {
			const result: number[] = [];
			const m = new EventMultiplexer<number>();
			m.event(r => result.push(r));

			const e1 = new Emitter<number>();
			m.add(e1.event);

			assert.deepEqual(result, []);

			e1.fire(0);
			assert.deepEqual(result, [0]);

			m.dispose();
			assert.deepEqual(result, [0]);

			e1.fire(0);
			assert.deepEqual(result, [0]);
		});

		test('event dispose works', () => {
			const result: number[] = [];
			const m = new EventMultiplexer<number>();
			m.event(r => result.push(r));

			const e1 = new Emitter<number>();
			m.add(e1.event);

			assert.deepEqual(result, []);

			e1.fire(0);
			assert.deepEqual(result, [0]);

			e1.dispose();
			assert.deepEqual(result, [0]);

			e1.fire(0);
			assert.deepEqual(result, [0]);
		});

		test('mutliplexer event dispose works', () => {
			const result: number[] = [];
			const m = new EventMultiplexer<number>();
			m.event(r => result.push(r));

			const e1 = new Emitter<number>();
			const l1 = m.add(e1.event);

			assert.deepEqual(result, []);

			e1.fire(0);
			assert.deepEqual(result, [0]);

			l1.dispose();
			assert.deepEqual(result, [0]);

			e1.fire(0);
			assert.deepEqual(result, [0]);
		});

		test('hot start works', () => {
			const result: number[] = [];
			const m = new EventMultiplexer<number>();
			m.event(r => result.push(r));

			const e1 = new Emitter<number>();
			m.add(e1.event);
			const e2 = new Emitter<number>();
			m.add(e2.event);
			const e3 = new Emitter<number>();
			m.add(e3.event);

			e1.fire(1);
			e2.fire(2);
			e3.fire(3);
			assert.deepEqual(result, [1, 2, 3]);
		});

		test('cold start works', () => {
			const result: number[] = [];
			const m = new EventMultiplexer<number>();

			const e1 = new Emitter<number>();
			m.add(e1.event);
			const e2 = new Emitter<number>();
			m.add(e2.event);
			const e3 = new Emitter<number>();
			m.add(e3.event);

			m.event(r => result.push(r));

			e1.fire(1);
			e2.fire(2);
			e3.fire(3);
			assert.deepEqual(result, [1, 2, 3]);
		});

		test('late add works', () => {
			const result: number[] = [];
			const m = new EventMultiplexer<number>();

			const e1 = new Emitter<number>();
			m.add(e1.event);
			const e2 = new Emitter<number>();
			m.add(e2.event);

			m.event(r => result.push(r));

			e1.fire(1);
			e2.fire(2);

			const e3 = new Emitter<number>();
			m.add(e3.event);
			e3.fire(3);

			assert.deepEqual(result, [1, 2, 3]);
		});

		test('add dispose works', () => {
			const result: number[] = [];
			const m = new EventMultiplexer<number>();

			const e1 = new Emitter<number>();
			m.add(e1.event);
			const e2 = new Emitter<number>();
			m.add(e2.event);

			m.event(r => result.push(r));

			e1.fire(1);
			e2.fire(2);

			const e3 = new Emitter<number>();
			const l3 = m.add(e3.event);
			e3.fire(3);
			assert.deepEqual(result, [1, 2, 3]);

			l3.dispose();
			e3.fire(4);
			assert.deepEqual(result, [1, 2, 3]);

			e2.fire(4);
			e1.fire(5);
			assert.deepEqual(result, [1, 2, 3, 4, 5]);
		});
	});

	test('latch', () => {
		const emitter = new Emitter<number>();
		const event = latch(emitter.event);

		const result: number[] = [];
		const listener = event(num => result.push(num));

		assert.deepEqual(result, []);

		emitter.fire(1);
		assert.deepEqual(result, [1]);

		emitter.fire(2);
		assert.deepEqual(result, [1, 2]);

		emitter.fire(2);
		assert.deepEqual(result, [1, 2]);

		emitter.fire(1);
		assert.deepEqual(result, [1, 2, 1]);

		emitter.fire(1);
		assert.deepEqual(result, [1, 2, 1]);

		emitter.fire(3);
		assert.deepEqual(result, [1, 2, 1, 3]);

		emitter.fire(3);
		assert.deepEqual(result, [1, 2, 1, 3]);

		emitter.fire(3);
		assert.deepEqual(result, [1, 2, 1, 3]);

		listener.dispose();
	});
});
