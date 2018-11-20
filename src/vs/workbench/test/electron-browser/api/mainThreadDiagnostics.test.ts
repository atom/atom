/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { MarkerService } from 'vs/platform/markers/common/markerService';
import { MainThreadDiagnostics } from 'vs/workbench/api/electron-browser/mainThreadDiagnostics';
import { URI } from 'vs/base/common/uri';


suite('MainThreadDiagnostics', function () {

	let markerService: MarkerService;

	setup(function () {
		markerService = new MarkerService();
	});

	test('clear markers on dispose', function () {

		let diag = new MainThreadDiagnostics(null, markerService);

		diag.$changeMany('foo', [[URI.file('a'), [{
			code: '666',
			startLineNumber: 1,
			startColumn: 1,
			endLineNumber: 1,
			endColumn: 1,
			message: 'fffff',
			severity: 1,
			source: 'me'
		}]]]);

		assert.equal(markerService.read().length, 1);
		diag.dispose();
		assert.equal(markerService.read().length, 0);
	});
});
