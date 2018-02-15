#!/usr/bin/python2
#
# check_archlinux.py
#
# Original script by Scott Horowitz <stonecrest@gmail.com>
# Rewritten by Xavier Chantry <shiningxc@gmail.com>
#
# This script currently checks for a number of issues in your ABS tree:
#   1. Directories with missing PKGBUILDS
#   2. Invalid PKGBUILDs (bash syntax error for instance)
#   3. PKGBUILD names that don't match their directory
#   4. Duplicate PKGBUILDs
#   5. Valid arch's in PKGBUILDS
#   6. Missing (make-)dependencies
#   7. Hierarchy of repos (e.g., that a core package doesn't depend on
#      a non-core package)
#   8. Circular dependencies

import os,re,commands,getopt,sys,tarfile
import pdb

import ctypes
_alpm = ctypes.cdll.LoadLibrary("libalpm.so")

DBEXT='.db.tar.gz'

packages = {} # pkgname : PacmanPackage
repopkgs = {} # pkgname : PacmanPackage
provisions = {} # provision : PacmanPackage
pkgdeps,makepkgdeps = {},{} # PacmanPackage : list of the PacmanPackage dependencies
invalid_pkgbuilds = []
missing_pkgbuilds = []
dups = []

dbonly = []
absonly = []

mismatches = []
missing_deps = []
missing_makedeps = []
invalid_archs = []
dep_hierarchy = []
makedep_hierarchy = []
circular_deps = [] # pkgname>dep1>dep2>...>pkgname
checked_deps = []

class PacmanPackage:
	def __init__(self):
		self.name,self.version = "",""
		self.base = ""
		self.path,self.repo = "",""
		self.deps,self.makedeps = [],[]
		self.provides,self.conflicts = [],[]
		self.archs = []

class Depend:
	def __init__(self,name,version,mod):
		self.name = name
		self.version = version
		self.mod = mod

def parse_pkgbuilds(repos,arch):
	for absroot in absroots:
		for repo in repos:
			cmd = os.path.dirname(os.path.realpath(sys.argv[0])) + '/parse_pkgbuilds.sh '
			cmd += arch + ' ' + absroot + '/' + repo
			(status,output) = commands.getstatusoutput(cmd)
			if status != 0:
				print "Error : failed to run '%s'" % cmd
				sys.exit()
			parse_data(repo,output)

def parse_data(repo,data):
	attrname = None

	for line in data.split('\n'):
		if line.startswith('%'):
			attrname = line.strip('%').lower()
		elif line.strip() == '':
			attrname = None
		elif attrname == "invalid":
			if repo in repos:
				invalid_pkgbuilds.append(line)
		elif attrname == "missing":
			if repo in repos:
				missing_pkgbuilds.append(line)
		elif attrname == "name":
			pkg = PacmanPackage()
			pkg.name = line
			pkg.repo = repo
			dup = None
			if pkg.name in packages:
				dup = packages[pkg.name]
			else:
				packages[pkg.name] = pkg
		elif attrname == "base":
			pkg.base = line
		elif attrname == "version":
			pkg.version = line
		elif attrname == "path":
			pkg.path = line
			if dup != None and (pkg.repo in repos or dup.repo in repos):
				dups.append(pkg.path + " vs. " + dup.path)
		elif attrname == "arch":
			pkg.archs.append(line)
		elif attrname == "depends":
			pkg.deps.append(line)
		elif attrname == "makedepends":
			pkg.makedeps.append(line)
		elif attrname == "conflicts":
			pkg.conflicts.append(line)
		elif attrname == "provides":
			pkg.provides.append(line)

def parse_dbs(repos,arch):
	dbpkgs = {}
	for repo in repos:
		pkgs = set([])
		db = tarfile.open(os.path.join(repodir,repo,'os',arch,repo + DBEXT))
		for line in db.getnames():
			if not '/' in line:
				pkgs.add(line.rsplit('-',2)[0])
		dbpkgs[repo] = pkgs
	return(dbpkgs)

def splitdep(dep):
	name = dep
	version = ""
	mod = ""
	for char in (">=", "<=", "=", ">", "<"):
		pos = dep.find(char)
		if pos > -1:
			name = dep[:pos]
			version = dep[pos:].replace(char, "")
			mod = char
			break
	return Depend(name,version,mod)

def splitprov(prov):
	name = prov
	version = ""
	pos = prov.find("=")
	if pos > -1:
		name = prov[:pos]
		version = prov[pos:].replace("=", "")
	return (name,version)

def vercmp(v1,mod,v2):
	"""
	>>> vercmp("1.0", "<=", "2.0")
	True
	>>> vercmp("1:1.0", ">", "2.0")
	True
	>>> vercmp("1.0.2", ">=", "2.1.0")
	False
	"""
	s1 = ctypes.c_char_p(v1)
	s2 = ctypes.c_char_p(v2)
	res = _alpm.alpm_pkg_vercmp(s1,s2)
	if res == 0:
		return (mod.find("=") > -1)
	elif res < 0:
		return (mod.find("<") > -1)
	elif res > 0:
		return (mod.find(">") > -1)
	return False


def depcmp(name,version,dep):
	if name != dep.name:
		return False
	if dep.version == "" or dep.mod == "":
		return True
	if version == "":
		return False
	return vercmp(version,dep.mod,dep.version)

def provcmp(pkg,dep):
	for prov in pkg.provides:
		(provname,provver) = splitprov(prov)
		if depcmp(provname,provver,dep):
			return True
	return False

def verify_dep(dep):
	dep = splitdep(dep)
	if dep.name in packages:
		pkg = packages[dep.name]
		if depcmp(pkg.name,pkg.version,dep):
			return [pkg]
	if dep.name in provisions:
		provlist = provisions[dep.name]
		results = []
		for prov in provlist:
			if provcmp(prov,dep):
				results.append(prov)
		return results
	return []

def verify_deps(name,repo,deps):
	pkg_deps = []
	missdeps = []
	hierarchy = []
	for dep in deps:
		pkglist = verify_dep(dep)
		if pkglist == []:
			missdeps.append(repo + "/" + name + " --> '" + dep + "'")
		else:
			valid_repos = get_repo_hierarchy(repo)
			pkgdep = None
			for pkg in pkglist:
				if pkg.repo in valid_repos:
					pkgdep = pkg
					break
			if not pkgdep:
				pkgdep = pkglist[0]
				hierarchy.append((repo,name,pkgdep))

			pkg_deps.append(pkgdep)

	return (pkg_deps,missdeps,hierarchy)

def compute_deplist(pkg):
	list = []
	stack = [pkg]
	while stack != []:
		dep = stack.pop()
		if dep in pkgdeps:
			for dep2 in pkgdeps[dep]:
				if dep2 not in list:
					list.append(dep2)
					stack.append(dep2)
		if dep in makepkgdeps:
			for dep2 in makepkgdeps[dep]:
				if dep2 not in list:
					list.append(dep2)
					stack.append(dep2)
	return list

def check_hierarchy(deph):
	hierarchy = []
	for (repo,name,pkgdep) in deph:
		deplist = compute_deplist(pkgdep)
		valid_repos = get_repo_hierarchy(repo)
		extdeps = []
		for dep in deplist:
			if dep.repo not in valid_repos:
				extdeps.append(dep.name)
		string = repo + "/" + name + " depends on " + pkgdep.repo + "/" + pkgdep.name + " ("
		string += "%s extra (make)deps to pull" % len(extdeps)
		if 0 < len(extdeps) < 10:
			string += " : " +  ' '.join(extdeps)
		string += ")"
		hierarchy.append(string)
	return hierarchy

def get_repo_hierarchy(repo):
	repo_hierarchy = {'core': ['core'], \
		'extra': ['core', 'extra'], \
		'community': ['core', 'extra', 'community'], \
                'multilib': ['core', 'extra', 'community', 'multilib'] }
	if repo in repo_hierarchy:
		return repo_hierarchy[repo]
	else:
		return ['core','extra','community']

def verify_archs(name,repo,archs):
	valid_archs = ['any', 'i686', 'x86_64']
	invalid_archs = []
	for arch in archs:
		if arch not in valid_archs:
			invalid_archs.append(repo + "/" + name + " --> " + arch)
	return invalid_archs

def find_scc(packages):
	# reset all variables
	global index,S,pkgindex,pkglowlink
	index = 0
	S = []
	pkgindex = {}
	pkglowlink = {}
	cycles = []
	for pkg in packages:
		tarjan(pkg)

def tarjan(pkg):
	global index,S,pkgindex,pkglowlink,cycles
	pkgindex[pkg] = index
	pkglowlink[pkg] = index
	index += 1
	checked_deps.append(pkg)
	S.append(pkg)
	deps = []
	if pkg in pkgdeps:
		deps = pkgdeps[pkg]
	for dep in deps:
		if dep not in pkgindex:
			tarjan(dep)
			pkglowlink[pkg] = min(pkglowlink[pkg],pkglowlink[dep])
		elif dep in S:
			pkglowlink[pkg] = min(pkglowlink[pkg],pkgindex[dep])
	if pkglowlink[pkg] == pkgindex[pkg]:
		dep = S.pop()
		if pkg == dep:
			return
		path = pkg.name
		while pkg != dep:
			path = dep.repo + "/" + dep.name + ">" + path
			dep = S.pop()
		path = dep.name + ">" + path
		if pkg.repo in repos:
			circular_deps.append(path)

def print_heading(heading):
	print ""
	print "=" * (len(heading) + 4)
	print "= " + heading + " ="
	print "=" * (len(heading) + 4)

def print_subheading(subheading):
	print ""
	print subheading
	print "-" * (len(subheading) + 2)

def print_missdeps(pkgname,missdeps) :
	for d in missdeps:
		print pkgname + " : " + d

def print_result(list, subheading):
	if len(list) > 0:
		list.sort()
		print_subheading(subheading)
		for item in list:
			print item

def print_results():
	print_result(missing_pkgbuilds, "Missing PKGBUILDs")
	print_result(invalid_pkgbuilds, "Invalid PKGBUILDs")
	print_result(mismatches, "Mismatched Pkgnames")
	print_result(dups, "Duplicate PKGBUILDs")
	print_result(invalid_archs, "Invalid Archs")
	print_result(missing_deps, "Missing Dependencies")
	print_result(missing_makedeps, "Missing Makedepends")
	print_result(dep_hierarchy, "Repo Hierarchy for Dependencies")
	print_result(makedep_hierarchy, "Repo Hierarchy for Makedepends")
	print_result(circular_deps, "Circular Dependencies")
	print_result(dbonly, "Packages found in db, but not in tree")
	print_result(absonly,"Packages found in tree, but not in db")
	print_subheading("Summary")
	print "Missing PKGBUILDs:                    ", len(missing_pkgbuilds)
	print "Invalid PKGBUILDs:                    ", len(invalid_pkgbuilds)
	print "Mismatching PKGBUILD names:           ", len(mismatches)
	print "Duplicate PKGBUILDs:                  ", len(dups)
	print "Invalid archs:                        ", len(invalid_archs)
	print "Missing (make)dependencies:           ", len(missing_deps)+len(missing_makedeps)
	print "Repo hierarchy problems:              ", len(dep_hierarchy)+len(makedep_hierarchy)
	print "Circular dependencies:                ", len(circular_deps)
	print "In db, but not in tree:               ", len(dbonly)
	print "In tree, but not in db:               ", len(absonly)
	print ""

def print_usage():
	print ""
	print "Usage: ./check_packages.py [OPTION]"
	print ""
	print "Options:"
	print "  --abs-tree=<path[,path]>      Check the specified tree(s) (default : /var/abs)"
	print "  --repos=<r1,r2,...>           Check the specified repos (default : core,extra)"
	print "  --arch=<i686|x86_64>          Check the specified arch (default : x86_64)"
	print "  --repo-dir=<path>             Check the dbs at the specified path (default : /srv/ftp)"
	print "  -h, --help                    Show this help and exit"
	print ""
	print "Examples:"
	print "\n  Check core and extra in existing abs tree:"
	print "    ./check_packages.py --abs-tree=/var/abs --repos=core,extra --arch=x86_64"
	print "\n  Check community:"
	print "    ./check_packages.py --abs-tree=/var/abs --repos=community --arch=x86_64"
	print ""

if __name__ == "__main__":
	## Default path to the abs root directory
	absroots = ["/var/abs"]
	## Default list of repos to check
	repos = ['core', 'extra']
	## Default arch
	arch = "x86_64"
	## Default repodir
	repodir = "/srv/ftp"

	try:
		opts, args = getopt.getopt(sys.argv[1:], "", ["abs-tree=", "repos=",
		"arch=", "repo-dir="])
	except getopt.GetoptError:
		print_usage()
		sys.exit()
	if opts != []:
		for o, a in opts:
			if o in ("--abs-tree"):
				absroots = a.split(',')
			elif o in ("--repos"):
				repos = a.split(",")
			elif o in ("--arch"):
				arch = a
			elif o in ("--repo-dir"):
				repodir = a
			else:
				print_usage()
				sys.exit()
			if args != []:
				print_usage()
				sys.exit()

	for absroot in absroots:
		if not os.path.isdir(absroot):
			print "Error : the abs tree " + absroot + " does not exist"
			sys.exit()
		for repo in repos:
			repopath = absroot + "/" + repo
			if not os.path.isdir(repopath):
				print("Warning : the repository " + repo + " does not exist in " + absroot)

	if not os.path.isdir(repodir):
		print "Error: the repository directory %s does not exist" % repodir
		sys.exit()
	for repo in repos:
		path = os.path.join(repodir,repo,'os',arch,repo + DBEXT)
		if not os.path.isfile(path):
			print "Error : repo DB %s : File not found" % path
			sys.exit()
		if not tarfile.is_tarfile(path):
			print "Error : Cant open repo DB %s, not a valid tar file" % path
			sys.exit()
	# repos which need to be loaded
	loadrepos = set([])
	for repo in repos:
		loadrepos = loadrepos | set(get_repo_hierarchy(repo))

	print_heading("Integrity Check " + arch + " of " + ",".join(repos))
	print("\nPerforming integrity checks...")

	print("==> parsing pkgbuilds")
	parse_pkgbuilds(loadrepos,arch)

	# fill provisions
	for name,pkg in packages.iteritems():
		for prov in pkg.provides:
			provname=prov.split("=")[0]
			if provname not in provisions:
				provisions[provname] = []
			provisions[provname].append(pkg)

	# fill repopkgs
	for name,pkg in packages.iteritems():
		if pkg.repo in repos:
			repopkgs[name] = pkg

	print("==> parsing db files")
	dbpkgs = parse_dbs(repos,arch)

	print("==> checking mismatches")
	for name,pkg in repopkgs.iteritems():
		pkgdirname = pkg.path.split("/")[-1]
		if name != pkgdirname and pkg.base != pkgdirname:
			mismatches.append(name + " vs. " + pkg.path)

	print("==> checking archs")
	for name,pkg in repopkgs.iteritems():
		archs = verify_archs(name,pkg.repo,pkg.archs)
		invalid_archs.extend(archs)

	deph,makedeph = [],[]

	print("==> checking dependencies")
	for name,pkg in repopkgs.iteritems():
		(deps,missdeps,hierarchy) = verify_deps(name,pkg.repo,pkg.deps)
		pkgdeps[pkg] = deps
		missing_deps.extend(missdeps)
		deph.extend(hierarchy)

	print("==> checking makedepends")
	for name,pkg in repopkgs.iteritems():
		(makedeps,missdeps,hierarchy) = verify_deps(name,pkg.repo,pkg.makedeps)
		makepkgdeps[pkg] = makedeps
		missing_makedeps.extend(missdeps)
		makedeph.extend(hierarchy)

	print("==> checking hierarchy")
	dep_hierarchy = check_hierarchy(deph)
	makedep_hierarchy = check_hierarchy(makedeph)

	print("==> checking for circular dependencies")
	# make sure pkgdeps is filled for every package
	for name,pkg in packages.iteritems():
		if pkg not in pkgdeps:
			(deps,missdeps,_) = verify_deps(name,pkg.repo,pkg.deps)
			pkgdeps[pkg] = deps
	find_scc(repopkgs.values())

	print("==> checking for differences between db files and pkgbuilds")
	for repo in repos:
		for pkg in dbpkgs[repo]:
			if not (pkg in repopkgs and repopkgs[pkg].repo == repo):
				dbonly.append("%s/%s" % (repo,pkg))
	for name,pkg in repopkgs.iteritems():
		if not name in dbpkgs[pkg.repo]:
			absonly.append("%s/%s" % (pkg.repo,name))

	print_results()
