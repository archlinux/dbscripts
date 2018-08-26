# Arch Linux repository management scripts [![Build Status](https://travis-ci.org/archlinux/dbscripts.svg?branch=master)](https://travis-ci.org/archlinux/dbscripts)
## Configuration
* The default configuration can be found in `config`.
* An optional `config.local` may override the default configuration.
* The path and name of the local configuration file can be overridden by setting the `DBSCRIPTS_CONFIG` environment variable.
## Overview
The executables that you (might) care about are:

    dbscripts/
    ├── cron-jobs/
    │   ├── devlist-mailer
    │   ├── ftpdir-cleanup
    │   ├── integrity-check
    │   └── sourceballs
    ├── db-move
    ├── db-remove
    ├── db-repo-add
    ├── db-repo-remove
    ├── db-update
    └── testing2x

Ok, now let's talk about what those are.

There are 3 "main" programs:

 - `db-update` : add packages to repositories
 - `db-remove` : remove packages from repositories
 - `db-move`   : move packages from one repository to another

Moving packages from testing to stable repositories is such a common
task that we have a wrapper around `db-move` to make it easier:

 - `testing2x`

Of course, sometimes things go wrong, and you need to drop to a
lower-level, but you don't want to go all the way down to pacman's
`repo-add`/`repo-remove`.  So, we have:

 - `db-repo-add`
 - `db-repo-remove`

Now, we'd like to be able to check that the repos are all OK, so we
have

 - `cron-jobs/integrity-check`

When we remove a package from a repository, it stays in the package
"pool".  We would like to be able to eventually remove packages from
the pool, to reclaim the disk space:

 - `cron-jobs/ftpdir-cleanup`

Things that haven't been mentioned yet:

 - `cron-jobs/devlist-mailer`
 - `cron-jobs/sourceballs`
## Testing
* Install the `make` and `docker` packages. Start the docker daemon by issuing `systemctl start docker`.
* The test suite can now be run with `make test`.
* A coverage report can be generated with `make test-coverage`. Open `coverage/index.html` in your web browser to inspect the results.
