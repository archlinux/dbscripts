/* $Id: pkgdb2-del.c,v 1.1 2006/07/06 03:37:01 judd Exp $ */

#include <stdio.h>
#include <stdlib.h>
#include <mysql.h>
#include <string.h>
#include <limits.h>

#define DB_USER "archweb"
#define DB_NAME "archweb"
#define DB_PASS "passwords-are-cool"

typedef struct pkg {
	unsigned int id;
	char *name;
	char *ver;
	char *rel;
	struct pkg *next;
} pkg_t;

MYSQL_RES *doquery(MYSQL *m, const char* q)
{
	MYSQL_RES *res;
		if(mysql_query(m, q)) {
			fprintf(stderr, "mysql_query: %s\n", mysql_error(m));
			return(NULL);
		}
		res = mysql_store_result(m);
		return(res);
}

/* this function is ugly -- it malloc's for each string it
 * returns, and they probably won't be freed by the caller.
 */
char* addslashes(const char *s) {
	char slashed[8192];
	char *p;
 
	slashed[0] = '\0';
	p = slashed;
	while(*s) {
		if(*s == '\'' || *s == '"' || *s == '\\') {
			*p++ = '\\';
		}
		*p++ = *s++;
	}
	*p = '\0';
	return(strdup(slashed));
}

char* trim(char *str)
{
	char *pch = str;
	while(isspace(*pch)) {
		pch++;
	}
	if(pch != str) {
		memmove(str, pch, (strlen(pch) + 1));
	}
	
	pch = (char*)(str + (strlen(str) - 1));
	while(isspace(*pch)) {
		pch--;
	}
	*++pch = '\0';

	return str;
}

int main(int argc, char **argv)
{
	MYSQL db;
	MYSQL_RES *result;
	MYSQL_ROW row;
	char query[4096];
	char fn[PATH_MAX];
	char ftppath[PATH_MAX];
	int repoid;
	pkg_t *pkglist = NULL;
	pkg_t *pkgptr, *ptr;

	if(argc < 3) {
		printf("usage: pkgdb2-del <repoid> <ftp_repo_root>\n");
		printf("\nWARNING: Do not run this manually! It is intended to be run from\n"
				"the Arch db-generation scripts.\n\n");
		return(1);
	}
	repoid = atoi(argv[1]);
	strncpy(ftppath, argv[2], PATH_MAX-1);

	if(mysql_init(&db) == NULL) {
		fprintf(stderr, "could not initialize\n");
		return(1);
	}
	if(mysql_real_connect(&db, "localhost", DB_USER, DB_PASS, DB_NAME,
			0, NULL, 0) == NULL) {
		fprintf(stderr, "failed to connect to database: %s\n", mysql_error(&db));
		return(1);
	}

	while(!feof(stdin)) {
		int found = 0;
		unsigned int catid = 0;
		unsigned int pkgid = 0;
		char name[256];
		/* get package data from stdin */
		fgets(name, 256, stdin);
		trim(name);
		if(feof(stdin)) continue;
		/* check for overruns */
		if(strlen(name) > 254) {
			fprintf(stderr, "pkgdb2-del: one or more fields are too long in package '%s'\n", name);
			return(1);
		}
		/* get the package id */
		snprintf(query, sizeof(query), "SELECT id FROM packages WHERE "
				"repoid='%d' AND pkgname='%s'", repoid, addslashes(name));
		result = doquery(&db, query);
		if(mysql_num_rows(result) == 0) {
			fprintf(stderr, "pkgdb2-del: %s was not found in repo %d\n", name, repoid);
			continue;
		}
		row = mysql_fetch_row(result);
		pkgid = (unsigned int)atoi(row[0]);
		/* delete from db */
		fprintf(stderr, "pkgdb2-del: deleting %s (id %d)\n", name, pkgid);
		snprintf(query, sizeof(query), "DELETE FROM packages WHERE id='%d'", pkgid);
		doquery(&db, query);
		snprintf(query, sizeof(query), "DELETE FROM packages_files WHERE id='%d'", pkgid);
		doquery(&db, query);
		snprintf(query, sizeof(query), "DELETE FROM todolist_pkgs WHERE pkgid='%d'", pkgid);
		doquery(&db, query);
	}
	
	mysql_close(&db);
	return(0);
}
