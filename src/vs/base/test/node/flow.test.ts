/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as flow from 'vs/base/node/flow';

const loop = flow.loop;
const sequence = flow.sequence;
const parallel = flow.parallel;

suite('Flow', () => {
	function assertCounterEquals(counter: number, expected: number): void {
		assert.ok(counter === expected, 'Expected ' + expected + ' assertions, but got ' + counter);
	}

	function syncThrowsError(callback: any): void {
		callback(new Error('foo'), null);
	}

	function syncSequenceGetThrowsError(value: any, callback: any) {
		sequence(
			function onError(error) {
				callback(error, null);
			},

			function getFirst(this: any) {
				syncThrowsError(this);
			},

			function handleFirst(first: number) {
				//Foo
			}
		);
	}

	function syncGet(value: any, callback: any): void {
		callback(null, value);
	}

	function syncGetError(value: any, callback: any): void {
		callback(new Error(''), null);
	}

	function asyncGet(value: any, callback: any): void {
		process.nextTick(function () {
			callback(null, value);
		});
	}

	function asyncGetError(value: any, callback: any): void {
		process.nextTick(function () {
			callback(new Error(''), null);
		});
	}

	test('loopSync', function (done: () => void) {
		const elements = ['1', '2', '3'];
		loop(elements, function (element, callback, index, total) {
			assert.ok(index === 0 || index === 1 || index === 2);
			assert.deepEqual(3, total);
			callback(null, element);
		}, function (error, result) {
			assert.equal(error, null);
			assert.deepEqual(result, elements);

			done();
		});
	});

	test('loopByFunctionSync', function (done: () => void) {
		const elements = function (callback: Function) {
			callback(null, ['1', '2', '3']);
		};

		loop(elements, function (element, callback) {
			callback(null, element);
		}, function (error, result) {
			assert.equal(error, null);
			assert.deepEqual(result, ['1', '2', '3']);

			done();
		});
	});

	test('loopByFunctionAsync', function (done: () => void) {
		const elements = function (callback: Function) {
			process.nextTick(function () {
				callback(null, ['1', '2', '3']);
			});
		};

		loop(elements, function (element, callback) {
			callback(null, element);
		}, function (error, result) {
			assert.equal(error, null);
			assert.deepEqual(result, ['1', '2', '3']);

			done();
		});
	});

	test('loopSyncErrorByThrow', function (done: () => void) {
		const elements = ['1', '2', '3'];
		loop(elements, function (element, callback) {
			if (element === '2') {
				throw new Error('foo');
			} else {
				callback(null, element);
			}
		}, function (error, result) {
			assert.ok(error);
			assert.ok(!result);

			done();
		});
	});

	test('loopSyncErrorByCallback', function (done: () => void) {
		const elements = ['1', '2', '3'];
		loop(elements, function (element, callback) {
			if (element === '2') {
				callback(new Error('foo'), null);
			} else {
				callback(null, element);
			}
		}, function (error, result) {
			assert.ok(error);
			assert.ok(!result);

			done();
		});
	});

	test('loopAsync', function (done: () => void) {
		const elements = ['1', '2', '3'];
		loop(elements, function (element, callback) {
			process.nextTick(function () {
				callback(null, element);
			});
		}, function (error, result) {
			assert.equal(error, null);
			assert.deepEqual(result, elements);

			done();
		});
	});

	test('loopAsyncErrorByCallback', function (done: () => void) {
		const elements = ['1', '2', '3'];
		loop(elements, function (element, callback) {
			process.nextTick(function () {
				if (element === '2') {
					callback(new Error('foo'), null);
				} else {
					callback(null, element);
				}
			});
		}, function (error, result) {
			assert.ok(error);
			assert.ok(!result);

			done();
		});
	});

	test('sequenceSync', function (done: () => void) {
		let assertionCount = 0;
		let errorCount = 0;

		sequence(
			function onError(error) {
				errorCount++;
			},

			function getFirst(this: any) {
				syncGet('1', this);
			},

			function handleFirst(this: any, first: number) {
				assert.deepEqual('1', first);
				assertionCount++;
				syncGet('2', this);
			},

			function handleSecond(this: any, second: any) {
				assert.deepEqual('2', second);
				assertionCount++;
				syncGet(null, this);
			},

			function handleThird(third: any) {
				assert.ok(!third);
				assertionCount++;

				assertCounterEquals(assertionCount, 3);
				assertCounterEquals(errorCount, 0);
				done();
			}
		);
	});

	test('sequenceAsync', function (done: () => void) {
		let assertionCount = 0;
		let errorCount = 0;

		sequence(
			function onError(error) {
				errorCount++;
			},

			function getFirst(this: any) {
				asyncGet('1', this);
			},

			function handleFirst(this: any, first: number) {
				assert.deepEqual('1', first);
				assertionCount++;
				asyncGet('2', this);
			},

			function handleSecond(this: any, second: number) {
				assert.deepEqual('2', second);
				assertionCount++;
				asyncGet(null, this);
			},

			function handleThird(third: number) {
				assert.ok(!third);
				assertionCount++;

				assertCounterEquals(assertionCount, 3);
				assertCounterEquals(errorCount, 0);
				done();
			}
		);
	});

	test('sequenceSyncErrorByThrow', function (done: () => void) {
		let assertionCount = 0;
		let errorCount = 0;

		sequence(
			function onError(error) {
				errorCount++;

				assertCounterEquals(assertionCount, 1);
				assertCounterEquals(errorCount, 1);
				done();
			},

			function getFirst(this: any) {
				syncGet('1', this);
			},

			function handleFirst(this: any, first: number) {
				assert.deepEqual('1', first);
				assertionCount++;
				syncGet('2', this);
			},

			function handleSecond(second: number) {
				if (true) {
					throw new Error('');
				}
				// assertionCount++;
				// syncGet(null, this);
			},

			function handleThird(third: number) {
				throw new Error('We should not be here');
			}
		);
	});

	test('sequenceSyncErrorByCallback', function (done: () => void) {
		let assertionCount = 0;
		let errorCount = 0;

		sequence(
			function onError(error) {
				errorCount++;

				assertCounterEquals(assertionCount, 1);
				assertCounterEquals(errorCount, 1);
				done();
			},

			function getFirst(this: any) {
				syncGet('1', this);
			},

			function handleFirst(this: any, first: number) {
				assert.deepEqual('1', first);
				assertionCount++;
				syncGetError('2', this);
			},

			function handleSecond(second: number) {
				throw new Error('We should not be here');
			}
		);
	});

	test('sequenceAsyncErrorByThrow', function (done: () => void) {
		let assertionCount = 0;
		let errorCount = 0;

		sequence(
			function onError(error) {
				errorCount++;

				assertCounterEquals(assertionCount, 1);
				assertCounterEquals(errorCount, 1);
				done();
			},

			function getFirst(this: any) {
				asyncGet('1', this);
			},

			function handleFirst(this: any, first: number) {
				assert.deepEqual('1', first);
				assertionCount++;
				asyncGet('2', this);
			},

			function handleSecond(second: number) {
				if (true) {
					throw new Error('');
				}
				// assertionCount++;
				// asyncGet(null, this);
			},

			function handleThird(third: number) {
				throw new Error('We should not be here');
			}
		);
	});

	test('sequenceAsyncErrorByCallback', function (done: () => void) {
		let assertionCount = 0;
		let errorCount = 0;

		sequence(
			function onError(error) {
				errorCount++;

				assertCounterEquals(assertionCount, 1);
				assertCounterEquals(errorCount, 1);
				done();
			},

			function getFirst(this: any) {
				asyncGet('1', this);
			},

			function handleFirst(this: any, first: number) {
				assert.deepEqual('1', first);
				assertionCount++;
				asyncGetError('2', this);
			},

			function handleSecond(second: number) {
				throw new Error('We should not be here');
			}
		);
	});

	test('syncChainedSequenceError', function (done: () => void) {
		sequence(
			function onError(error) {
				done();
			},

			function getFirst(this: any) {
				syncSequenceGetThrowsError('1', this);
			}
		);
	});

	test('tolerateBooleanResults', function (done: () => void) {
		let assertionCount = 0;
		let errorCount = 0;

		sequence(
			function onError(error) {
				errorCount++;
			},

			function getFirst(this: any) {
				this(true);
			},

			function getSecond(this: any, result: boolean) {
				assert.equal(result, true);
				this(false);
			},

			function last(result: boolean) {
				assert.equal(result, false);
				assertionCount++;

				assertCounterEquals(assertionCount, 1);
				assertCounterEquals(errorCount, 0);
				done();
			}
		);
	});

	test('loopTolerateBooleanResults', function (done: () => void) {
		let elements = ['1', '2', '3'];
		loop(elements, function (element, callback) {
			process.nextTick(function () {
				(<any>callback)(true);
			});
		}, function (error, result) {
			assert.equal(error, null);
			assert.deepEqual(result, [true, true, true]);

			done();
		});
	});

	test('parallel', function (done: () => void) {
		let elements = [1, 2, 3, 4, 5];
		let sum = 0;

		parallel(elements, function (element, callback) {
			sum += element;
			callback(null, element * element);
		}, function (errors, result) {
			assert.ok(!errors);

			assert.deepEqual(sum, 15);
			assert.deepEqual(result, [1, 4, 9, 16, 25]);

			done();
		});
	});

	test('parallel - setTimeout', function (done: () => void) {
		let elements = [1, 2, 3, 4, 5];
		let timeouts = [10, 30, 5, 0, 4];
		let sum = 0;

		parallel(elements, function (element, callback) {
			setTimeout(function () {
				sum += element;
				callback(null, element * element);
			}, timeouts.pop());
		}, function (errors, result) {
			assert.ok(!errors);

			assert.deepEqual(sum, 15);
			assert.deepEqual(result, [1, 4, 9, 16, 25]);

			done();
		});
	});

	test('parallel - with error', function (done: () => void) {
		const elements = [1, 2, 3, 4, 5];
		const timeouts = [10, 30, 5, 0, 4];
		let sum = 0;

		parallel(elements, function (element, callback) {
			setTimeout(function () {
				if (element === 4) {
					callback(new Error('error!'), null);
				} else {
					sum += element;
					callback(null, element * element);
				}
			}, timeouts.pop());
		}, function (errors, result) {
			assert.ok(errors);
			assert.deepEqual(errors, [null, null, null, new Error('error!'), null]);

			assert.deepEqual(sum, 11);
			assert.deepEqual(result, [1, 4, 9, null, 25]);

			done();
		});
	});
});