/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import 'vs/workbench/parts/search/electron-browser/search.contribution'; // load contributions
import * as assert from 'assert';
import * as fs from 'fs';
import { IWorkspaceContextService } from 'vs/platform/workspace/common/workspace';
import { createSyncDescriptor } from 'vs/platform/instantiation/common/descriptors';
import { IEditorGroupsService } from 'vs/workbench/services/group/common/editorGroupsService';
import { ISearchService } from 'vs/platform/search/common/search';
import { ITelemetryService, ITelemetryInfo } from 'vs/platform/telemetry/common/telemetry';
import { IUntitledEditorService, UntitledEditorService } from 'vs/workbench/services/untitled/common/untitledEditorService';
import { IEditorService } from 'vs/workbench/services/editor/common/editorService';
import * as minimist from 'minimist';
import * as path from 'path';
import { SearchService } from 'vs/workbench/services/search/node/searchService';
import { ServiceCollection } from 'vs/platform/instantiation/common/serviceCollection';
import { TestEnvironmentService, TestContextService, TestEditorService, TestEditorGroupsService, TestTextResourcePropertiesService } from 'vs/workbench/test/workbenchTestServices';
import { IEnvironmentService } from 'vs/platform/environment/common/environment';
import { URI } from 'vs/base/common/uri';
import { InstantiationService } from 'vs/platform/instantiation/common/instantiationService';
import { TestConfigurationService } from 'vs/platform/configuration/test/common/testConfigurationService';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { ModelServiceImpl } from 'vs/editor/common/services/modelServiceImpl';
import { IModelService } from 'vs/editor/common/services/modelService';

import { SearchModel } from 'vs/workbench/parts/search/common/searchModel';
import { QueryBuilder, ITextQueryBuilderOptions } from 'vs/workbench/parts/search/common/queryBuilder';

import * as event from 'vs/base/common/event';
import { testWorkspace } from 'vs/platform/workspace/test/common/testWorkspace';
import { NullLogService, ILogService } from 'vs/platform/log/common/log';
import { ITextResourcePropertiesService } from 'vs/editor/common/services/resourceConfiguration';

declare var __dirname: string;

// Checkout sources to run against:
// git clone --separate-git-dir=testGit --no-checkout --single-branch https://chromium.googlesource.com/chromium/src testWorkspace
// cd testWorkspace; git checkout 39a7f93d67f7
// Run from repository root folder with (test.bat on Windows): ./scripts/test-int-mocha.sh --grep TextSearch.performance --timeout 500000 --testWorkspace <path>
suite.skip('TextSearch performance (integration)', () => {

	test('Measure', () => {
		if (process.env['VSCODE_PID']) {
			return undefined; // TODO@Rob find out why test fails when run from within VS Code
		}

		const n = 3;
		const argv = minimist(process.argv);
		const testWorkspaceArg = argv['testWorkspace'];
		const testWorkspacePath = testWorkspaceArg ? path.resolve(testWorkspaceArg) : __dirname;
		if (!fs.existsSync(testWorkspacePath)) {
			throw new Error(`--testWorkspace doesn't exist`);
		}

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
			[ISearchService, createSyncDescriptor(SearchService)],
			[ILogService, new NullLogService()]
		));

		const queryOptions: ITextQueryBuilderOptions = {
			maxResults: 2048
		};

		const searchModel: SearchModel = instantiationService.createInstance(SearchModel);
		function runSearch(): Promise<any> {
			const queryBuilder: QueryBuilder = instantiationService.createInstance(QueryBuilder);
			const query = queryBuilder.text({ pattern: 'static_library(' }, [URI.file(testWorkspacePath)], queryOptions);

			// Wait for the 'searchResultsFinished' event, which is fired after the search() promise is resolved
			const onSearchResultsFinished = event.filterEvent(telemetryService.eventLogged, e => e.name === 'searchResultsFinished');
			event.once(onSearchResultsFinished)(onComplete);

			function onComplete(): void {
				try {
					const allEvents = telemetryService.events.map(e => JSON.stringify(e)).join('\n');
					assert.equal(telemetryService.events.length, 3, 'Expected 3 telemetry events, got:\n' + allEvents);

					const [firstRenderEvent, resultsShownEvent, resultsFinishedEvent] = telemetryService.events;
					assert.equal(firstRenderEvent.name, 'searchResultsFirstRender');
					assert.equal(resultsShownEvent.name, 'searchResultsShown');
					assert.equal(resultsFinishedEvent.name, 'searchResultsFinished');

					telemetryService.events = [];

					resolve(resultsFinishedEvent);
				} catch (e) {
					// Fail the runSearch() promise
					error(e);
				}
			}

			let resolve;
			let error;
			return new Promise((_resolve, _error) => {
				resolve = _resolve;
				error = _error;

				// Don't wait on this promise, we're waiting on the event fired above
				searchModel.search(query).then(
					null,
					_error);
			});
		}

		const finishedEvents = [];
		return runSearch() // Warm-up first
			.then(() => {
				if (testWorkspaceArg) { // Don't measure by default
					let i = n;
					return (function iterate() {
						if (!i--) {
							return;
						}

						return runSearch()
							.then((resultsFinishedEvent: any) => {
								console.log(`Iteration ${n - i}: ${resultsFinishedEvent.data.duration / 1000}s`);
								finishedEvents.push(resultsFinishedEvent);
								return iterate();
							});
					})().then(() => {
						const totalTime = finishedEvents.reduce((sum, e) => sum + e.data.duration, 0);
						console.log(`Avg duration: ${totalTime / n / 1000}s`);
					});
				}
			});
	});
});

class TestTelemetryService implements ITelemetryService {
	public _serviceBrand: any;
	public isOptedIn = true;

	public events: any[] = [];

	private emitter = new event.Emitter<any>();

	public get eventLogged(): event.Event<any> {
		return this.emitter.event;
	}

	public publicLog(eventName: string, data?: any): Promise<void> {
		const event = { name: eventName, data: data };
		this.events.push(event);
		this.emitter.fire(event);
		return Promise.resolve();
	}

	public getTelemetryInfo(): Promise<ITelemetryInfo> {
		return Promise.resolve({
			instanceId: 'someValue.instanceId',
			sessionId: 'someValue.sessionId',
			machineId: 'someValue.machineId'
		});
	}
}
