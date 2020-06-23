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


def metadata_gen(dist_info, module, version):
    with open("%sMETADATA" % (dist_info), 'w') as f:
        f.write("Metadata-Version: 2.1\n")
        f.write("Name: %s\n" % (module))
        f.write("Version: %s\n" % (version))
        f.write("Summary: %s extension\n" % (module))
        f.write("Home-page: http://www.featuremine.com\n")
        f.write("Maintainer: Featuremine Corporation\n")
        f.write("Maintainer-email: support@featuremine.com\n")
        f.write("License: UNKNOWN\n")
        f.write("Platform: UNKNOWN\n\n")
        f.write("%s extension.\n" % (module))


def wheel_gen(dist_info, mayor_ver, minor_ver):
    with open("%sWHEEL" % (dist_info), 'w') as f:
        v = "%s%s" % (mayor_ver, minor_ver)
        f.write("Wheel-Version: 1.0\n")
        f.write("Generator: bdist_wheel (0.33.1)\n")
        f.write("Root-Is-Purelib: false\n")
        f.write("Tag: cp%s-cp%sm-linux_x86_64\n" % (v, v))


def top_level_gen(dist_info, module):
    with open("%stop_level.txt" % (dist_info), 'w') as f:
        f.write("\n%s\n\n" % (module))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--module', help="Module name", type=str)
    parser.add_argument('--version', help='Module version', type=str)
    parser.add_argument('--build_dir', help='Build directory', type=str)
    parser.add_argument('--sources', help='Sources', type=json.loads)
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
    metadata_gen(dist_info, args.module, args.version)
    record_gen(dist_info, args.module, args.sources)

    zipname = '%s-%s-cp%s%s-cp%s%sm-linux_x86_64.whl' % (args.module,
                                                         args.version,
                                                         major_ver,
                                                         minor_ver,
                                                         major_ver,
                                                         minor_ver)

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
