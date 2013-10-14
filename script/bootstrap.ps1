git submodule --quiet sync
git submodule --quiet update --recursive --init

cd vendor/apm
npm install --silent .

cd ../..
npm install --silent vendor/apm

./node_modules/.bin/apm.cmd install --silent
