/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as Types from 'vs/base/common/types';

export const enum ValidationState {
	OK = 0,
	Info = 1,
	Warning = 2,
	Error = 3,
	Fatal = 4
}

export class ValidationStatus {
	private _state: ValidationState;

	constructor() {
		this._state = ValidationState.OK;
	}

	public get state(): ValidationState {
		return this._state;
	}

	public set state(value: ValidationState) {
		if (value > this._state) {
			this._state = value;
		}
	}

	public isOK(): boolean {
		return this._state === ValidationState.OK;
	}

	public isFatal(): boolean {
		return this._state === ValidationState.Fatal;
	}
}

export interface IProblemReporter {
	info(message: string): void;
	warn(message: string): void;
	error(message: string): void;
	fatal(message: string): void;
	status: ValidationStatus;
}

export abstract class Parser {

	private _problemReporter: IProblemReporter;

	constructor(problemReporter: IProblemReporter) {
		this._problemReporter = problemReporter;
	}

	public reset(): void {
		this._problemReporter.status.state = ValidationState.OK;
	}

	public get problemReporter(): IProblemReporter {
		return this._problemReporter;
	}

	public info(message: string): void {
		this._problemReporter.info(message);
	}

	public warn(message: string): void {
		this._problemReporter.warn(message);
	}

	public error(message: string): void {
		this._problemReporter.error(message);
	}

	public fatal(message: string): void {
		this._problemReporter.fatal(message);
	}

	protected static merge<T>(destination: T, source: T, overwrite: boolean): void {
		Object.keys(source).forEach((key: string) => {
			let destValue = destination[key];
			let sourceValue = source[key];
			if (Types.isUndefined(sourceValue)) {
				return;
			}
			if (Types.isUndefined(destValue)) {
				destination[key] = sourceValue;
			} else {
				if (overwrite) {
					if (Types.isObject(destValue) && Types.isObject(sourceValue)) {
						this.merge(destValue, sourceValue, overwrite);
					} else {
						destination[key] = sourceValue;
					}
				}
			}
		});
	}
}