/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as platform from 'vs/base/common/platform';

import { NsfwWatcherService } from 'vs/workbench/services/files/node/watcher/nsfw/nsfwWatcherService';
import { IWatcherRequest } from 'vs/workbench/services/files/node/watcher/nsfw/watcher';

class TestNsfwWatcherService extends NsfwWatcherService {
	public normalizeRoots(roots: string[]): string[] {
		// Work with strings as paths to simplify testing
		const requests: IWatcherRequest[] = roots.map(r => {
			return { basePath: r, ignored: [] };
		});
		return this._normalizeRoots(requests).map(r => r.basePath);
	}
}

suite('NSFW Watcher Service', () => {
	suite('_normalizeRoots', () => {
		test('should not impacts roots that don\'t overlap', () => {
			const service = new TestNsfwWatcherService();
			if (platform.isWindows) {
				assert.deepEqual(service.normalizeRoots(['C:\\a']), ['C:\\a']);
				assert.deepEqual(service.normalizeRoots(['C:\\a', 'C:\\b']), ['C:\\a', 'C:\\b']);
				assert.deepEqual(service.normalizeRoots(['C:\\a', 'C:\\b', 'C:\\c\\d\\e']), ['C:\\a', 'C:\\b', 'C:\\c\\d\\e']);
			} else {
				assert.deepEqual(service.normalizeRoots(['/a']), ['/a']);
				assert.deepEqual(service.normalizeRoots(['/a', '/b']), ['/a', '/b']);
				assert.deepEqual(service.normalizeRoots(['/a', '/b', '/c/d/e']), ['/a', '/b', '/c/d/e']);
			}
		});

		test('should remove sub-folders of other roots', () => {
			const service = new TestNsfwWatcherService();
			if (platform.isWindows) {
				assert.deepEqual(service.normalizeRoots(['C:\\a', 'C:\\a\\b']), ['C:\\a']);
				assert.deepEqual(service.normalizeRoots(['C:\\a', 'C:\\b', 'C:\\a\\b']), ['C:\\a', 'C:\\b']);
				assert.deepEqual(service.normalizeRoots(['C:\\b\\a', 'C:\\a', 'C:\\b', 'C:\\a\\b']), ['C:\\a', 'C:\\b']);
				assert.deepEqual(service.normalizeRoots(['C:\\a', 'C:\\a\\b', 'C:\\a\\c\\d']), ['C:\\a']);
			} else {
				assert.deepEqual(service.normalizeRoots(['/a', '/a/b']), ['/a']);
				assert.deepEqual(service.normalizeRoots(['/a', '/b', '/a/b']), ['/a', '/b']);
				assert.deepEqual(service.normalizeRoots(['/b/a', '/a', '/b', '/a/b']), ['/a', '/b']);
				assert.deepEqual(service.normalizeRoots(['/a', '/a/b', '/a/c/d']), ['/a']);
			}
		});
	});
});
