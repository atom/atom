/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as assert from 'assert';
import * as sinon from 'sinon';
import { URI } from 'vs/base/common/uri';
import { Registry } from 'vs/platform/registry/common/platform';
import { Extensions, IConfigurationRegistry, ConfigurationScope } from 'vs/platform/configuration/common/configurationRegistry';
import { IWorkspaceContextService, WorkbenchState } from 'vs/platform/workspace/common/workspace';
import { TestInstantiationService } from 'vs/platform/instantiation/test/common/instantiationServiceMock';
import { MainThreadConfiguration } from 'vs/workbench/api/electron-browser/mainThreadConfiguration';
import { SingleProxyRPCProtocol } from './testRPCProtocol';
import { IConfigurationService, ConfigurationTarget } from 'vs/platform/configuration/common/configuration';
import { WorkspaceService } from 'vs/workbench/services/configuration/node/configurationService';

suite('MainThreadConfiguration', function () {

	let instantiationService: TestInstantiationService;
	let target: sinon.SinonSpy;

	suiteSetup(() => {
		Registry.as<IConfigurationRegistry>(Extensions.Configuration).registerConfiguration({
			'id': 'extHostConfiguration',
			'title': 'a',
			'type': 'object',
			'properties': {
				'extHostConfiguration.resource': {
					'description': 'extHostConfiguration.resource',
					'type': 'boolean',
					'default': true,
					'scope': ConfigurationScope.RESOURCE
				},
				'extHostConfiguration.window': {
					'description': 'extHostConfiguration.resource',
					'type': 'boolean',
					'default': true,
					'scope': ConfigurationScope.WINDOW
				}
			}
		});
	});

	setup(() => {
		target = sinon.spy();

		instantiationService = new TestInstantiationService();
		instantiationService.stub(IConfigurationService, WorkspaceService);
		instantiationService.stub(IConfigurationService, 'onDidUpdateConfiguration', sinon.mock());
		instantiationService.stub(IConfigurationService, 'onDidChangeConfiguration', sinon.mock());
		instantiationService.stub(IConfigurationService, 'updateValue', target);
	});

	test('update resource configuration without configuration target defaults to workspace in multi root workspace when no resource is provided', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.WORKSPACE });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(null, 'extHostConfiguration.resource', 'value', null);

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('update resource configuration without configuration target defaults to workspace in folder workspace when resource is provider', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(null, 'extHostConfiguration.resource', 'value', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('update resource configuration without configuration target defaults to workspace in folder workspace when no resource is provider', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(null, 'extHostConfiguration.resource', 'value', null);

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('update window configuration without configuration target defaults to workspace in multi root workspace when no resource is provided', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.WORKSPACE });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(null, 'extHostConfiguration.window', 'value', null);

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('update window configuration without configuration target defaults to workspace in multi root workspace when resource is provided', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.WORKSPACE });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(null, 'extHostConfiguration.window', 'value', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('update window configuration without configuration target defaults to workspace in folder workspace when resource is provider', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(null, 'extHostConfiguration.window', 'value', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('update window configuration without configuration target defaults to workspace in folder workspace when no resource is provider', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(null, 'extHostConfiguration.window', 'value', null);

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('update resource configuration without configuration target defaults to folder', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.WORKSPACE });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(null, 'extHostConfiguration.resource', 'value', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE_FOLDER, target.args[0][3]);
	});

	test('update configuration with user configuration target', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(ConfigurationTarget.USER, 'extHostConfiguration.window', 'value', URI.file('abc'));

		assert.equal(ConfigurationTarget.USER, target.args[0][3]);
	});

	test('update configuration with workspace configuration target', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(ConfigurationTarget.WORKSPACE, 'extHostConfiguration.window', 'value', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('update configuration with folder configuration target', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$updateConfigurationOption(ConfigurationTarget.WORKSPACE_FOLDER, 'extHostConfiguration.window', 'value', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE_FOLDER, target.args[0][3]);
	});

	test('remove resource configuration without configuration target defaults to workspace in multi root workspace when no resource is provided', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.WORKSPACE });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$removeConfigurationOption(null, 'extHostConfiguration.resource', null);

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('remove resource configuration without configuration target defaults to workspace in folder workspace when resource is provider', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$removeConfigurationOption(null, 'extHostConfiguration.resource', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('remove resource configuration without configuration target defaults to workspace in folder workspace when no resource is provider', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$removeConfigurationOption(null, 'extHostConfiguration.resource', null);

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('remove window configuration without configuration target defaults to workspace in multi root workspace when no resource is provided', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.WORKSPACE });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$removeConfigurationOption(null, 'extHostConfiguration.window', null);

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('remove window configuration without configuration target defaults to workspace in multi root workspace when resource is provided', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.WORKSPACE });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$removeConfigurationOption(null, 'extHostConfiguration.window', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('remove window configuration without configuration target defaults to workspace in folder workspace when resource is provider', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$removeConfigurationOption(null, 'extHostConfiguration.window', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('remove window configuration without configuration target defaults to workspace in folder workspace when no resource is provider', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.FOLDER });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$removeConfigurationOption(null, 'extHostConfiguration.window', null);

		assert.equal(ConfigurationTarget.WORKSPACE, target.args[0][3]);
	});

	test('remove configuration without configuration target defaults to folder', function () {
		instantiationService.stub(IWorkspaceContextService, <IWorkspaceContextService>{ getWorkbenchState: () => WorkbenchState.WORKSPACE });
		const testObject: MainThreadConfiguration = instantiationService.createInstance(MainThreadConfiguration, SingleProxyRPCProtocol(null));

		testObject.$removeConfigurationOption(null, 'extHostConfiguration.resource', URI.file('abc'));

		assert.equal(ConfigurationTarget.WORKSPACE_FOLDER, target.args[0][3]);
	});
});
