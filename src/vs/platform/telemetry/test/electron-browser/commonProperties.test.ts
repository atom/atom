/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as assert from 'assert';
import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs';
import { resolveWorkbenchCommonProperties } from 'vs/platform/telemetry/node/workbenchCommonProperties';
import { getRandomTestPath, TestEnvironmentService } from 'vs/workbench/test/workbenchTestServices';
import { IStorageService, StorageScope } from 'vs/platform/storage/common/storage';
import { StorageService } from 'vs/platform/storage/node/storageService';
import { NullLogService } from 'vs/platform/log/common/log';
import { del } from 'vs/base/node/extfs';
import { mkdirp } from 'vs/base/node/pfs';
import { timeout } from 'vs/base/common/async';

suite('Telemetry - common properties', function () {
	const parentDir = getRandomTestPath(os.tmpdir(), 'vsctests', 'telemetryservice');
	const installSource = path.join(parentDir, 'installSource');

	const commit: string = void 0;
	const version: string = void 0;
	let nestStorage2Service: IStorageService;

	setup(() => {
		nestStorage2Service = new StorageService(':memory:', false, new NullLogService(), TestEnvironmentService);
	});

	teardown(done => {
		del(parentDir, os.tmpdir(), done);
	});

	test('default', async function () {
		await mkdirp(parentDir);
		fs.writeFileSync(installSource, 'my.install.source');
		const props = await resolveWorkbenchCommonProperties(nestStorage2Service, commit, version, 'someMachineId', installSource);
		assert.ok('commitHash' in props);
		assert.ok('sessionID' in props);
		assert.ok('timestamp' in props);
		assert.ok('common.platform' in props);
		assert.ok('common.nodePlatform' in props);
		assert.ok('common.nodeArch' in props);
		assert.ok('common.timesincesessionstart' in props);
		assert.ok('common.sequence' in props);
		// assert.ok('common.version.shell' in first.data); // only when running on electron
		// assert.ok('common.version.renderer' in first.data);
		assert.ok('common.platformVersion' in props, 'platformVersion');
		assert.ok('version' in props);
		assert.equal(props['common.source'], 'my.install.source');
		assert.ok('common.firstSessionDate' in props, 'firstSessionDate');
		assert.ok('common.lastSessionDate' in props, 'lastSessionDate'); // conditional, see below, 'lastSessionDate'ow
		assert.ok('common.isNewSession' in props, 'isNewSession');
		// machine id et al
		assert.ok('common.instanceId' in props, 'instanceId');
		assert.ok('common.machineId' in props, 'machineId');
		fs.unlinkSync(installSource);
		const props_1 = await resolveWorkbenchCommonProperties(nestStorage2Service, commit, version, 'someMachineId', installSource);
		assert.ok(!('common.source' in props_1));
	});

	test('lastSessionDate when aviablale', async function () {

		nestStorage2Service.store('telemetry.lastSessionDate', new Date().toUTCString(), StorageScope.GLOBAL);

		const props = await resolveWorkbenchCommonProperties(nestStorage2Service, commit, version, 'someMachineId', installSource);
		assert.ok('common.lastSessionDate' in props); // conditional, see below
		assert.ok('common.isNewSession' in props);
		assert.equal(props['common.isNewSession'], 0);
	});

	test('values chance on ask', async function () {
		const props = await resolveWorkbenchCommonProperties(nestStorage2Service, commit, version, 'someMachineId', installSource);
		let value1 = props['common.sequence'];
		let value2 = props['common.sequence'];
		assert.ok(value1 !== value2, 'seq');

		value1 = props['timestamp'];
		value2 = props['timestamp'];
		assert.ok(value1 !== value2, 'timestamp');

		value1 = props['common.timesincesessionstart'];
		await timeout(10);
		value2 = props['common.timesincesessionstart'];
		assert.ok(value1 !== value2, 'timesincesessionstart');
	});
});
