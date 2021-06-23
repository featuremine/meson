import hashlib
import os
import errno
import tarfile
import shutil
import json
import time
import os
import subprocess
import sys
import argparse


def hashes(file_names):
    return [
        hashlib.sha256(open(file_name, 'rb').read()).hexdigest()
        for file_name in file_names
    ]

def sizes(file_names):
    return [
        os.stat(file_name).st_size
        for file_name in file_names
    ]

def gen_libpy_path(module, file, python_ver):
    return 'lib/python{0}/{1}'.format(python_ver, file)

def is_script(file):
    return file.rfind("/scripts/") != -1

def gen_bin_path(file):
    return 'bin/{}'.format(os.path.basename(file))

def paths_gen(info_dir, module, sources, python_ver):
    with open("%spaths.json" % (info_dir), 'w') as f:
        paths = []
        for dir, files in sources.items():
            for file, sha, sz in zip(files, hashes(files), sizes(files)):
                file = os.path.join(dir, os.path.basename(file))
                path = {
                    "_path": gen_bin_path(file) if is_script(file) else gen_libpy_path(module, file, python_ver),
                    "path_type": "hardlink",
                    "sha256": sha,
                    "size_in_bytes": sz
                }
                paths.append(path)
        json.dump({"paths": paths, "paths_version": 1}, f, indent=2, separators=(',', ': '))

def index_gen(info_dir, module, version, build, python_ver):
    index = {
        "arch": "x86_64",
        "build": build,
        "build_number": 0,
        "depends": [
            "python >=%s" % (python_ver)
        ],
        "license": "MIT",
        "license_family": "MIT",
        "name": module,
        "platform": "linux",
        "subdir": "linux-64",
        "timestamp": round(time.time()),
        "version": version
    }
    with open("%sindex.json" % (info_dir), 'w') as f:
        json.dump(index, f, indent=2, separators=(',', ': '))

def files_gen(info_dir, module, sources, python_ver, mode):
    with open("%sfiles" % (info_dir), mode) as f:
        for dir, files in sources.items():
            for file in files:
                file = os.path.join(dir, os.path.basename(file))
                f.write(
                    '{0}\n'.format(
                        gen_bin_path(file) if is_script(file) else gen_libpy_path(
                            module,
                            file,
                            python_ver)))

def run_subprocess(cmd):
    ps = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    cout, _ = ps.communicate()
    return str(cout, 'utf-8').strip()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--module', help="Module name", type=str)
    parser.add_argument('--version', help='Module version', type=str)
    parser.add_argument('--build_dir', help='Build directory', type=str)
    parser.add_argument('--sources', help='Sources', type=json.loads)
    args = parser.parse_args()

    distro_name = run_subprocess(['lsb_release', '-is']).lower()
    distro_ver = run_subprocess(['lsb_release', '-rs']).lower()
    major_ver = sys.version_info.major
    minor_ver = sys.version_info.minor

    python_ver = "{0}.{1}".format(major_ver, minor_ver)
    dirname = "".join(['conda', args.module, args.version])
    info_dir = "{0}/{1}/info/".format(args.build_dir, dirname)

    try:
        os.makedirs(os.path.dirname(info_dir))
    except OSError as exc:
        if exc.errno != errno.EEXIST:
            raise

    os.chdir("%s/%s" % (args.build_dir, dirname))

    build = "{0}_{1}_py{2}{3}".format(distro_name, distro_ver, major_ver, minor_ver)

    index_gen(info_dir, args.module, args.version, build, python_ver)

    paths_gen(info_dir, args.module, args.sources, python_ver)
    files_gen(info_dir, args.module, args.sources, python_ver, 'w')

    zipname = '%s-%s-%s.tar.bz2' % (args.module, args.version, build)

    with tarfile.open(zipname, 'w:bz2') as tar:
        for dir, files in args.sources.items():
            for file in files:
                f = os.path.join(dir, os.path.basename(file))
                tar.add(file, gen_bin_path(f) if is_script(f) else gen_libpy_path(args.module, f, python_ver))
        tar.add("info/index.json")
        tar.add("info/paths.json")
        tar.add("info/files")

    os.chdir("../")

    shutil.move('%s/%s' % (dirname, zipname), zipname)
    shutil.rmtree(dirname)
