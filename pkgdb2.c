/* $Id: pkgdb2.c,v 1.4 2004/07/11 20:45:21 judd Exp $ */

#include <stdio.h>
#include <stdlib.h>
#include <mysql.h>
#include <string.h>

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
	int repoid;
	pkg_t *dblist = NULL;
	pkg_t *pkglist = NULL;
	pkg_t *pkgptr, *ptr;

	if(argc < 2) {
		printf("usage: pkgdb2 <repoid>\n");
		printf("\nWARNING: Do not run this manually! It is intended to be"
				" run with pkgdb1 only.\n");
		return(1);
	}
	repoid = atoi(argv[1]);

	if(mysql_init(&db) == NULL) {
		fprintf(stderr, "could not initialize\n");
		return(1);
	}
	if(mysql_real_connect(&db, "localhost", "archweb", "passwords-are-cool",
			"archweb", 0, NULL, 0) == NULL) {
		fprintf(stderr, "failed to connect to database: %s\n", mysql_error(&db));
		return(1);
	}
	snprintf(query, sizeof(query), "SELECT id,pkgname,pkgver,pkgrel FROM packages "
			"WHERE repoid='%d'", repoid);
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
		/* get package data from stdin */
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
				strlen(sources) > 4094 || strlen(deplist) > 4094) {
			fprintf(stderr, "pkgdb2: one or more fields are too long in package '%s'\n", name);
			fprintf(stderr, "pkgdb2: check the lengths of your strings, most are limited "
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
			fprintf(stderr, "pkgdb2: no db category found for '%s'\n", cat);
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
			printf("pkgdb2: inserting %s\n", name);
			snprintf(query, sizeof(query), "INSERT INTO packages (id,repoid,"
					"categoryid,pkgname,pkgver,pkgrel,pkgdesc,url,sources,depends,"
					"lastupdate) VALUES (NULL,'%d','%d','%s','%s','%s','%s',"
					"'%s','%s','%s',NOW())",
					repoid, catid, addslashes(name), addslashes(ver), addslashes(rel),
					addslashes(desc), addslashes(url), addslashes(sources),
					addslashes(deplist));
			doquery(&db, query);
			continue;
		} else if(strcmp(ptr->ver, ver) || strcmp(ptr->rel, rel)) {		
			/* ...or Update */
			printf("pkgdb2: updating %s (%s-%s ==> %s-%s)\n",
					ptr->name, ptr->ver, ptr->rel, ver, rel);
			snprintf(query, sizeof(query), "UPDATE packages SET categoryid='%d',"
					"pkgname='%s',pkgver='%s',pkgrel='%s',pkgdesc='%s',url='%s',"
					"sources='%s',depends='%s',needupdate=0,lastupdate=NOW() "
					"WHERE id='%d'",
					catid, addslashes(name), addslashes(ver), addslashes(rel),
					addslashes(desc), addslashes(url), addslashes(sources),
					addslashes(deplist), ptr->id);
			doquery(&db, query);
			snprintf(query, sizeof(query), "UPDATE todolist_pkgs SET complete=1 "
					"WHERE pkgid='%d'", ptr->id);
			doquery(&db, query);
		}
	}

	/* look for delete packages */
	for(ptr = dblist; ptr; ptr = ptr->next) {
		int found = 0;
		for(pkgptr = pkglist; pkgptr; pkgptr = pkgptr->next) {
			if(!strcmp(ptr->name, pkgptr->name)) {
				found = 1;
				break;
			}
		}
		if(!found) {
			/* delete from db */
			printf("pkgdb2: deleting %s\n", ptr->name);
			snprintf(query, sizeof(query), "DELETE FROM packages WHERE id='%d'",
					ptr->id);
			doquery(&db, query);
			snprintf(query, sizeof(query), "DELETE FROM todolist_pkgs WHERE listid='%d'",
					ptr->id);
			doquery(&db, query);
		}
	}
	
	mysql_close(&db);
	return(0);
}
