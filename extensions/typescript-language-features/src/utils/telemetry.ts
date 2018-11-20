/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import VsCodeTelemetryReporter from 'vscode-extension-telemetry';
import { memoize } from './memoize';

interface PackageInfo {
	readonly name: string;
	readonly version: string;
	readonly aiKey: string;
}

export default class TelemetryReporter {
	private _reporter: VsCodeTelemetryReporter | null = null;

	dispose() {
		if (this._reporter) {
			this._reporter.dispose();
			this._reporter = null;
		}
	}

	constructor(
		private readonly clientVersionDelegate: () => string
	) { }

	public logTelemetry(eventName: string, properties?: { [prop: string]: string }) {
		const reporter = this.reporter;
		if (reporter) {
			if (!properties) {
				properties = {};
			}

			/* __GDPR__FRAGMENT__
				"TypeScriptCommonProperties" : {
					"version" : { "classification": "SystemMetaData", "purpose": "FeatureInsight" }
				}
			*/
			properties['version'] = this.clientVersionDelegate();

			reporter.sendTelemetryEvent(eventName, properties);
		}
	}

	@memoize
	private get reporter(): VsCodeTelemetryReporter | null {
		if (this.packageInfo && this.packageInfo.aiKey) {
			this._reporter = new VsCodeTelemetryReporter(
				this.packageInfo.name,
				this.packageInfo.version,
				this.packageInfo.aiKey);
			return this._reporter;
		}
		return null;
	}

	@memoize
	private get packageInfo(): PackageInfo | null {
		const { packageJSON } = vscode.extensions.getExtension('vscode.typescript-language-features')!;
		if (packageJSON) {
			return {
				name: packageJSON.name,
				version: packageJSON.version,
				aiKey: packageJSON.aiKey
			};
		}
		return null;
	}
}
