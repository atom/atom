/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as assert from 'assert';
import { HistoryNavigator } from 'vs/base/common/history';

suite('History Navigator', () => {

	test('create reduces the input to limit', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 2);

		assert.deepEqual(['3', '4'], toArray(testObject));
	});

	test('create sets the position to last', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 100);

		assert.equal(testObject.current(), null);
		assert.equal(testObject.next(), null);
		assert.equal(testObject.previous(), '4');
	});

	test('last returns last element', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 100);

		assert.equal(testObject.first(), '1');
		assert.equal(testObject.last(), '4');
	});

	test('first returns first element', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 3);

		assert.equal('2', testObject.first());
	});

	test('next returns next element', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 3);

		testObject.first();

		assert.equal(testObject.next(), '3');
		assert.equal(testObject.next(), '4');
		assert.equal(testObject.next(), null);
	});

	test('previous returns previous element', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 3);

		assert.equal(testObject.previous(), '4');
		assert.equal(testObject.previous(), '3');
		assert.equal(testObject.previous(), '2');
		assert.equal(testObject.previous(), null);
	});

	test('next on last element returs null and remains on last', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 3);

		testObject.first();
		testObject.last();

		assert.equal(testObject.current(), '4');
		assert.equal(testObject.next(), null);
	});

	test('previous on first element returs null and remains on first', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 3);

		testObject.first();

		assert.equal(testObject.current(), '2');
		assert.equal(testObject.previous(), null);
	});

	test('add reduces the input to limit', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 2);

		testObject.add('5');

		assert.deepEqual(toArray(testObject), ['4', '5']);
	});

	test('adding existing element changes the position', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 5);

		testObject.add('2');

		assert.deepEqual(toArray(testObject), ['1', '3', '4', '2']);
	});

	test('add resets the navigator to last', () => {
		const testObject = new HistoryNavigator(['1', '2', '3', '4'], 3);

		testObject.first();
		testObject.add('5');

		assert.equal(testObject.previous(), '5');
		assert.equal(testObject.next(), null);
	});

	test('adding an existing item changes the order', () => {
		const testObject = new HistoryNavigator(['1', '2', '3']);

		testObject.add('1');

		assert.deepEqual(['2', '3', '1'], toArray(testObject));
	});

	test('clear', () => {
		const testObject = new HistoryNavigator(['a', 'b', 'c']);
		assert.equal(testObject.previous(), 'c');
		testObject.clear();
		assert.equal(testObject.current(), undefined);
	});

	function toArray(historyNavigator: HistoryNavigator<string>): string[] {
		let result: string[] = [];
		historyNavigator.first();
		if (historyNavigator.current()) {
			do {
				result.push(historyNavigator.current());
			} while (historyNavigator.next());
		}
		return result;
	}
});
