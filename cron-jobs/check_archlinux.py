#!/usr/bin/env python
#
# check_archlinux.py
#
# Written by Scott Horowitz <stonecrest@gmail.com>
# Graphical dependency tree by Cesar G. Miguel <cesargm@ime.usp.br>
#
# This script currently checks for a number of issues in your ABS tree:
#   1. Directories with missing PKGBUILDS
#   2. Duplicate PKGBUILDs
#   3. Missing (make-)dependencies, taking into account 'provides'
#   4. Provisioned dependencies
#   5. Circular dependencies
#   6. Valid arch's in PKGBUILDS
#   7. Missing packages in Arch repos
#   8. PKGBUILD names that don't match their directory
#   9. Hierarchy of repos (e.g., that a core package doesn't depend on
#      a non-core package)
# It can also, optionally, generate a graphical representation of the
# dependency tree.
#
# Todo:
#   1. Accommodate testing repo?

abs_conf_dir = "/etc/abs"
valid_archs = ['i686', 'x86_64']
cvs_tags = {'i686': 'CURRENT', 'x86_64': 'CURRENT-64'}
include_paths = ['core', 'extra', 'community', 'unstable']
pkgdir_path_depth = 3

base_server = "ftp.archlinux.org" # Must be ftp site
# Ensure that core repo only depends on core, and the extra repo only
# depends on core and extra, etc.
repo_hierarchy = {'core': ('core'), \
'extra': ('core', 'extra'), \
'unstable': ('core', 'extra', 'unstable'), \
'community': ('core', 'extra', 'unstable', 'community')} 

pkgname_str = "pkgname="
dep_str = "depends=("
makedep_str = "makedepends=("
provides_str = "provides=("
arch_str = "arch=("
pkgver_str = "pkgver="
pkgrel_str = "pkgrel="
build_str = "build()"
source_str = "source="
url_str = "url="
mathlist = (">=", "<=", "=", ">", "<")
sup_tag_str = "*default tag="

import os, sys, getopt, tempfile
from ftplib import FTP
try:
	import pydot
	HAS_PYDOT = True
except:
	HAS_PYDOT = False

def print_heading(heading):
	print ""
	print "=" * (len(heading) + 4)
	print "= " + heading + " ="
	print "=" * (len(heading) + 4)

def print_subheading(subheading):
	print ""
	print subheading
	print "-" * (len(subheading) + 2)

def rmgeneric(path, __func__):
	try:
		__func__(path)
	except OSError, (errno, strerror):
		pass

def removeall(path):
	if not os.path.isdir(path):
		return

	files=os.listdir(path)

	for x in files:
		fullpath=os.path.join(path, x)
		if os.path.isfile(fullpath):
			f=os.remove
			rmgeneric(fullpath, f)
		elif os.path.isdir(fullpath):
			removeall(fullpath)
			f=os.rmdir
			rmgeneric(fullpath, f)

def update_var(line, user_vars, pkgpath):
	if line.count("$") > 0:
		export_line = ""
		for var in user_vars:
			if line.count(var[0]) > 0:
				export_line = export_line + var[0] + "=" + var[1] + " && "
		if line.startswith("(") and line.endswith(")"):
			line = line[1:-1]
		export_line = export_line + "echo \"" + line + "\""
		line = os.popen(export_line).read().replace("\n", "")
	return line

def split_dep_prov_symbol(dep):
	# Splits 'foo>=1.2.3' into ('foo', '1.2.3', '>=')
	prov = ""
	symbol = ""
	for char in mathlist:
		pos = dep.find(char)
		if pos > -1:
			prov = dep[pos:].replace(char, "")
			dep = dep[:pos]
			symbol = char
			break
	return (dep, prov, symbol)

def repo_from_path(path):
	# Community HACK: community still has old 
	# community/category/pkgname/PKGBUILD path - accomodate for this
	if path.split("/")[-1 * (pkgdir_path_depth + 1)] == "community":
		return path.split("/")[-1 * (pkgdir_path_depth + 1)]
	return path.split("/")[-1 * pkgdir_path_depth]

def create_supfile(sourcefile, destfile, newtag):
	o = open(sourcefile, 'r')
	info = o.read()
	o.close()
	lines = info.split("\n")
	
	o = open(destfile, 'w')
	for line in lines:
		line = line.strip()
		if line[:len(sup_tag_str)] == sup_tag_str:
			line = sup_tag_str + newtag
		o.write(line + "\n")
	o.close()

def get_deps_provides_etc(pkgpath):
	# Parse PKGBUILD for name, depends, makedepends, provides, arch's, and version
	o = open(pkgpath, 'r')
	info = o.read()
	o.close()
	lines = info.split("\n")

	deps = []
	provides = []
	archs = []
	makedeps = []
	array = []
	user_vars = []
	continue_line = False
	for line in lines:
		line = line.strip()
		if line.find("#") > -1:
			line = line[:line.find("#")].strip()
		if not continue_line:
			deps_line = False
			provides_line = False
			arch_line = False
			makedeps_line = False
		if line[:len(dep_str)] == dep_str:
			line = line.replace(dep_str,"")
			deps_line = True
		elif line[:len(makedep_str)] == makedep_str:
			line = line.replace(makedep_str,"")
			makedeps_line = True
		elif line[:len(provides_str)] == provides_str:
			line = line.replace(provides_str,"")
			provides_line = True
		elif line[:len(arch_str)] == arch_str:
			line = line.replace(arch_str, "")
			arch_line = True
		elif line[:len(pkgname_str)] == pkgname_str:
			pkgname = line.replace(pkgname_str, "")
			if pkgname.startswith("\"") and pkgname.endswith("\""):
				pkgname = pkgname[1:-1]
			pkgname = update_var(pkgname, user_vars, pkgpath)
			user_vars.append([pkgname_str, pkgname])
			line = ""
		elif line[:len(pkgver_str)] == pkgver_str:
			pkgver = line.replace(pkgver_str, "")
			if pkgver.startswith("\"") and pkgver.endswith("\""):
				pkgver = pkgver[1:-1]
			pkgver = update_var(pkgver, user_vars, pkgpath)
			user_vars.append([pkgver_str[:-1], pkgver])
			line = ""
		elif line[:len(pkgrel_str)] == pkgrel_str:
			pkgrel = line.replace(pkgrel_str, "")
			if pkgrel.startswith("\"") and pkgrel.endswith("\""):
				pkgrel = pkgrel[1:-1]
			pkgrel = update_var(pkgrel, user_vars, pkgpath)
			user_vars.append([pkgrel_str[:-1], pkgrel])
			line = ""
		elif line[:len(build_str)] == build_str:
			break
		elif not continue_line:
			if line.count("=") == 1 and line.count(" ") == 0 and line[:1] != "#" and \
			line[:len(source_str)] != source_str and line[:len(url_str)] != url_str:
				split = line.split("=")
				for item in range(len(split)):
					split[item] = update_var(split[item], user_vars, pkgpath)
				user_vars.append(split)
			line = ""
		if len(line) > 0:
			pos = line.find(")")
			if pos > -1:
				# strip everything from closing paranthesis on
				# since some PKGBUILDS have comments after the
				# depends array
				line = line[:pos]
			line = line.split(' ')
			for i in range(len(line)):
				line[i] = line[i].replace("'","").replace('"','')
				line[i] = update_var(line[i], user_vars, pkgpath)
				if len(line[i]) > 0:
					if deps_line:
						deps.append(line[i])
						array=deps
					elif provides_line:
						provides.append(line[i])
						array=provides
					elif arch_line:
						archs.append(line[i])
						array=archs
					elif makedeps_line:
						makedeps.append(line[i])
						array=makedeps
			if array and (array[-1] == "\\" or array[-1][-1] == "\\"):
				# continue reading deps/provides on next line
				if array[-1] == "\\":
					array.pop(-1)
				else:
					array[-1] = array[-1].replace("\\", "")
				continue_line = True
			else:
				continue_line = False
	version = pkgver + "-" + pkgrel
	return (pkgname, deps, makedeps, provides, archs, version)

def get_pkgbuilds_in_dir(rootdir):
	# Recursively populates pkgbuild_deps, pkgbuild_paths, etc.
	# dicts with info from each PKGBUILD found in rootdir:
	if rootdir != absroot:
		if rootdir.count("/") == (absroot.count("/")+1) and rootdir not in curr_include_paths:
			return
	pkgfound = False
	for f in os.listdir(rootdir):
		fpath = rootdir + "/" + f
		if os.path.isdir(fpath):
			get_pkgbuilds_in_dir(fpath)
		elif f == 'PKGBUILD':
			pkgfound = True
			name = rootdir.split("/")[-1]
			if name in pkgbuild_deps:
				dups.append(fpath.replace(absroot, "") + " vs. " + pkgbuild_paths[name].replace(absroot, ""))
			else:
				(pkgname, deps, makedeps, provides, archs, version) = get_deps_provides_etc(fpath)
				pkgbuild_deps[pkgname] = deps
				pkgbuild_makedeps[pkgname] = makedeps
				pkgbuild_paths[pkgname] = fpath
				pkgbuild_archs[pkgname] = archs
				pkgbuild_versions[pkgname] = version
				# We'll store the provides "backwards" compared to
				# the other dicts. This will make searching for
				# provides easier by being able to look up the
				# provide name itself and find what provides it
				for provide in provides:
					pkgbuild_provides[provide] = pkgname
				if pkgname != name:
					mismatches.append(pkgname + " vs. " + fpath.replace(absroot, ""))
	if not pkgfound and rootdir != absroot:
		repo = rootdir.replace(absroot, "").split("/")[1]
		num_slashes = pkgdir_path_depth - 1
		# Community HACK: community still has old 
		# community/category/pkgname/PKGBUILD path - accomodate for this
		if repo == "community" and rootdir.replace(absroot, "").count("/") == num_slashes + 1 and rootdir.split("/")[-1] != "CVS":
			misses.append(rootdir.replace(absroot, "") + "/PKGBUILD")
		if repo != "community" and rootdir.replace(absroot, "").count("/") == num_slashes:
			misses.append(rootdir.replace(absroot, "") + "/PKGBUILD")
	
def verify_depends_makedepends(verify_makedeps=False):
	# Make sure all the deps we parsed are actually packages; also
	# ensure we meet dep provisions.
	if verify_makedeps:
		array = pkgbuild_makedeps
	else:
		array = pkgbuild_deps
	for pkgname in array:
		deps = array[pkgname]
		pkg_repo = repo_from_path(pkgbuild_paths[pkgname])
		deps_to_pop = []
		for i in range(len(deps)):
			dep = deps[i]
			(dep, prov, char) = split_dep_prov_symbol(dep)
			try:
				x = pkgbuild_deps[dep]
				# Check that prov is met too:
				if len(prov) > 0:
					compare_str = "vercmp " + pkgbuild_versions[dep] + " " + prov
					error = False
					if char == "<=":
						if int(os.popen(compare_str).read().replace("\n", "")) > 0:
							error = True
					elif char == ">=":
						if int(os.popen(compare_str).read().replace("\n", "")) < 0:
							error = True
					elif char == "=":
						if int(os.popen(compare_str).read().replace("\n", "")) != 0:
							error = True
					elif char == ">":
						if int(os.popen(compare_str).read().replace("\n", "")) <= 0:
							error = True
					elif char == "<":
						if int(os.popen(compare_str).read().replace("\n", "")) >= 0:
							error = True						
					if error:
						if verify_makedeps:
							unmet_makedep_provs.append(pkgname + " --> '" + dep + char + prov + "'")
						else:
							unmet_dep_provs.append(pkgname + " --> '" + dep + char + prov + "'")
				# Check repos fit hierarchy scheme:
				dep_repo = repo_from_path(pkgbuild_paths[dep])
				try:
					valid_repos = repo_hierarchy[pkg_repo]
					# Make sure dep repo is one of the valid repos:
					if dep_repo not in valid_repos:
						if verify_makedeps:
							makedep_hierarchy.append(pkg_repo + "/" + pkgname + " depends on " + dep_repo + "/" + dep)
						else:
							dep_hierarchy.append(pkg_repo + "/" + pkgname + " depends on " + dep_repo + "/" + dep)
				except:
					pass
			except:
				# Check if a package provides this dep:
				try:
					x = pkgbuild_provides[dep]
				except:
					if verify_makedeps:
						missing_makedeps.append(pkgname + " --> '" + dep + "'")
					else:
						missing_deps.append(pkgname + " --> '" + dep + "'")
				deps_to_pop.append(i)
		# Pop deps not found from end to beginning:
		while len(deps_to_pop) > 0:
			deps.pop(deps_to_pop[-1])
			deps_to_pop.pop(-1)

def verify_archs():
	for pkgname in pkgbuild_archs:
		newarch = []
		archs = pkgbuild_archs[pkgname]
		for arch in archs:
			if arch not in valid_archs:
				invalid_archs.append(pkgname + " --> " + arch)
			else:
				newarch.append(arch)
		if len(newarch) > 0:
			pkgbuild_archs[pkgname] = newarch
	
def verify_packages(tree_arch):
	# Make sure packages exist in Arch repo(s):
	ftp = FTP(base_server)
	ftp.login()
	prev_wd = ""
	# Find all repos/archs; marching through them in order will greatly speed
	# up searching for ftp files by minimizing the number of .nlst's that we
	# have to do.
	repos = []
	for pkgname in pkgbuild_paths:
		pkgrepo = repo_from_path(pkgbuild_paths[pkgname])
		if not pkgrepo in repos:
			repos.append(pkgrepo)
	archs = []
	for pkgname in pkgbuild_archs:
		pkgarchs = pkgbuild_archs[pkgname]
		for arch in pkgarchs:
			if not arch in archs:
				archs.append(arch)
	for r in repos:
		for pkgname in pkgbuild_archs:
			repo = repo_from_path(pkgbuild_paths[pkgname])
			if repo == r:
				archs = pkgbuild_archs[pkgname]
				pkgver_rel = pkgbuild_versions[pkgname]
				for arch in archs:
					if arch == tree_arch:
						# Check for file:
						wd = repo + "/os/" + arch
						if wd != prev_wd:
							ftpfiles = ftp.nlst(wd)
							prev_wd = wd
						fname_new = wd + "/" + pkgname + "-" + pkgver_rel + "-" + arch + ".pkg.tar.gz"
						fname_old = wd + "/" + pkgname + "-" + pkgver_rel + ".pkg.tar.gz"
						if fname_old not in ftpfiles and fname_new not in ftpfiles:
							missing_pkgs.append(pkgname + "-" + pkgver_rel + " in " + wd)
	ftp.quit()
	
def subset_superset_path(currpath, currpathnum, paths):
	# If a pair of subset/superset paths are found,
	# pop the superset one to show the more minimal
	# case.
	#
	# e.g. foo > bar > baz > foo (superset)
	#      foo > bar > foo (subset)
	#      --> pop the superset
	#
	currdeps = currpath.split(">")
	currdeps = list(set(currdeps))
	currdeps.sort()
	pathnum = 0
	for path in paths:
		if pathnum != currpathnum:
			deps = path.split(">")
			deps = list(set(deps))
			deps.sort()
			if len(currdeps) < len(path):
				subset = True
				for d in currdeps:
					if not d in path:
						subset = False
						break
				if subset:
					circular_deps.pop(pathnum)
					if pathnum <= currpathnum:
						currpathnum -= 1
			elif len(currdeps) > len(path):
				superset = True
				for d in path:
					if not d in currdeps:
						superset = False
						break
				if superset:
					circular_deps.pop(currpathnum)
					currpathnum -= 1
		pathnum += 1
	return True

def unique_path(currpath, paths):
	# Returns false if an equivalent path exists in
	# paths.
	#
	# e.g. foo > bar > foo
	#      bar > foo > bar
	#
	currdeps = currpath.split(">")
	currdeps = list(set(currdeps))
	currdeps.sort()
	for path in paths:
		deps = path.split(">")
		deps = list(set(deps))
		deps.sort()
		if currdeps == deps:
			return False
	return True

def update_paths(paths, dep, dep2):
	# Update paths by appending new paths with dep2
	# based on all the different ways we could get
	# to dep2. Returns True if a path was updated.
	new_path = False
	for i in range(len(paths)):
		array = paths[i].split(">")
		newpath = paths[i] + ">" + dep2
		if array[-1] == dep and not dep2 in array and unique_path(newpath, paths):
			paths.append(newpath)
			new_path = True
	return new_path

def check_name_in_recursive_deps(pkgname):
	# Retrieve all recursive dependencies from a package and
	# determines if pkgname is found in one of its deps.
	recursive_deps = []
	for dep in pkgbuild_deps[pkgname]:
		dep = split_dep_prov_symbol(dep)[0] # Strip any provision
		recursive_deps.append(dep)
	paths = []
	for dep in recursive_deps:
		dep = split_dep_prov_symbol(dep)[0] # Strip any provision
		paths.append(dep)
	searching = True
	while searching:
		searching = False
		for dep in recursive_deps:
			for dep2 in pkgbuild_deps[dep]:
				dep2 = split_dep_prov_symbol(dep2)[0] # Strip any provision
				# This is a HUGE time-saver. Instead of generating every single
				# possible path that can yield a circular dep, we'll reduce
				# the number greatly by throwing out paths like such:
				#
				# If we have a path: foo>bar>baz>blah>poop>foo
				# We will throw out any: 
				#      foo>...>bar>baz>blah>poop>foo
				#      foo>...>baz>blah>poop>foo
				#      foo>...>blah>poop>foo
				# and so on. Otherwise we will find hundreds or even thousands
				# of possible paths that all essentially represent the same 
				# circular dep.
				#
				# However, we will always let pkgname through in order to make
				# sure we can find multiple circular deps for a given pkg.
				if dep2 not in recursive_deps or dep2 == pkgname: 
					updated = update_paths(paths, dep, dep2)
					if dep2 not in recursive_deps:
						recursive_deps.append(dep2)
					if updated:
						searching = True
	# Done searching, store circular deps:
	for path in paths:
		if path.split(">")[-1] == pkgname:
			if unique_path(pkgname + ">" + path, circular_deps):
				circular_deps.append(pkgname + ">" + path)
	# Reduce any subset/superset path pairs:
	pathnum = 0
	for path in circular_deps:
		subset_superset_path(path, pathnum, circular_deps)
		pathnum += 1

def circular_deps_check():
	# Check for circular dependencies:
	for pkgname in pkgbuild_deps:
		check_name_in_recursive_deps(pkgname)

def visualize_repo():
	output = 'digraph G { \n \
		concentrate = true; \n \
		ordering = out;     \n \
		ranksep=5.0;        \n \
		node [style=filled,fontsize=8]; \n'

	# draws circular dependencies in red
	for path in circular_deps:
		output += '\t "'+path[0]+'"'
		deps = path.split(">")
		for d in deps:
			output += ' -> "'+d+'"'
		output += '  [color=red]\n'

	for pkg in pkgbuild_deps.keys():
		output += '\t "'+pkg+'" -> { '
		for d in pkgbuild_deps[pkg]:
			d = split_dep_prov_symbol(d)[0] # Strip any provision
			output += '"'+d+'"; '
		output += '}\n'

	output += '}'

	# Uncomment these lines to get a file dump called
	# 'output'. This can be used to manually generate
	# an image using, e.g., dot -Tsvg output tree.svg
	#dump = open('output', 'w')
	#dump.write(output)
	#dump.close()

	fname = 'dependency_tree-' + arch + '.svg'
	print "Generating " + fname + "..."
	g = pydot.graph_from_dot_data(output)
	g.write(fname, prog='dot', format='svg')
	
def print_result(list, subheading):
	if len(list) > 0:
		print_subheading(subheading)
		for item in list:
			print item

def print_results():
	print_result(misses, "Missing PKGBUILDs")
	print_result(mismatches, "Mismatched Pkgnames")
	print_result(dups, "Duplicate PKGBUILDs")
	print_result(missing_deps, "Missing Dependencies")
	print_result(missing_makedeps, "Missing Makedepends")
	print_result(unmet_dep_provs, "Unmet Dependency Provisions")
	print_result(unmet_makedep_provs, "Unmet Makedepends Provisions")
	print_result(dep_hierarchy, "Repo Hierarchy for Dependencies")
	print_result(makedep_hierarchy, "Repo Hierarchy for Makedepends")
	print_result(invalid_archs, "Invalid Archs")
	print_result(circular_deps, "Circular Dependencies")
	print_result(missing_pkgs, "Missing Repo Packages")
	print_subheading("Summary")
	print "Dirs with missing PKGBUILDs:          ", len(misses)
	print "Duplicate PKGBUILDs:                  ", len(dups)
	print "Missing (make)dependencies:           ", len(missing_deps)+len(missing_makedeps)
	print "Unmet provisioned (make)dependencies: ", len(unmet_dep_provs)+len(unmet_makedep_provs)
	print "Circular dependencies:                ", len(circular_deps)
	print "Invalid archs:                        ", len(invalid_archs)
	print "Missing packages in repos:            ", len(missing_pkgs)
	print "Mismatching PKGBUILD names:           ", len(mismatches)
	print "Repo hierarchy problems:              ", len(dep_hierarchy)+len(makedep_hierarchy)
	print ""

def print_usage():
	print ""
	print "Usage: check_archlinux [OPTION]"
	print ""
	print "Options:"
	print "  --abs-tree=<path>  REQUIRED   Check specified tree (assumes the abs tree"
	print "                                is i686 unless overridden with --arch)"
	print "  --arch=<arch>      OPTIONAL   Use specified arch (e.g. 'x86_64')"
	print "  -g                 OPTIONAL   Generate graphical dependency tree(s)"
	print "  -h, --help         OPTIONAL   Show this help and exit"
	print ""
	print "Examples:"
	print "\n  Check existing i686 abs tree:"
	print "    check_archlinux --abs-tree=/var/abs"
	print "\n  Check existing x86_64 abs tree and also generate dep tree image:"
	print "    check_archlinux --abs-tree=/var/abs --arch=x86_64 -g"
	print ""

graphdeptree = False
user_absroot = ""
user_arch = ""
try:
	opts, args = getopt.getopt(sys.argv[1:], "g", ["abs-tree=", "arch="])
except getopt.GetoptError:
	print_usage()
	sys.exit()
if opts != []:
	for o, a in opts:
		if o in ("-g"):
			graphdeptree = True
			if not HAS_PYDOT:
				print "You must install pydot to generate a graphical dependency tree. Aborting..."
				sys.exit()
		elif o in ("--abs-tree"):
			user_absroot = a
		elif o in ("--arch"):
			user_arch = a
			if user_arch not in valid_archs:
				print "You did not specify a valid arch. Aborting..."
				sys.exit()
		else:
			print_usage()
			sys.exit()
		if args != []:
			for a in args:
				if a in ("play", "pause", "stop", "next", "prev", "pp", "info", "status", "repeat", "shuffle"):
					self.single_connect_for_passed_arg(a)
				else:
					print_usage()
				sys.exit()

if len(user_absroot) == 0:
	print_usage()
	sys.exit()

if len(user_arch) == 0:
	user_arch = valid_archs[0] # i686 default..

if len(user_absroot) > 0:
	print "Warning: Ensure your ABS tree is clean to prevent false positives."

try:
	for arch in valid_archs:
		if len(user_arch) == 0 or user_arch == arch:
			print_heading(arch + " Integrity Check")
			absroot = user_absroot
			curr_include_paths = []
			for repo in include_paths:
				curr_include_paths.append(absroot + "/" + repo)

			# Re-init vars for new abs tree:
			pkgbuild_deps = {} # pkgname: [dep1, dep2>foo, dep3=bar, ...]
			pkgbuild_makedeps = {} # pkgname: [dep1, dep2>foo, dep3=bar, ...]
			pkgbuild_provides = {} # provide_name: pkgname
			pkgbuild_paths = {} # pkgname: /var/abs/foo/bar/pkgname/PKGBUILD
			pkgbuild_archs = {} # pkgname: [i686, x86_64]
			pkgbuild_versions = {} # pkname: 1.0.4-2
			# circular_deps is not a dict to accommodate multiple circ deps for a given pkg
			circular_deps = [] # pkgname>dep1>dep2>...>pkgname
			mismatches = []
			misses = []
			dups = []
			missing_deps = []
			unmet_dep_provs = []
			dep_hierarchy = []
			missing_makedeps = []
			unmet_makedep_provs = []
			makedep_hierarchy = []
			invalid_archs = []
			missing_pkgs = []

			# Verify stuff for abs tree:
			print "\nPerforming integrity checks..."
			print "==> parsing pkgbuilds"
			get_pkgbuilds_in_dir(absroot)
			print "==> checking dependencies"
			verify_depends_makedepends()
			print "==> checking makedepends"
			verify_depends_makedepends(True)
			print "==> checking archs"
			verify_archs()
			print "==> checking for circular dependencies"
			circular_deps_check()
			print "==> checking repo packages"
			verify_packages(arch)
			print_results()
			if graphdeptree:
				visualize_repo()

except:
	sys.exit()

# vim: set ts=2 sw=2 noet :
