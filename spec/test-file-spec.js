const chai = require('chai')
const expect = chai.expect
const fs = require('fs');
const assert = require('assert');

const file_name = 'test_file.txt'
const path = `./${file_name}`;

async function get_files(file_path) {
	return fs.readFile(path, (err, data) => {
		if (err) throw err;
		return data;
	})
}

describe("Open a file with name conflict with existing folder", () => {
	it('read files', () => {
		return get_files(path).then(res => {
			assert.equal(res, file_name);
		})
	})
});


