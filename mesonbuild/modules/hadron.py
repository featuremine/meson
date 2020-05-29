# Copyright 2016-2017 The Meson development team

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sysconfig
from .. import mesonlib, dependencies, build

from . import ExtensionModule
from mesonbuild.modules import ModuleReturnValue
from ..interpreterbase import noKwargs, permittedKwargs, FeatureDeprecated
from ..build import known_shmod_kwargs

import hashlib
import base64
import os
from sys import argv, version_info
import errno
from shutil import copyfile
from zipfile import ZipFile
import shutil
import subprocess
from pathlib import Path
import sys
import platform

class HadronModule(ExtensionModule):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def package(self, state, args, kwargs):
        if args:
            self.name = args[0]
        self.version = kwargs.get('version', '')
        self.mir_headers = kwargs.get('mir_headers', [])
        self.c_sources = kwargs.get('c_sources', [])
        self.py_sources = kwargs.get('py_sources', [])
        self.root_files = kwargs.get('root_files', [])
        self.extensions = kwargs.get('extensions', [])
        self.pkg_dir = os.path.join(state.environment.build_dir, 'package', self.name, self.version)
        self.api_gen_dir = os.path.join(state.environment.build_dir, 'api-gen', self.name, self.version)
        self.source_dir = state.environment.source_dir
        self.build_dir = state.environment.build_dir
        self.subdir = state.subdir
        self.subproject = state.subproject

        py_targets = self.py_src_targets()
        root_targets = self.root_files_targets()
        [ext_targets, ext_deps] = self.process_extensions()
        wheel_target = self.make_wheel_target(py_targets, root_targets, ext_deps)
        conda_target = self.make_conda_target(py_targets, root_targets, ext_deps)
        ret = py_targets + root_targets + [wheel_target] + [conda_target] + ext_targets

        self.make_racket_target()

        return ModuleReturnValue(ret, ret)
        # mir_gen = self._racket_generate(state, self.mir_headers)
        # self.c_sources.append(mir_gen)
        # shlib = build.SharedLibrary(self.name, state.subdir, state.subproject, False, self.c_sources, [], state.environment, kwargs)
        # rv = [mir_gen, shlib]
        # return ModuleReturnValue(rv, rv)

    def py_src_target(self, path):
        py = os.path.join(self.source_dir, 'lib', path)
        if not os.path.isfile(py):
            raise mesonlib.MesonException("Python source file '{0}' doesn't exist".format(py))
        custom_kwargs = {
            'input' : py,
            'output' : os.path.basename(path),
            'command' : ['cp', '@INPUT@', '@OUTPUT@'],
            'build_by_default' : True
        }
        return build.CustomTarget(path.replace('/', '_'), os.path.join(self.pkg_dir, os.path.dirname(path)), self.subproject, custom_kwargs)

    def py_src_targets(self):
        self.make_pkg_dir()
        targets = []
        for py in self.py_sources:
            targets.append(self.py_src_target(py))
        return targets

    def root_file_target(self, path):
        absolute_path = os.path.join(self.source_dir, 'lib', path)
        if not os.path.isfile(absolute_path):
            raise mesonlib.MesonException("The file '{0}' doesn't exist".format(absolute_path))
        custom_kwargs = {
            'input' : absolute_path,
            'output' : os.path.basename(path),
            'command' : ['cp', '@INPUT@', '@OUTPUT@'],
            'build_by_default' : True
        }
        return build.CustomTarget(path.replace('/', '_'), os.path.join(self.build_dir, 'package', self.name), self.subproject, custom_kwargs)

    def root_files_targets(self):
        self.make_pkg_dir()
        targets = []
        for root_file in self.root_files:
            targets.append(self.root_file_target(root_file))
        return targets

    def make_pkg_dir(self):
        if not os.path.exists(self.pkg_dir):
            os.makedirs(self.pkg_dir)

    def make_api_gen_dir(self):
        if not os.path.exists(self.api_gen_dir):
            os.makedirs(self.api_gen_dir)

    def make_racket_target(self):
        pass

    def run_mir_generation(self):
        self.make_api_gen_dir()
        tools_dir = os.path.join(self.source_dir, 'tools')
        mir_gen = os.path.join(tools_dir, 'mir', 'mir-generator.rkt')
        dest_dir = self.api_gen_dir
        target = []
        for mir_header in self.mir_headers:
            target += self.make_racket_targets(tools_dir, mir_gen, dest_dir, mir_header)

    def make_racket_targets(self, tools_dir, mir_gen, dest_dir, mir_header):
        cmd = ['racket', '-S', tools_dir, mir_gen, '-d', dest_dir, '-s', mir_header]
        sources = self.run_subprocess(cmd + ['-i'])
        dependencies = self.run_subprocess(cmd + ['-m'])
        target_deps = []
        res = []
        for dep in dependencies:
            target, children = self.make_racket_targets(tools_dir, mir_gen, dest_dir, dep)
            target_deps.append(target)
            res += children
        custom_kwargs = {

        }
        target = build.CustomTarget(mir_header.replace('/', '_'), os.path.join(self.build_dir, 'package', self.name), self.subproject, custom_kwargs) 
        return [target, children]

    def run_subprocess(self, cmd):
        ps = subprocess.Popen(cmd + ['-i'], stdout=subprocess.PIPE)
        cout, cerr = ps.communicate()
        return self.parse_mir_gen_output(cout)

    def parse_mir_gen_output(self, output):
        out = str(output, 'utf-8')
        def find(s, ch):
            return [i for i, ltr in enumerate(s) if ltr == ch]
        beg = find(out, '"')[-2]
        end = find(out, '"')[-1]
        return [path.strip() for path in out[beg+1:end].split(',')]

    def make_wheel_target(self, py_src_targets, root_files_targets, deps):
        py_script = os.path.join(self.source_dir, 'scripts', 'wheel_gen.py')
        major_ver = sys.version_info.major
        minor_ver = sys.version_info.minor
        name = '{0}-{1}-cp{2}{3}-cp{2}{3}m-linux_x86_64.whl'.format(self.name, self.version, major_ver, minor_ver)
        custom_kwargs = {
            'input': py_src_targets + root_files_targets,
            'output': name,
            'command': ['python3', py_script, self.name, self.version, self.build_dir, str(major_ver), str(minor_ver), '@INPUT@'],
            'depends': py_src_targets + root_files_targets + deps,
            'build_by_default' : True
        }
        return build.CustomTarget(name, self.subdir, self.subproject, custom_kwargs)

    def make_conda_target(self, py_src_targets, root_files_targets, deps):
        py_script = os.path.join(self.source_dir, 'scripts', 'conda_gen.py')
        major_ver = sys.version_info.major
        minor_ver = sys.version_info.minor
        distro_name = platform.linux_distribution()[0]
        distro_ver = platform.linux_distribution()[1]
        name = "{0}_{1}_py{2}{3}".format(distro_name, distro_ver, major_ver, minor_ver)
        custom_kwargs = {
            'input': py_src_targets + root_files_targets + deps,
            'output': name,
            'command': ['python3', py_script, distro_name, distro_ver, self.name, self.version, self.build_dir, str(major_ver), str(minor_ver), '@INPUT@'],
            'depends': py_src_targets + root_files_targets,
            'build_by_default' : True
        }
        return build.CustomTarget(name, self.subdir, self.subproject, custom_kwargs)

    def process_extensions(self):
        deps = []
        targets = []
        for extension in self.extensions:
            if isinstance(extension, str):
                pos = extension.find('/')
                if extension[:pos] != 'lib':
                    raise mesonlib.MesonException("Invalid path '{0}'. The file should be under 'lib' directory.".format(extension))
                custom_kwargs = {
                    'input': os.path.join(self.build_dir, extension),
                    'output': os.path.basename(extension),
                    'command': ['cp', '@INPUT@', '@OUTPUT@'],
                    'build_by_default': True
                }
                targets.append(build.CustomTarget(extension.replace('/', '_'), os.path.join(self.pkg_dir, os.path.dirname(extension[pos+1:])), self.subproject, custom_kwargs))
            elif isinstance(extension, build.BuildTarget):
                deps.append(extension)
        return [targets, deps]

def initialize(*args, **kwargs):
  return HadronModule(*args, **kwargs)
