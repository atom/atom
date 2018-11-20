/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
import * as vscode from 'vscode';
import * as arrays from './arrays';

export enum TsServerLogLevel {
	Off,
	Normal,
	Terse,
	Verbose,
}

export namespace TsServerLogLevel {
	export function fromString(value: string): TsServerLogLevel {
		switch (value && value.toLowerCase()) {
			case 'normal':
				return TsServerLogLevel.Normal;
			case 'terse':
				return TsServerLogLevel.Terse;
			case 'verbose':
				return TsServerLogLevel.Verbose;
			case 'off':
			default:
				return TsServerLogLevel.Off;
		}
	}

	export function toString(value: TsServerLogLevel): string {
		switch (value) {
			case TsServerLogLevel.Normal:
				return 'normal';
			case TsServerLogLevel.Terse:
				return 'terse';
			case TsServerLogLevel.Verbose:
				return 'verbose';
			case TsServerLogLevel.Off:
			default:
				return 'off';
		}
	}
}

export class TypeScriptServiceConfiguration {
	public readonly locale: string | null;
	public readonly globalTsdk: string | null;
	public readonly localTsdk: string | null;
	public readonly npmLocation: string | null;
	public readonly tsServerLogLevel: TsServerLogLevel = TsServerLogLevel.Off;
	public readonly tsServerPluginPaths: string[];
	public readonly checkJs: boolean;
	public readonly experimentalDecorators: boolean;
	public readonly disableAutomaticTypeAcquisition: boolean;

	public static loadFromWorkspace(): TypeScriptServiceConfiguration {
		return new TypeScriptServiceConfiguration();
	}

	private constructor() {
		const configuration = vscode.workspace.getConfiguration();

		this.locale = TypeScriptServiceConfiguration.extractLocale(configuration);
		this.globalTsdk = TypeScriptServiceConfiguration.extractGlobalTsdk(configuration);
		this.localTsdk = TypeScriptServiceConfiguration.extractLocalTsdk(configuration);
		this.npmLocation = TypeScriptServiceConfiguration.readNpmLocation(configuration);
		this.tsServerLogLevel = TypeScriptServiceConfiguration.readTsServerLogLevel(configuration);
		this.tsServerPluginPaths = TypeScriptServiceConfiguration.readTsServerPluginPaths(configuration);
		this.checkJs = TypeScriptServiceConfiguration.readCheckJs(configuration);
		this.experimentalDecorators = TypeScriptServiceConfiguration.readExperimentalDecorators(configuration);
		this.disableAutomaticTypeAcquisition = TypeScriptServiceConfiguration.readDisableAutomaticTypeAcquisition(configuration);
	}

	public isEqualTo(other: TypeScriptServiceConfiguration): boolean {
		return this.locale === other.locale
			&& this.globalTsdk === other.globalTsdk
			&& this.localTsdk === other.localTsdk
			&& this.npmLocation === other.npmLocation
			&& this.tsServerLogLevel === other.tsServerLogLevel
			&& this.checkJs === other.checkJs
			&& this.experimentalDecorators === other.experimentalDecorators
			&& this.disableAutomaticTypeAcquisition === other.disableAutomaticTypeAcquisition
			&& arrays.equals(this.tsServerPluginPaths, other.tsServerPluginPaths);
	}

	private static extractGlobalTsdk(configuration: vscode.WorkspaceConfiguration): string | null {
		const inspect = configuration.inspect('typescript.tsdk');
		if (inspect && inspect.globalValue && 'string' === typeof inspect.globalValue) {
			return inspect.globalValue;
		}
		return null;
	}

	private static extractLocalTsdk(configuration: vscode.WorkspaceConfiguration): string | null {
		const inspect = configuration.inspect('typescript.tsdk');
		if (inspect && inspect.workspaceValue && 'string' === typeof inspect.workspaceValue) {
			return inspect.workspaceValue;
		}
		return null;
	}

	private static readTsServerLogLevel(configuration: vscode.WorkspaceConfiguration): TsServerLogLevel {
		const setting = configuration.get<string>('typescript.tsserver.log', 'off');
		return TsServerLogLevel.fromString(setting);
	}

	private static readTsServerPluginPaths(configuration: vscode.WorkspaceConfiguration): string[] {
		return configuration.get<string[]>('typescript.tsserver.pluginPaths', []);
	}

	private static readCheckJs(configuration: vscode.WorkspaceConfiguration): boolean {
		return configuration.get<boolean>('javascript.implicitProjectConfig.checkJs', false);
	}

	private static readExperimentalDecorators(configuration: vscode.WorkspaceConfiguration): boolean {
		return configuration.get<boolean>('javascript.implicitProjectConfig.experimentalDecorators', false);
	}

	private static readNpmLocation(configuration: vscode.WorkspaceConfiguration): string | null {
		return configuration.get<string | null>('typescript.npm', null);
	}

	private static readDisableAutomaticTypeAcquisition(configuration: vscode.WorkspaceConfiguration): boolean {
		return configuration.get<boolean>('typescript.disableAutomaticTypeAcquisition', false);
	}

	private static extractLocale(configuration: vscode.WorkspaceConfiguration): string | null {
		return configuration.get<string | null>('typescript.locale', null);
	}
}
