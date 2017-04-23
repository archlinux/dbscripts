# Arch Linux repository management scripts
## Configuration
* The default configuration can be found in `config`.
* An optional `config.local` may override the default configuration.
* The path and name of the local configuration file can be overriden by setting the `DBSCRIPTS_CONFIG` environment variable.
## Testing
* Install the `make` and `docker` packages. Start the docker daemon by issuing `systemctl start docker`.
* The test suite can now be run with `make test`.
* A coverage report can be generated with `make test-coverage`. Open `coverage/index.html` in your web browser to inspect the results.
