from zipfile import ZipFile
import argparse
import re
import hashlib
import base64
import os
import errno
from shutil import copyfile
import shutil
import sys
import json
from distutils import util
from importlib import import_module
from pip._vendor import pkg_resources

pkg_os = util.get_platform().replace('-','_').replace('.','_')

def hashes(file_names):
    return [
        base64.urlsafe_b64encode(hashlib.sha256(open(file_name, 'rb').read()).digest()).decode('latin1').rstrip('=')
        for file_name in file_names
    ]


def sizes(file_names):
    return [
        os.stat(file_name).st_size
        for file_name in file_names
    ]


def record_gen(dist_info, module, sources):
    with open("%sRECORD" % (dist_info), 'w') as f:
        for dir, files in sources.items():
            for file, sha, sz in zip(files, hashes(files), sizes(files)):
                f.write("%s,sha256=%s,%d\n" % (os.path.join(dir, os.path.basename(file)), sha, sz))
        f.write("%s.dist-info/RECORD,,\n" % (module))

def get_version(package):
    for p in pkg_resources.working_set:
        if p.project_name.lower() == package.__name__.lower():
            return p.version
    raise RuntimeError("Unable to find version")

def metadata_gen(dist_info, module, version, rigid_deps, flexible_deps, non_validated_deps):
    with open("%sMETADATA" % (dist_info), 'w') as f:
        f.write("Metadata-Version: 2.1\n")
        f.write("Name: %s\n" % (module))
        f.write("Version: %s\n" % (version))
        f.write("Summary: %s extension\n" % (module))
        f.write("Home-page: http://www.featuremine.com\n")
        f.write("Maintainer: Featuremine Corporation\n")
        f.write("Maintainer-email: support@featuremine.com\n")
        for dep in rigid_deps:
            dep_module = import_module(dep)
            f.write("Requires-Dist: %s == %s\n" % (dep, dep_module.__version__))
        for dep in flexible_deps:
            dep_module = import_module(dep)
            if hasattr(dep_module, "__version__") :
                f.write("Requires-Dist: %s >= %s\n" % (dep, dep_module.__version__))
            else:
                f.write("Requires-Dist: %s >= %s\n" % (dep, get_version(dep_module)))
        for dep in non_validated_deps:
            f.write("Requires-Dist: %s\n" % (dep,))
        f.write("License: UNKNOWN\n")
        f.write("Platform: UNKNOWN\n\n")
        f.write("%s extension.\n" % (module))


def wheel_gen(dist_info, mayor_ver, minor_ver):
    with open("%sWHEEL" % (dist_info), 'w') as f:
        v = "%s%s" % (mayor_ver, minor_ver)
        f.write("Wheel-Version: 1.0\n")
        f.write("Generator: bdist_wheel (0.33.1)\n")
        f.write("Root-Is-Purelib: false\n")
        if major_ver >= 3 and minor_ver>=8:
            f.write("Tag: cp%s-cp%s-%s\n" % (v, v, pkg_os))
        else:
            f.write("Tag: cp%s-cp%sm-%s\n" % (v, v, pkg_os))


def top_level_gen(dist_info, module):
    with open("%stop_level.txt" % (dist_info), 'w') as f:
        f.write("\n%s\n\n" % (module))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--module', help="Module name", type=str)
    parser.add_argument('--version', help='Module version', type=str)
    parser.add_argument('--build_dir', help='Build directory', type=str)
    parser.add_argument('--sources', help='Sources', type=json.loads)
    parser.add_argument('--rigid_dependencies', action='append', default=[])
    parser.add_argument('--flexible_dependencies', action='append', default=[])
    parser.add_argument('--non_validated_dependencies', action='append', default=[])
    args = parser.parse_args()

    major_ver = sys.version_info.major
    minor_ver = sys.version_info.minor
    dirname = "".join(['wheel', args.module, args.version])
    dist_info = "%s/%s/%s-%s.dist-info/" % (args.build_dir, dirname, args.module, args.version)

    try:
        os.makedirs(os.path.dirname(dist_info))
    except OSError as exc:
        if exc.errno != errno.EEXIST:
            raise

    os.chdir("%s/%s" % (args.build_dir, dirname))

    wheel_gen(dist_info, major_ver, minor_ver)
    top_level_gen(dist_info, args.module)
    metadata_gen(dist_info, args.module, args.version, args.rigid_dependencies, args.flexible_dependencies, args.non_validated_dependencies)
    record_gen(dist_info, args.module, args.sources)

    if major_ver >= 3 and minor_ver>=8:
        zipname = '%s-%s-cp%s%s-cp%s%s-%s.whl' % (args.module,
                                                  args.version,
                                                  major_ver,
                                                  minor_ver,
                                                  major_ver,
                                                  minor_ver,
                                                  pkg_os)
    else:
        zipname = '%s-%s-cp%s%s-cp%s%sm-%s.whl' % (args.module,
                                                   args.version,
                                                   major_ver,
                                                   minor_ver,
                                                   major_ver,
                                                   minor_ver,
                                                   pkg_os)

    module_dir = os.path.join(args.build_dir, 'package', args.module)
    with ZipFile(zipname, 'w') as zip:
        for dir, files in args.sources.items():
            for file in files:
                zip.write(file, os.path.join(dir, os.path.basename(file)))
        zip.write("%s-%s.dist-info/WHEEL" % (args.module, args.version))
        zip.write("%s-%s.dist-info/top_level.txt" % (args.module, args.version))
        zip.write("%s-%s.dist-info/METADATA" % (args.module, args.version))
        zip.write("%s-%s.dist-info/RECORD" % (args.module, args.version))

    os.chdir("../")

    shutil.move('%s/%s' % (dirname, zipname), zipname)
    shutil.rmtree(dirname)
