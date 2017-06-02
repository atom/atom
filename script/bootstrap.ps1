git submodule --quiet sync
git submodule --quiet update --recursive --init

if (!(Get-Command "npm")) {
    Write-Error "You need to install Node and have npm on the PATH"
    Break
}

cd vendor/apm
npm install --silent .

cd ../..
npm install --silent vendor/apm

./node_modules/.bin/apm.cmd install --silent
