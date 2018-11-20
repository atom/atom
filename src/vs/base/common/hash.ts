/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

/**
 * Return a hash value for an object.
 */
export function hash(obj: any, hashVal = 0): number {
	switch (typeof obj) {
		case 'object':
			if (obj === null) {
				return numberHash(349, hashVal);
			} else if (Array.isArray(obj)) {
				return arrayHash(obj, hashVal);
			}
			return objectHash(obj, hashVal);
		case 'string':
			return stringHash(obj, hashVal);
		case 'boolean':
			return booleanHash(obj, hashVal);
		case 'number':
			return numberHash(obj, hashVal);
		case 'undefined':
			return numberHash(0, 937);
		default:
			return numberHash(0, 617);
	}
}

function numberHash(val: number, initialHashVal: number): number {
	return (((initialHashVal << 5) - initialHashVal) + val) | 0;  // hashVal * 31 + ch, keep as int32
}

function booleanHash(b: boolean, initialHashVal: number): number {
	return numberHash(b ? 433 : 863, initialHashVal);
}

function stringHash(s: string, hashVal: number) {
	hashVal = numberHash(149417, hashVal);
	for (let i = 0, length = s.length; i < length; i++) {
		hashVal = numberHash(s.charCodeAt(i), hashVal);
	}
	return hashVal;
}

function arrayHash(arr: any[], initialHashVal: number): number {
	initialHashVal = numberHash(104579, initialHashVal);
	return arr.reduce((hashVal, item) => hash(item, hashVal), initialHashVal);
}

function objectHash(obj: any, initialHashVal: number): number {
	initialHashVal = numberHash(181387, initialHashVal);
	return Object.keys(obj).sort().reduce((hashVal, key) => {
		hashVal = stringHash(key, hashVal);
		return hash(obj[key], hashVal);
	}, initialHashVal);
}

export class Hasher {

	private _value = 0;

	get value(): number {
		return this._value;
	}

	hash(obj: any): number {
		this._value = hash(obj, this._value);
		return this._value;
	}
}