rm /home/fox/Git/prosjekter/Bash/dbscripts/test-dbscripts/ftp/core/os/x86_64/* || true
rm /home/fox/Git/prosjekter/Bash/dbscripts/test-dbscripts/ftp/pool/packages/* || true
rm /home/fox/Git/prosjekter/Bash/dbscripts/test-dbscripts/ftp/extra/os/x86_64/* || true
cp ~/.cache/makepkg/pkgdest/hello-1-1-x86_64.pkg.tar.zst /home/fox/Git/prosjekter/Bash/dbscripts/test-dbscripts/staging/core
cp ~/.cache/makepkg/pkgdest/hello-1-1-x86_64.pkg.tar.zst.sig /home/fox/Git/prosjekter/Bash/dbscripts/test-dbscripts/staging/core
DBSCRIPTS_CONFIG=./config.local.svn-packages ./db-update
DBSCRIPTS_CONFIG=./config.local.svn-packages ./db-move core extra hello
DBSCRIPTS_CONFIG=./config.local.svn-packages ./db-remove extra x86_64 hello
