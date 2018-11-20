/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as nls from 'vs/nls';
import { assign, deepClone } from 'vs/base/common/objects';
import { IConfigurationService } from 'vs/platform/configuration/common/configuration';
import { IWindowsService } from 'vs/platform/windows/common/windows';
import { ITelemetryService } from 'vs/platform/telemetry/common/telemetry';
import { crashReporter } from 'electron';
import product from 'vs/platform/node/product';
import pkg from 'vs/platform/node/package';
import * as os from 'os';
import { isWindows, isMacintosh, isLinux } from 'vs/base/common/platform';
import { createDecorator } from 'vs/platform/instantiation/common/instantiation';
import { IConfigurationRegistry, Extensions } from 'vs/platform/configuration/common/configurationRegistry';
import { Registry } from 'vs/platform/registry/common/platform';

export const ICrashReporterService = createDecorator<ICrashReporterService>('crashReporterService');

export const TELEMETRY_SECTION_ID = 'telemetry';

export interface ICrashReporterConfig {
	enableCrashReporter: boolean;
}

const configurationRegistry = Registry.as<IConfigurationRegistry>(Extensions.Configuration);
configurationRegistry.registerConfiguration({
	'id': TELEMETRY_SECTION_ID,
	'order': 110,
	title: nls.localize('telemetryConfigurationTitle', "Telemetry"),
	'type': 'object',
	'properties': {
		'telemetry.enableCrashReporter': {
			'type': 'boolean',
			'description': nls.localize('telemetry.enableCrashReporting', "Enable crash reports to be sent to a Microsoft online service. \nThis option requires restart to take effect."),
			'default': true,
			'tags': ['usesOnlineServices']
		}
	}
});

export interface ICrashReporterService {
	_serviceBrand: any;
	getChildProcessStartOptions(processName: string): Electron.CrashReporterStartOptions | undefined; // TODO
}

export const NullCrashReporterService: ICrashReporterService = {
	_serviceBrand: undefined,
	getChildProcessStartOptions(processName: string) { return undefined; }
};

export class CrashReporterService implements ICrashReporterService {

	_serviceBrand: any;

	private options: Electron.CrashReporterStartOptions;
	private isEnabled: boolean;

	constructor(
		@ITelemetryService private telemetryService: ITelemetryService,
		@IWindowsService private windowsService: IWindowsService,
		@IConfigurationService configurationService: IConfigurationService
	) {
		const config = configurationService.getValue<ICrashReporterConfig>(TELEMETRY_SECTION_ID);
		this.isEnabled = !!config.enableCrashReporter;

		if (this.isEnabled) {
			this.startCrashReporter();
		}
	}

	private startCrashReporter(): void {

		// base options with product info
		this.options = {
			companyName: product.crashReporter.companyName,
			productName: product.crashReporter.productName,
			submitURL: this.getSubmitURL(),
			extra: {
				vscode_version: pkg.version,
				vscode_commit: product.commit
			}
		};

		// mixin telemetry info
		this.telemetryService.getTelemetryInfo()
			.then(info => {
				assign(this.options.extra, {
					vscode_sessionId: info.sessionId
				});

				// start crash reporter right here
				crashReporter.start(deepClone(this.options));

				// start crash reporter in the main process
				return this.windowsService.startCrashReporter(this.options);
			});
	}

	private getSubmitURL(): string {
		if (isWindows) {
			return product.hockeyApp[`win32-${process.arch}`];
		} else if (isMacintosh) {
			return product.hockeyApp.darwin;
		} else if (isLinux) {
			return product.hockeyApp[`linux-${process.arch}`];
		}
		throw new Error('Unknown platform');
	}

	getChildProcessStartOptions(name: string): Electron.CrashReporterStartOptions | undefined {

		// Experimental crash reporting support for child processes on Mac only for now
		if (this.isEnabled && isMacintosh) {
			const childProcessOptions = deepClone(this.options);
			(<any>childProcessOptions.extra).processName = name;
			childProcessOptions.crashesDirectory = os.tmpdir();

			return childProcessOptions;
		}

		return void 0;
	}
}
