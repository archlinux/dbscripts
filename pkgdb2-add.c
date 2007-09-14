/* $Id: pkgdb2-add.c,v 1.3 2007/09/14 23:23:38 thomas Exp $ */

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

/* scan a .pkg.tar.gz file and put all files listed into the database.
 *
 * this function is hacky and should be done properly, but this route is
 * easier than reading the file with libtar.
 */
void updatefilelist(MYSQL *db, unsigned long id, char *fn)
{
	FILE *fp;
	char *tmp;
	char cmd[PATH_MAX];
	char line[PATH_MAX];
	char query[PATH_MAX];

	tmp = tempnam("/tmp", "pkgdb");
	snprintf(cmd, PATH_MAX-1, "/bin/tar tzvf %s | awk '{print $6}' >%s", fn, tmp);
	system(cmd);
	fp = fopen(tmp, "r");
	if(fp == NULL) {
		fprintf(stderr, "pkgdb2-add: could not open tempfile: %s\n", tmp);
		return;
	}
	snprintf(query, sizeof(query), "DELETE FROM packages_files WHERE pkg_id='%lu'", id);
	doquery(db, query);
	while(fgets(line, sizeof(line)-1, fp)) {
		char *fixedfn = addslashes(trim(line));
		if(!strcmp(fixedfn, ".FILELIST") || !strcmp(fixedfn, ".PKGINFO") || !strcmp(fixedfn, ".INSTALL")) {
			free(fixedfn);
			continue;
		}
		/* varchars aren't case-sensitive but filesystems are, so we use REPLACE INTO */
		snprintf(query, sizeof(query), "REPLACE INTO packages_files (pkg_id,path) VALUES "
				"('%lu', '%s')", id, fixedfn);
		free(fixedfn);
		doquery(db, query);
	}
	fclose(fp);
	unlink(tmp);
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
	pkg_t *dblist = NULL;
	pkg_t *pkglist = NULL;
	pkg_t *pkgptr, *ptr;

	if(argc < 3) {
		printf("usage: pkgdb2-add <repoid> <ftp_repo_root>\n");
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
	snprintf(query, sizeof(query), "SELECT id,pkgname,pkgver,pkgrel FROM packages "
			"WHERE repo_id='%d'", repoid);
	result = doquery(&db, query);
	while(row = mysql_fetch_row(result)) {
		int i;
		/*unsigned long *lengths;
		lengths = mysql_fetch_lengths(result);*/
		/* add the node to the list */
		if(dblist == NULL) {
			dblist = (pkg_t*)malloc(sizeof(pkg_t));
			if(dblist == NULL) {
				fprintf(stderr, "error: out of memory!\n");
				return(1);
			}
			ptr = dblist;
		} else {
			ptr->next = (pkg_t*)malloc(sizeof(pkg_t));
			if(ptr->next == NULL) {
				fprintf(stderr, "error: out of memory!\n");
				return(1);
			}
			ptr = ptr->next;
		}
		ptr->next = NULL;
		/* pick out the fields */
		ptr->id = atoi(row[0]);
		ptr->name = strdup(row[1]);
		ptr->ver = strdup(row[2]);
		ptr->rel = strdup(row[3]);
	}
	mysql_free_result(result);

	while(!feof(stdin)) {
		int found = 0;
		unsigned int catid = 0;
		char name[256], ver[256], rel[256], desc[4096];
		char cat[256], url[256], sources[4096], deplist[4096];
                char pkgfile[4096];
		/* get package data from stdin */
                fgets(pkgfile, 4096, stdin); trim(pkgfile); if(feof(stdin)) continue;
                fgets(name, 256, stdin);     trim(name);    if(feof(stdin)) continue;
		fgets(ver, 256, stdin);      trim(ver);     if(feof(stdin)) continue;
		fgets(rel, 256, stdin);      trim(rel);     if(feof(stdin)) continue;
		fgets(desc, 4096, stdin);    trim(desc);    if(feof(stdin)) continue;
		fgets(cat, 256, stdin);      trim(cat);     if(feof(stdin)) continue;
		fgets(url, 256, stdin);      trim(url);     if(feof(stdin)) continue;
		fgets(sources, 4096, stdin); trim(sources); if(feof(stdin)) continue;
		fgets(deplist, 4096, stdin); trim(deplist); if(feof(stdin)) continue;
		/* check for overruns */
		if(strlen(name) > 254 || strlen(ver) >= 254 || strlen(rel) > 254 ||
				strlen(desc) > 4094 || strlen(cat) >= 254 || strlen(url) > 254 ||
				strlen(sources) > 4094 || strlen(deplist) > 4094 || strlen(pkgfile) > 4094) {
			fprintf(stderr, "pkgdb2-add: one or more fields are too long in package '%s'\n", name);
			fprintf(stderr, "pkgdb2-add: check the lengths of your strings, most are limited "
					"to 255 chars, some are 4095\n");
			return(1);
		}
		/* add the node to the list */
		if(pkglist == NULL) {
			pkglist = (pkg_t*)malloc(sizeof(pkg_t));
			if(pkglist == NULL) {
				fprintf(stderr, "error: out of memory!\n");
				return(1);
			}
			pkgptr = pkglist;
		} else {
			pkgptr->next = (pkg_t*)malloc(sizeof(pkg_t));
			if(pkgptr->next == NULL) {
				fprintf(stderr, "error: out of memory!\n");
				return(1);
			}
			pkgptr = pkgptr->next;
		}
		pkgptr->next = NULL;
		pkgptr->name = strdup(name);
		/* look it up in our cache */
		for(ptr = dblist; ptr; ptr = ptr->next) {
			if(!strcmp(name, ptr->name)) {
				found = 1;
				break;
			}
		}
		/* get the category */
		snprintf(query, sizeof(query),
				"SELECT id FROM categories WHERE category='%s'", cat);
		result = doquery(&db, query);
		if(mysql_num_rows(result) == 0) {
			fprintf(stderr, "pkgdb2-add: no db category found for '%s'\n", cat);
			/*
			snprintf(query, sizeof(query), "INSERT INTO categories (id,category) "
					" VALUES (NULL,'%s')", addslashes(cat));
			doquery(&db, query);
			catid = (unsigned int)mysql_insert_id(&db);
			*/
		} else {
			row = mysql_fetch_row(result);
			catid = (unsigned int)atoi(row[0]);
		}
		if(!found) {
			/* Insert... */
			unsigned long id;
			fprintf(stderr, "pkgdb2-add: inserting %s\n", name);
			snprintf(query, sizeof(query), "INSERT INTO packages (id,repo_id,"
					"category_id,pkgname,pkgver,pkgrel,pkgdesc,url,sources,depends,"
					"last_update) VALUES (NULL,'%d','%d','%s','%s','%s','%s',"
					"'%s','%s','%s',NOW())",
					repoid, catid, addslashes(name), addslashes(ver), addslashes(rel),
					addslashes(desc), addslashes(url), addslashes(sources),
					addslashes(deplist));
			doquery(&db, query);
			id = mysql_insert_id(&db);
			snprintf(fn, PATH_MAX-1, "%s/%s", ftppath, pkgfile);
			updatefilelist(&db, id, fn);
			continue;
		} else if(strcmp(ptr->ver, ver) || strcmp(ptr->rel, rel)) {		
			/* ...or Update */
			fprintf(stderr, "pkgdb2-add: updating %s (%s-%s ==> %s-%s)\n",
					ptr->name, ptr->ver, ptr->rel, ver, rel);
			snprintf(query, sizeof(query), "UPDATE packages SET category_id='%d',"
					"pkgname='%s',pkgver='%s',pkgrel='%s',pkgdesc='%s',url='%s',"
					"sources='%s',depends='%s',needupdate=0,last_update=NOW() "
					"WHERE id='%d'",
					catid, addslashes(name), addslashes(ver), addslashes(rel),
					addslashes(desc), addslashes(url), addslashes(sources),
					addslashes(deplist), ptr->id);
			doquery(&db, query);
			snprintf(fn, PATH_MAX-1, "%s/%s", ftppath, pkgfile);
			updatefilelist(&db, ptr->id, fn);
			/*
			snprintf(query, sizeof(query), "UPDATE todolist_pkgs SET complete=1 "
					"WHERE pkgid='%d'", ptr->id);
			doquery(&db, query);
			*/
		}
	}

	mysql_close(&db);
	return(0);
}
