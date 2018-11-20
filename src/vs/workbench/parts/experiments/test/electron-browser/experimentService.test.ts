/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import { ExperimentService, ExperimentActionType, ExperimentState, IExperiment } from 'vs/workbench/parts/experiments/node/experimentService';
import { TestInstantiationService } from 'vs/platform/instantiation/test/common/instantiationServiceMock';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { TestLifecycleService } from 'vs/workbench/test/workbenchTestServices';
import {
	IExtensionManagementService, DidInstallExtensionEvent, DidUninstallExtensionEvent, InstallExtensionEvent, IExtensionIdentifier,
	IExtensionEnablementService, ILocalExtension, LocalExtensionType
} from 'vs/platform/extensionManagement/common/extensionManagement';
import { ExtensionManagementService, getLocalExtensionIdFromManifest } from 'vs/platform/extensionManagement/node/extensionManagementService';
import { Emitter } from 'vs/base/common/event';
import { TestExtensionEnablementService } from 'vs/platform/extensionManagement/test/electron-browser/extensionEnablementService.test';
import { URLService } from 'vs/platform/url/common/urlService';
import { IURLService } from 'vs/platform/url/common/url';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { NullTelemetryService } from 'vs/platform/telemetry/common/telemetryUtils';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { TestConfigurationService } from 'vs/platform/configuration/test/common/testConfigurationService';
import { ILifecycleService } from 'vs/platform/lifecycle/common/lifecycle';
import { TPromise } from 'vs/base/common/winjs.base';
import { assign } from 'vs/base/common/objects';
import { URI } from 'vs/base/common/uri';
import { IStorageService } from 'vs/platform/storage/common/storage';
import { lastSessionDateStorageKey } from 'vs/platform/telemetry/node/workbenchCommonProperties';

let experimentData = {
	experiments: []
};

const local = aLocalExtension('installedExtension1', { version: '1.0.0' });

function aLocalExtension(name: string = 'someext', manifest: any = {}, properties: any = {}): ILocalExtension {
	const localExtension = <ILocalExtension>Object.create({ manifest: {} });
	assign(localExtension, { type: LocalExtensionType.User, manifest: {}, location: URI.file(`pub.${name}`) }, properties);
	assign(localExtension.manifest, { name, publisher: 'pub', version: '1.0.0' }, manifest);
	localExtension.identifier = { id: getLocalExtensionIdFromManifest(localExtension.manifest) };
	localExtension.metadata = { id: localExtension.identifier.id, publisherId: localExtension.manifest.publisher, publisherDisplayName: 'somename' };
	return localExtension;
}

export class TestExperimentService extends ExperimentService {
	public getExperiments(): TPromise<any[]> {
		return TPromise.wrap(experimentData.experiments);
	}
}

suite('Experiment Service', () => {
	let instantiationService: TestInstantiationService;
	let testConfigurationService: TestConfigurationService;
	let testObject: ExperimentService;
	let installEvent: Emitter<InstallExtensionEvent>,
		didInstallEvent: Emitter<DidInstallExtensionEvent>,
		uninstallEvent: Emitter<IExtensionIdentifier>,
		didUninstallEvent: Emitter<DidUninstallExtensionEvent>;

	suiteSetup(() => {
		instantiationService = new TestInstantiationService();
		installEvent = new Emitter<InstallExtensionEvent>();
		didInstallEvent = new Emitter<DidInstallExtensionEvent>();
		uninstallEvent = new Emitter<IExtensionIdentifier>();
		didUninstallEvent = new Emitter<DidUninstallExtensionEvent>();

		instantiationService.stub(IExtensionManagementService, ExtensionManagementService);
		instantiationService.stub(IExtensionManagementService, 'onInstallExtension', installEvent.event);
		instantiationService.stub(IExtensionManagementService, 'onDidInstallExtension', didInstallEvent.event);
		instantiationService.stub(IExtensionManagementService, 'onUninstallExtension', uninstallEvent.event);
		instantiationService.stub(IExtensionManagementService, 'onDidUninstallExtension', didUninstallEvent.event);
		instantiationService.stub(IExtensionEnablementService, new TestExtensionEnablementService(instantiationService));
		instantiationService.stub(ITelemetryService, NullTelemetryService);
		instantiationService.stub(IURLService, URLService);
		instantiationService.stubPromise(IExtensionManagementService, 'getInstalled', [local]);
		testConfigurationService = new TestConfigurationService();
		instantiationService.stub(IConfigurationService, testConfigurationService);
		instantiationService.stub(ILifecycleService, new TestLifecycleService());
		instantiationService.stub(IStorageService, { get: (a, b, c) => c, getBoolean: (a, b, c) => c, store: () => { }, remove: () => { } });

		setup(() => {
			instantiationService.stub(IEnvironmentService, {});
			instantiationService.stub(IStorageService, { get: (a, b, c) => c, getBoolean: (a, b, c) => c, store: () => { }, remove: () => { } });
		});

		teardown(() => {
			if (testObject) {
				testObject.dispose();
			}
		});
	});

	test('Simple Experiment Test', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1'
				},
				{
					id: 'experiment2',
					enabled: false
				},
				{
					id: 'experiment3',
					enabled: true
				},
				{
					id: 'experiment4',
					enabled: true,
					condition: {

					}
				},
				{
					id: 'experiment5',
					enabled: true,
					condition: {
						insidersOnly: true
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		const tests: TPromise<IExperiment>[] = [];
		tests.push(testObject.getExperimentById('experiment1'));
		tests.push(testObject.getExperimentById('experiment2'));
		tests.push(testObject.getExperimentById('experiment3'));
		tests.push(testObject.getExperimentById('experiment4'));
		tests.push(testObject.getExperimentById('experiment5'));

		return TPromise.join(tests).then(results => {
			assert.equal(results[0].id, 'experiment1');
			assert.equal(results[0].enabled, false);
			assert.equal(results[0].state, ExperimentState.NoRun);

			assert.equal(results[1].id, 'experiment2');
			assert.equal(results[1].enabled, false);
			assert.equal(results[1].state, ExperimentState.NoRun);

			assert.equal(results[2].id, 'experiment3');
			assert.equal(results[2].enabled, true);
			assert.equal(results[2].state, ExperimentState.Run);

			assert.equal(results[3].id, 'experiment4');
			assert.equal(results[3].enabled, true);
			assert.equal(results[3].state, ExperimentState.Run);

			assert.equal(results[4].id, 'experiment5');
			assert.equal(results[4].enabled, true);
			assert.equal(results[4].state, ExperimentState.Run);
		});
	});

	test('Insiders only experiment shouldnt be enabled in stable', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						insidersOnly: true
					}
				}
			]
		};

		instantiationService.stub(IEnvironmentService, { appQuality: 'stable' });
		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.NoRun);
		});
	});

	test('NewUsers experiment shouldnt be enabled for old users', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						newUser: true
					}
				}
			]
		};

		instantiationService.stub(IStorageService, {
			get: (a, b, c) => {
				return a === lastSessionDateStorageKey ? 'some-date' : undefined;
			},
			getBoolean: (a, b, c) => c, store: () => { }, remove: () => { }
		});
		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.NoRun);
		});
	});

	test('OldUsers experiment shouldnt be enabled for new users', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						newUser: false
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.NoRun);
		});
	});

	test('Experiment without NewUser condition should be enabled for old users', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {}
				}
			]
		};

		instantiationService.stub(IStorageService, {
			get: (a, b, c) => {
				return a === lastSessionDateStorageKey ? 'some-date' : undefined;
			},
			getBoolean: (a, b, c) => c, store: () => { }, remove: () => { }
		});
		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.Run);
		});
	});

	test('Experiment without NewUser condition should be enabled for new users', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.Run);
		});
	});

	test('Experiment with no matching display language should be disabled', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						displayLanguage: 'somethingthat-nooneknows'
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.NoRun);
		});
	});

	test('Experiment with condition type InstalledExtensions is enabled when one of the expected extensions is installed', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						installedExtensions: {
							inlcudes: ['pub.installedExtension1', 'uninstalled-extention-id']
						}
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.Run);
		});
	});

	test('Experiment with condition type InstalledExtensions is disabled when none of the expected extensions is installed', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						installedExtensions: {
							includes: ['uninstalled-extention-id1', 'uninstalled-extention-id2']
						}
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.NoRun);
		});
	});

	test('Experiment with condition type InstalledExtensions is disabled when one of the exlcuded extensions is installed', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						installedExtensions: {
							excludes: ['pub.installedExtension1', 'uninstalled-extention-id2']
						}
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.NoRun);
		});
	});

	test('Experiment that is marked as complete should be disabled regardless of the conditions', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						installedExtensions: {
							includes: ['pub.installedExtension1', 'uninstalled-extention-id2']
						}
					}
				}
			]
		};

		instantiationService.stub(IStorageService, {
			get: (a, b, c) => a === 'experiments.experiment1' ? JSON.stringify({ state: ExperimentState.Complete }) : c,
			store: (a, b, c) => { }
		});

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.Complete);
		});
	});

	test('Experiment with evaluate only once should read enablement from storage service', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					condition: {
						installedExtensions: {
							excludes: ['pub.installedExtension1', 'uninstalled-extention-id2']
						},
						evaluateOnlyOnce: true
					}
				}
			]
		};

		instantiationService.stub(IStorageService, {
			get: (a, b, c) => a === 'experiments.experiment1' ? JSON.stringify({ enabled: true, state: ExperimentState.Run }) : c,
			store: (a, b, c) => { }
		});
		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.Run);
		});
	});

	test('Curated list should be available if experiment is enabled.', () => {
		const promptText = 'Hello there! Can you see this?';
		const curatedExtensionsKey = 'AzureDeploy';
		const curatedExtensionsList = ['uninstalled-extention-id1', 'uninstalled-extention-id2'];
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: true,
					action: {
						type: 'Prompt',
						properties: {
							promptText,
							commands: [
								{
									text: 'Search Marketplace',
									dontShowAgain: true,
									curatedExtensionsKey,
									curatedExtensionsList
								},
								{
									text: 'No'
								}
							]
						}
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, true);
			assert.equal(result.state, ExperimentState.Run);
			return testObject.getCuratedExtensionsList(curatedExtensionsKey).then(curatedList => {
				assert.equal(curatedList, curatedExtensionsList);
			});
		});
	});

	test('Curated list shouldnt be available if experiment is disabled.', () => {
		const promptText = 'Hello there! Can you see this?';
		const curatedExtensionsKey = 'AzureDeploy';
		const curatedExtensionsList = ['uninstalled-extention-id1', 'uninstalled-extention-id2'];
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: false,
					action: {
						type: 'Prompt',
						properties: {
							promptText,
							commands: [
								{
									text: 'Search Marketplace',
									dontShowAgain: true,
									curatedExtensionsKey,
									curatedExtensionsList
								},
								{
									text: 'No'
								}
							]
						}
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, false);
			assert.equal(result.state, ExperimentState.NoRun);
			return testObject.getCuratedExtensionsList(curatedExtensionsKey).then(curatedList => {
				assert.equal(curatedList.length, 0);
			});
		});
	});

	test('Experiment that is disabled or deleted should be removed from storage', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment1',
					enabled: false
				},
				{
					id: 'experiment3',
					enabled: true
				}
			]
		};

		let storageDataExperiment1 = { enabled: false };
		let storageDataExperiment2 = { enabled: false };
		let storageDataAllExperiments = ['experiment1', 'experiment2', 'experiment3'];
		instantiationService.stub(IStorageService, {
			get: (a, b, c) => {
				switch (a) {
					case 'experiments.experiment1':
						return JSON.stringify(storageDataExperiment1);
					case 'experiments.experiment2':
						return JSON.stringify(storageDataExperiment2);
					case 'allExperiments':
						return JSON.stringify(storageDataAllExperiments);
					default:
						break;
				}
				return c;
			},
			store: (a, b, c) => {
				switch (a) {
					case 'experiments.experiment1':
						storageDataExperiment1 = JSON.parse(b);
						break;
					case 'experiments.experiment2':
						storageDataExperiment2 = JSON.parse(b);
						break;
					case 'allExperiments':
						storageDataAllExperiments = JSON.parse(b);
						break;
					default:
						break;
				}
			},
			remove: a => {
				switch (a) {
					case 'experiments.experiment1':
						storageDataExperiment1 = null;
						break;
					case 'experiments.experiment2':
						storageDataExperiment2 = null;
						break;
					case 'allExperiments':
						storageDataAllExperiments = null;
						break;
					default:
						break;
				}
			}
		});

		testObject = instantiationService.createInstance(TestExperimentService);
		const disabledExperiment = testObject.getExperimentById('experiment1').then(result => {
			assert.equal(result.enabled, false);
			assert.equal(!!storageDataExperiment1, false);
		});
		const deletedExperiment = testObject.getExperimentById('experiment2').then(result => {
			assert.equal(!!result, false);
			assert.equal(!!storageDataExperiment2, false);
		});
		return TPromise.join([disabledExperiment, deletedExperiment]).then(() => {
			assert.equal(storageDataAllExperiments.length, 1);
			assert.equal(storageDataAllExperiments[0], 'experiment3');
		});

	});

	test('Offline mode', () => {
		experimentData = {
			experiments: null
		};

		let storageDataExperiment1 = { enabled: true, state: ExperimentState.Run };
		let storageDataExperiment2 = { enabled: true, state: ExperimentState.NoRun };
		let storageDataExperiment3 = { enabled: true, state: ExperimentState.Evaluating };
		let storageDataExperiment4 = { enabled: true, state: ExperimentState.Complete };
		let storageDataAllExperiments = ['experiment1', 'experiment2', 'experiment3', 'experiment4'];
		instantiationService.stub(IStorageService, {
			get: (a, b, c) => {
				switch (a) {
					case 'experiments.experiment1':
						return JSON.stringify(storageDataExperiment1);
					case 'experiments.experiment2':
						return JSON.stringify(storageDataExperiment2);
					case 'experiments.experiment3':
						return JSON.stringify(storageDataExperiment3);
					case 'experiments.experiment4':
						return JSON.stringify(storageDataExperiment4);
					case 'allExperiments':
						return JSON.stringify(storageDataAllExperiments);
					default:
						break;
				}
				return c;
			},
			store: (a, b, c) => {
				switch (a) {
					case 'experiments.experiment1':
						storageDataExperiment1 = JSON.parse(b);
						break;
					case 'experiments.experiment2':
						storageDataExperiment2 = JSON.parse(b);
						break;
					case 'experiments.experiment3':
						storageDataExperiment3 = JSON.parse(b);
						break;
					case 'experiments.experiment4':
						storageDataExperiment4 = JSON.parse(b);
						break;
					case 'allExperiments':
						storageDataAllExperiments = JSON.parse(b);
						break;
					default:
						break;
				}
			},
			remove: a => {
				switch (a) {
					case 'experiments.experiment1':
						storageDataExperiment1 = null;
						break;
					case 'experiments.experiment2':
						storageDataExperiment2 = null;
						break;
					case 'experiments.experiment3':
						storageDataExperiment3 = null;
						break;
					case 'experiments.experiment4':
						storageDataExperiment4 = null;
						break;
					case 'allExperiments':
						storageDataAllExperiments = null;
						break;
					default:
						break;
				}
			}
		});

		testObject = instantiationService.createInstance(TestExperimentService);

		const tests: TPromise<IExperiment>[] = [];
		tests.push(testObject.getExperimentById('experiment1'));
		tests.push(testObject.getExperimentById('experiment2'));
		tests.push(testObject.getExperimentById('experiment3'));
		tests.push(testObject.getExperimentById('experiment4'));

		return TPromise.join(tests).then(results => {
			assert.equal(results[0].id, 'experiment1');
			assert.equal(results[0].enabled, true);
			assert.equal(results[0].state, ExperimentState.Run);

			assert.equal(results[1].id, 'experiment2');
			assert.equal(results[1].enabled, true);
			assert.equal(results[1].state, ExperimentState.NoRun);

			assert.equal(results[2].id, 'experiment3');
			assert.equal(results[2].enabled, true);
			assert.equal(results[2].state, ExperimentState.Evaluating);

			assert.equal(results[3].id, 'experiment4');
			assert.equal(results[3].enabled, true);
			assert.equal(results[3].state, ExperimentState.Complete);
		});

	});

	test('getExperimentByType', () => {
		const customProperties = {
			some: 'random-value'
		};
		experimentData = {
			experiments: [
				{
					id: 'simple-experiment',
					enabled: true
				},
				{
					id: 'custom-experiment',
					enabled: true,
					action: {
						type: 'Custom',
						properties: customProperties
					}
				},
				{
					id: 'custom-experiment-no-properties',
					enabled: true,
					action: {
						type: 'Custom'
					}
				},
				{
					id: 'prompt-with-no-commands',
					enabled: true,
					action: {
						type: 'Prompt',
						properties: {
							promptText: 'someText'
						}
					}
				},
				{
					id: 'prompt-with-commands',
					enabled: true,
					action: {
						type: 'Prompt',
						properties: {
							promptText: 'someText',
							commands: [
								{
									text: 'Hello'
								}
							]
						}
					}
				}
			]
		};

		testObject = instantiationService.createInstance(TestExperimentService);
		const custom = testObject.getExperimentsByType(ExperimentActionType.Custom).then(result => {
			assert.equal(result.length, 3);
			assert.equal(result[0].id, 'simple-experiment');
			assert.equal(result[1].id, 'custom-experiment');
			assert.equal(result[1].action.properties, customProperties);
			assert.equal(result[2].id, 'custom-experiment-no-properties');
			assert.equal(!!result[2].action.properties, true);
		});
		const prompt = testObject.getExperimentsByType(ExperimentActionType.Prompt).then(result => {
			assert.equal(result.length, 2);
			assert.equal(result[0].id, 'prompt-with-no-commands');
			assert.equal(result[1].id, 'prompt-with-commands');
		});
		return TPromise.join([custom, prompt]);
	});

	test('experimentsPreviouslyRun includes, excludes check', () => {
		experimentData = {
			experiments: [
				{
					id: 'experiment3',
					enabled: true,
					condition: {
						experimentsPreviouslyRun: {
							includes: ['experiment1'],
							excludes: ['experiment2']
						}
					}
				},
				{
					id: 'experiment4',
					enabled: true,
					condition: {
						experimentsPreviouslyRun: {
							includes: ['experiment1'],
							excludes: ['experiment200']
						}
					}
				}
			]
		};

		let storageDataExperiment3 = { enabled: true, state: ExperimentState.Evaluating };
		let storageDataExperiment4 = { enabled: true, state: ExperimentState.Evaluating };
		instantiationService.stub(IStorageService, {
			get: (a, b, c) => {
				switch (a) {
					case 'currentOrPreviouslyRunExperiments':
						return JSON.stringify(['experiment1', 'experiment2']);
					default:
						break;
				}
				return c;
			},
			store: (a, b, c) => {
				switch (a) {
					case 'experiments.experiment3':
						storageDataExperiment3 = JSON.parse(b);
						break;
					case 'experiments.experiment4':
						storageDataExperiment4 = JSON.parse(b);
						break;
					default:
						break;
				}
			}
		});

		testObject = instantiationService.createInstance(TestExperimentService);
		return testObject.getExperimentsByType(ExperimentActionType.Custom).then(result => {
			assert.equal(result.length, 2);
			assert.equal(result[0].id, 'experiment3');
			assert.equal(result[0].state, ExperimentState.NoRun);
			assert.equal(result[1].id, 'experiment4');
			assert.equal(result[1].state, ExperimentState.Run);
			assert.equal(storageDataExperiment3.state, ExperimentState.NoRun);
			assert.equal(storageDataExperiment4.state, ExperimentState.Run);
			return TPromise.as(null);
		});
	});
	// test('Experiment with condition type FileEdit should increment editcount as appropriate', () => {

	// });

	// test('Experiment with condition type WorkspaceEdit should increment editcount as appropriate', () => {

	// });



});


