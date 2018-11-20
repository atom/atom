/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as assert from 'assert';
import { toErrorMessage } from 'vs/base/common/errorMessage';

suite('Errors', () => {
	test('Get Error Message', function () {
		assert.strictEqual(toErrorMessage('Foo Bar'), 'Foo Bar');
		assert.strictEqual(toErrorMessage(new Error('Foo Bar')), 'Foo Bar');

		let error: any = new Error();
		error = new Error();
		error.detail = {};
		error.detail.exception = {};
		error.detail.exception.message = 'Foo Bar';
		assert.strictEqual(toErrorMessage(error), 'Foo Bar');

		assert(toErrorMessage());
		assert(toErrorMessage(null));
		assert(toErrorMessage({}));
	});
});