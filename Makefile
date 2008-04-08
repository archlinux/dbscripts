# mysql db info.
DB_NAME:="archlinux"
DB_USER:="archlinux"
DB_PASS:="passwords-are-NOT-cool"

MYSQL_DEFS:=-DDB_NAME=\"$(DB_NAME)\" -DDB_USER=\"$(DB_USER)\" -DDB_PASS=\"$(DB_PASS)\"
MYSQL_FLAGS:=-I/usr/include/mysql -L/usr/lib/mysql -lmysqlclient

all: pkgdb2-add pkgdb2-del

pkgdb2-add: pkgdb2-add.c
	gcc $(MYSQL_DEFS) $(MYSQL_FLAGS) -o pkgdb2-add pkgdb2-add.c

pkgdb2-del: pkgdb2-del.c
	gcc $(MYSQL_DEFS) $(MYSQL_FLAGS) -o pkgdb2-del pkgdb2-del.c

clean:
	rm -f pkgdb2-add pkgdb2-del

.PHONY: all clean
