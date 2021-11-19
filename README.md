# Arch Linux repository management scripts
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
* Install the `make` and `podman` or `docker` packages depending on your
preferrence. The default expects docker but pomdan can be used if
`DOCKER=podman` is specified. When using docker, start the docker daemon by
issuing `systemctl start docker`.
* The test suite can now be run with `make test`.
* A coverage report can be generated with `make test-coverage`. Open `coverage/index.html` in your web browser to inspect the results.

Bats arguments or specific test can be run by providing `CASES` and `BATS_ARGS`:

```
make test DOCKER=podman CASES=cases/db-update.bats BATS_ARGS='-f Wrong'
```

## License
For a long time, dbscripts didn't have an explicit license. Currently it is
primarily licensed under the GPL-2.0-or-later, but some code is of unknown
license. Details on clarifying the license status may be found in LICENSE_STATUS.md

tl;dr

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/.
