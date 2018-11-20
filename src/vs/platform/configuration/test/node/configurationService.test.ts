/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as os from 'os';
import * as path from 'path';
import * as fs from 'fs';

import { Registry } from 'vs/platform/registry/common/platform';
import { ConfigurationService } from 'vs/platform/configuration/node/configurationService';
import { ParsedArgs } from 'vs/platform/environment/common/environment';
import { parseArgs } from 'vs/platform/environment/node/argv';
import { EnvironmentService } from 'vs/platform/environment/node/environmentService';
import * as uuid from 'vs/base/common/uuid';
import { IConfigurationRegistry, Extensions as ConfigurationExtensions } from 'vs/platform/configuration/common/configurationRegistry';
import { testFile } from 'vs/base/test/node/utils';

class SettingsTestEnvironmentService extends EnvironmentService {

	constructor(args: ParsedArgs, _execPath: string, private customAppSettingsHome) {
		super(args, _execPath);
	}

	get appSettingsPath(): string { return this.customAppSettingsHome; }
}

suite('ConfigurationService - Node', () => {

	test('simple', async () => {
		const res = await testFile('config', 'config.json');
		fs.writeFileSync(res.testFile, '{ "foo": "bar" }');

		const service = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, res.testFile));
		const config = service.getValue<{
			foo: string;
		}>();

		assert.ok(config);
		assert.equal(config.foo, 'bar');
		service.dispose();

		return res.cleanUp();
	});

	test('config gets flattened', async () => {
		const res = await testFile('config', 'config.json');

		fs.writeFileSync(res.testFile, '{ "testworkbench.editor.tabs": true }');

		const service = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, res.testFile));
		const config = service.getValue<{
			testworkbench: {
				editor: {
					tabs: boolean;
				};
			};
		}>();
		assert.ok(config);
		assert.ok(config.testworkbench);
		assert.ok(config.testworkbench.editor);
		assert.equal(config.testworkbench.editor.tabs, true);

		service.dispose();
		return res.cleanUp();
	});

	test('error case does not explode', async () => {
		const res = await testFile('config', 'config.json');

		fs.writeFileSync(res.testFile, ',,,,');

		const service = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, res.testFile));
		const config = service.getValue<{
			foo: string;
		}>();
		assert.ok(config);

		service.dispose();
		return res.cleanUp();
	});

	test('missing file does not explode', () => {
		const id = uuid.generateUuid();
		const parentDir = path.join(os.tmpdir(), 'vsctests', id);
		const newDir = path.join(parentDir, 'config', id);
		const testFile = path.join(newDir, 'config.json');

		const service = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, testFile));

		const config = service.getValue<{ foo: string }>();
		assert.ok(config);

		service.dispose();
	});

	test('reloadConfiguration', async () => {
		const res = await testFile('config', 'config.json');

		fs.writeFileSync(res.testFile, '{ "foo": "bar" }');

		const service = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, res.testFile));
		let config = service.getValue<{
			foo: string;
		}>();
		assert.ok(config);
		assert.equal(config.foo, 'bar');
		fs.writeFileSync(res.testFile, '{ "foo": "changed" }');

		// still outdated
		config = service.getValue<{
			foo: string;
		}>();
		assert.ok(config);
		assert.equal(config.foo, 'bar');

		// force a reload to get latest
		await service.reloadConfiguration();
		config = service.getValue<{
			foo: string;
		}>();
		assert.ok(config);
		assert.equal(config.foo, 'changed');

		service.dispose();
		return res.cleanUp();
	});

	test('model defaults', () => {
		interface ITestSetting {
			configuration: {
				service: {
					testSetting: string;
				}
			};
		}

		const configurationRegistry = Registry.as<IConfigurationRegistry>(ConfigurationExtensions.Configuration);
		configurationRegistry.registerConfiguration({
			'id': '_test',
			'type': 'object',
			'properties': {
				'configuration.service.testSetting': {
					'type': 'string',
					'default': 'isSet'
				}
			}
		});

		let serviceWithoutFile = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, '__testFile'));
		let setting = serviceWithoutFile.getValue<ITestSetting>();

		assert.ok(setting);
		assert.equal(setting.configuration.service.testSetting, 'isSet');

		return testFile('config', 'config.json').then(async res => {
			fs.writeFileSync(res.testFile, '{ "testworkbench.editor.tabs": true }');

			const service = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, res.testFile));

			let setting = service.getValue<ITestSetting>();

			assert.ok(setting);
			assert.equal(setting.configuration.service.testSetting, 'isSet');

			fs.writeFileSync(res.testFile, '{ "configuration.service.testSetting": "isChanged" }');

			await service.reloadConfiguration();
			let setting_1 = service.getValue<ITestSetting>();
			assert.ok(setting_1);
			assert.equal(setting_1.configuration.service.testSetting, 'isChanged');
			service.dispose();
			serviceWithoutFile.dispose();
			return res.cleanUp();
		});
	});

	test('lookup', async () => {
		const configurationRegistry = Registry.as<IConfigurationRegistry>(ConfigurationExtensions.Configuration);
		configurationRegistry.registerConfiguration({
			'id': '_test',
			'type': 'object',
			'properties': {
				'lookup.service.testSetting': {
					'type': 'string',
					'default': 'isSet'
				}
			}
		});

		const r = await testFile('config', 'config.json');
		const service = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, r.testFile));
		let res = service.inspect('something.missing');
		assert.strictEqual(res.value, void 0);
		assert.strictEqual(res.default, void 0);
		assert.strictEqual(res.user, void 0);

		res = service.inspect('lookup.service.testSetting');
		assert.strictEqual(res.default, 'isSet');
		assert.strictEqual(res.value, 'isSet');
		assert.strictEqual(res.user, void 0);

		fs.writeFileSync(r.testFile, '{ "lookup.service.testSetting": "bar" }');

		await service.reloadConfiguration();
		res = service.inspect('lookup.service.testSetting');
		assert.strictEqual(res.default, 'isSet');
		assert.strictEqual(res.user, 'bar');
		assert.strictEqual(res.value, 'bar');

		service.dispose();
		return r.cleanUp();
	});

	test('lookup with null', async () => {
		const configurationRegistry = Registry.as<IConfigurationRegistry>(ConfigurationExtensions.Configuration);
		configurationRegistry.registerConfiguration({
			'id': '_testNull',
			'type': 'object',
			'properties': {
				'lookup.service.testNullSetting': {
					'type': 'null',
				}
			}
		});

		const r = await testFile('config', 'config.json');
		const service = new ConfigurationService(new SettingsTestEnvironmentService(parseArgs(process.argv), process.execPath, r.testFile));
		let res = service.inspect('lookup.service.testNullSetting');
		assert.strictEqual(res.default, null);
		assert.strictEqual(res.value, null);
		assert.strictEqual(res.user, void 0);

		fs.writeFileSync(r.testFile, '{ "lookup.service.testNullSetting": null }');

		await service.reloadConfiguration();

		res = service.inspect('lookup.service.testNullSetting');
		assert.strictEqual(res.default, null);
		assert.strictEqual(res.value, null);
		assert.strictEqual(res.user, null);

		service.dispose();
		return r.cleanUp();
	});
});
