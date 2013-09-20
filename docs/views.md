# Installing custom CouchDB views

From the root of this repository:

* Run `npm install` to install the `couchapp` dependency.
* Run `grunt` to compile the CoffeeScript to JavaScript.
* Run the following to push the views (replace the `PASSWORD`):

```sh
couchapp push lib/couch/app.js https://atom:PASSWORD@atom.cloudant.com/registry
```

* Visit [here](http://atom.cloudant.com/registry/_design/apm/_view/atom_packages)
  to see the deployed view.
