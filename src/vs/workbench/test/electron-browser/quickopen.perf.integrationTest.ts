/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/workbench/parts/search/electron-browser/search.contribution'; // load contributions
import * as assert from 'assert';
import { IWorkspaceContextService } from 'vs/platform/workspace/common/workspace';
import { createSyncDescriptor } from 'vs/platform/instantiation/common/descriptors';
import { IEditorGroupsService } from 'vs/workbench/services/group/common/editorGroupsService';
import { ISearchService } from 'vs/platform/search/common/search';
import { ITelemetryService, ITelemetryInfo } from 'vs/platform/telemetry/common/telemetry';
import { IUntitledEditorService, UntitledEditorService } from 'vs/workbench/services/untitled/common/untitledEditorService';
import { IEditorService } from 'vs/workbench/services/editor/common/editorService';
import * as minimist from 'minimist';
import * as path from 'path';
import { IQuickOpenRegistry, Extensions } from 'vs/workbench/browser/quickopen';
import { Registry } from 'vs/platform/registry/common/platform';
import { SearchService } from 'vs/workbench/services/search/node/searchService';
import { ServiceCollection } from 'vs/platform/instantiation/common/serviceCollection';
import { TestEnvironmentService, TestContextService, TestEditorService, TestEditorGroupsService, TestTextResourcePropertiesService } from 'vs/workbench/test/workbenchTestServices';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { TPromise } from 'vs/base/common/winjs.base';
import { URI } from 'vs/base/common/uri';
import { InstantiationService } from 'vs/platform/instantiation/common/instantiationService';
import { TestConfigurationService } from 'vs/platform/configuration/test/common/testConfigurationService';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { ModelServiceImpl } from 'vs/editor/common/services/modelServiceImpl';
import { IModelService } from 'vs/editor/common/services/modelService';
import { testWorkspace } from 'vs/platform/workspace/test/common/testWorkspace';
import { CancellationToken } from 'vs/base/common/cancellation';
import { ITextResourcePropertiesService } from 'vs/editor/common/services/resourceConfiguration';

namespace Timer {
	export interface ITimerEvent {
		id: number;
		topic: string;
		name: string;
		description: string;
		data: any;

		startTime: Date;
		stopTime: Date;

		stop(stopTime?: Date): void;
		timeTaken(): number;
	}
}

declare var __dirname: string;

// Checkout sources to run against:
// git clone --separate-git-dir=testGit --no-checkout --single-branch https://chromium.googlesource.com/chromium/src testWorkspace
// cd testWorkspace; git checkout 39a7f93d67f7
// Run from repository root folder with (test.bat on Windows): ./scripts/test.sh --grep QuickOpen.performance --timeout 180000 --testWorkspace <path>
suite.skip('QuickOpen performance (integration)', () => {

	test('Measure', () => {
		if (process.env['VSCODE_PID']) {
			return void 0; // TODO@Christoph find out why test fails when run from within VS Code
		}

		const n = 3;
		const argv = minimist(process.argv);
		const testWorkspaceArg = argv['testWorkspace'];
		const verboseResults = argv['verboseResults'];
		const testWorkspacePath = testWorkspaceArg ? path.resolve(testWorkspaceArg) : __dirname;

		const telemetryService = new TestTelemetryService();
		const configurationService = new TestConfigurationService();
		const textResourcePropertiesService = new TestTextResourcePropertiesService(configurationService);
		const instantiationService = new InstantiationService(new ServiceCollection(
			[ITelemetryService, telemetryService],
			[IConfigurationService, configurationService],
			[ITextResourcePropertiesService, textResourcePropertiesService],
			[IModelService, new ModelServiceImpl(null, configurationService, textResourcePropertiesService)],
			[IWorkspaceContextService, new TestContextService(testWorkspace(URI.file(testWorkspacePath)))],
			[IEditorService, new TestEditorService()],
			[IEditorGroupsService, new TestEditorGroupsService()],
			[IEnvironmentService, TestEnvironmentService],
			[IUntitledEditorService, createSyncDescriptor(UntitledEditorService)],
			[ISearchService, createSyncDescriptor(SearchService)]
		));

		const registry = Registry.as<IQuickOpenRegistry>(Extensions.Quickopen);
		const descriptor = registry.getDefaultQuickOpenHandler();
		assert.ok(descriptor);

		function measure() {
			const handler = descriptor.instantiate(instantiationService);
			handler.onOpen();
			return handler.getResults('a', CancellationToken.None).then(result => {
				const uncachedEvent = popEvent();
				assert.strictEqual(uncachedEvent.data.symbols.fromCache, false, 'symbols.fromCache');
				assert.strictEqual(uncachedEvent.data.files.fromCache, true, 'files.fromCache');
				if (testWorkspaceArg) {
					assert.ok(!!uncachedEvent.data.files.joined, 'files.joined');
				}
				return uncachedEvent;
			}).then(uncachedEvent => {
				return handler.getResults('ab', CancellationToken.None).then(result => {
					const cachedEvent = popEvent();
					assert.strictEqual(uncachedEvent.data.symbols.fromCache, false, 'symbols.fromCache');
					assert.ok(cachedEvent.data.files.fromCache, 'filesFromCache');
					handler.onClose(false);
					return [uncachedEvent, cachedEvent];
				});
			});
		}

		function popEvent() {
			const events = telemetryService.events
				.filter(event => event.name === 'openAnything');
			assert.strictEqual(events.length, 1);
			const event = events[0];
			telemetryService.events.length = 0;
			return event;
		}

		function printResult(data: any) {
			if (verboseResults) {
				console.log(JSON.stringify(data, null, '  ') + ',');
			} else {
				console.log(JSON.stringify({
					filesfromCacheNotJoined: data.files.fromCache && !data.files.joined,
					searchLength: data.searchLength,
					sortedResultDuration: data.sortedResultDuration,
					filesResultCount: data.files.resultCount,
					errorCount: data.files.errors && data.files.errors.length || undefined
				}) + ',');
			}
		}

		return measure() // Warm-up first
			.then(() => {
				if (testWorkspaceArg || verboseResults) { // Don't measure by default
					const cachedEvents: Timer.ITimerEvent[] = [];
					let i = n;
					return (function iterate(): TPromise<Timer.ITimerEvent> {
						if (!i--) {
							return undefined;
						}
						return measure()
							.then(([uncachedEvent, cachedEvent]) => {
								printResult(uncachedEvent.data);
								cachedEvents.push(cachedEvent);
								return iterate();
							});
					})().then(() => {
						console.log();
						cachedEvents.forEach(cachedEvent => {
							printResult(cachedEvent.data);
						});
					});
				}
				return undefined;
			});
	});
});

class TestTelemetryService implements ITelemetryService {

	public _serviceBrand: any;
	public isOptedIn = true;

	public events: any[] = [];

	public publicLog(eventName: string, data?: any): TPromise<void> {
		this.events.push({ name: eventName, data: data });
		return TPromise.wrap<void>(null);
	}

	public getTelemetryInfo(): TPromise<ITelemetryInfo> {
		return TPromise.as({
			instanceId: 'someValue.instanceId',
			sessionId: 'someValue.sessionId',
			machineId: 'someValue.machineId'
		});
	}
}
