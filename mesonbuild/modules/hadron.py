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
import mesonbuild
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
from collections import defaultdict
from copy import copy

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
        self.bin_files = kwargs.get('bin_files', [])
        self.suffix = kwargs.get('suffix', '')
        self.pkg_dir = os.path.join(state.environment.build_dir, 'package', self.name, self.version + self.suffix)
        self.api_gen_dir = os.path.join(state.environment.build_dir, 'api-gen', self.name, self.version + self.suffix)
        self.source_dir = state.environment.source_dir
        self.build_dir = state.environment.build_dir
        self.state = state
        self.subdir = state.subdir
        self.subproject = state.subproject
        self.sources = defaultdict(list)
        self.mir_targets_map = defaultdict(list)
        py_targets = self.py_src_targets()
        root_targets = self.root_files_targets()
        [ext_targets, ext_deps] = self.process_extensions()
        print(self.name + self.version + self.suffix)
        mir_targets = self.process_mir_headers()

        shalib_target = self.generate_sharedlib(mir_targets, kwargs)
        wheel_target = self.make_wheel_target(py_targets, root_targets, ext_deps)
        conda_target = self.make_conda_target(py_targets, root_targets, ext_deps)
        ret = py_targets + root_targets + mir_targets + [shalib_target] + [wheel_target] + [conda_target] + ext_targets

        self.make_racket_target()

        return ModuleReturnValue(ret, ret)

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
        self.sources[os.path.join(self.name, os.path.dirname(path))].append(os.path.join(self.pkg_dir, path))
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
        self.sources[""].append(os.path.join(self.build_dir, 'package', self.name, os.path.basename(path)))
        return build.CustomTarget(path.replace('/', '_'), os.path.join(self.build_dir, 'package', self.name), self.subproject, custom_kwargs)

    def root_files_targets(self):
        self.make_pkg_dir()
        targets = []
        for root_file in self.root_files:
            targets.append(self.root_file_target(root_file))
        return targets

    def process_bins(self, wheel):
        data_dir = "{0}-{1}.data".format(self.name, self.version)
        ret = defaultdict(list)
        for bin_file in self.bin_files:
            pos = bin_file.find('/')
            if bin_file[:pos] != 'lib':
                raise mesonlib.MesonException("Invalid path '{0}'. The bin should be under 'lib' directory.".format(bin_file))
            path = os.path.join(self.source_dir, bin_file) 
            if not os.path.isfile(path):
                raise mesonlib.MesonException("Bin file '{0}' doesn't exist".format(path))
            if wheel:
                ret[os.path.join(data_dir, os.path.dirname(bin_file[pos+1:]))].append(path)
            else:
                ret[bin_file].append(path)
        return ret

    def make_pkg_dir(self):
        if not os.path.exists(self.pkg_dir):
            os.makedirs(self.pkg_dir)

    def make_api_gen_dir(self):
        if not os.path.exists(self.api_gen_dir):
            os.makedirs(self.api_gen_dir)

    def make_racket_target(self):
        pass

    def get_base_cmd(self):
        tools_dir = os.path.join(self.source_dir, 'tools')
        mir_gen = os.path.join(tools_dir, 'mir', 'mir-generator.rkt')
        dest_dir = self.api_gen_dir
        return ['racket', '-S', tools_dir, mir_gen, '-d', dest_dir, '-r', self.source_dir]

    def run_mir_generation(self):
        self.make_api_gen_dir()
        base_cmd = self.get_base_cmd()
        print(self.mir_headers)
        for mir_header in self.mir_headers:
            self.make_racket_targets(base_cmd, mir_header)

    def make_abs_path(self, path):
        val = os.path.join(self.build_dir, path)
        return os.path.abspath(val)

    def make_relpath(self, path):
        return os.path.relpath(path, self.source_dir)

    def make_racket_targets(self, base_cmd, mir_header):
        #mir_path = self.make_abs_path(mir_header)
        mir_path = os.path.join(self.source_dir, 'lib', mir_header)
        print('mir_path: {}'.format(mir_path))
        name = self.make_relpath(mir_path).replace('/', '_')
        print('name: {}'.format(name))
        if name in self.mir_targets_map:
            return None
        cmd = base_cmd + ['-s', mir_path] #mir_path]
        print('cmd:{}'.format(cmd + ['-i']))
        sources = self.run_mir_subprocess(cmd + ['-i'])
        print('sources:{}'.format(sources))
        dependencies = self.run_mir_subprocess(cmd + ['-m'])
        #dependencies.remove(mir_header) # remove yourself
        print('dependencies:{}'.format(dependencies))
        deps = []
        for dep in dependencies:
            target = self.make_racket_targets(base_cmd, dep)
            if target is not None:
                deps.append(target)
        custom_kwargs = {
            'input': mir_path,
            'output': sources,
            'command': cmd,
            'build_by_default': True,
            'depends': deps
        }
        print('create_target {}'.format(name))
        target = build.CustomTarget(name, self.pkg_dir, self.subproject, custom_kwargs)
        self.mir_targets_map[name] = target
        return target

    def process_mir_headers(self):
        if len(self.mir_headers) == 0:
            return []
        self.run_mir_generation()
        targets = []
        for _, target in self.mir_targets_map.items():
            targets.append(target)
        common_mir_target = self.generate_common_mir_target(targets)
        targets.append(common_mir_target)
        return targets 

    def generate_sharedlib(self, mir_targets, kwargs):
        custom_kwargs = copy(kwargs)
        shlib = build.SharedLibrary(self.name+self.version+self.suffix, self.subdir, self.subproject, False, self.c_sources + mir_targets, [], self.state.environment, custom_kwargs)
        return shlib

    def generate_common_mir_target(self, mir_targets):
        cmd = []
        for header in self.mir_headers:
            header = os.path.join(self.source_dir, 'lib', header)
            cmd += ['-s', header]#self.make_abs_path(header)]
        cmd = self.get_base_cmd() + cmd
        print(cmd + ['-i', '-c'])
        sources = self.run_mir_subprocess(cmd + ['-i', '-c'])
        custom_kwargs = {
            'input': self.mir_headers,
            'output': sources,
            'command': cmd + ['-c'],
            'build_by_default': True,
            'depends': mir_targets
        }
        return build.CustomTarget('common_mir_target_'+self.name+self.version+self.suffix, self.pkg_dir, self.subproject, custom_kwargs)

    def run_mir_subprocess(self, cmd):
        ps = subprocess.Popen(cmd, stdout=subprocess.PIPE)
        cout, _ = ps.communicate()
        return self.parse_mir_gen_output(cout)

    def run_subprocess(self, cmd):
        ps = subprocess.Popen(cmd, stdout=subprocess.PIPE)
        cout, _ = ps.communicate()
        return str(cout, 'utf-8').strip()

    def parse_mir_gen_output(self, output):
        out = str(output, 'utf-8')
        def find(s, ch):
            return [i for i, ltr in enumerate(s) if ltr == ch]
        beg = find(out, '"')[-2]
        end = find(out, '"')[-1]
        data = [path.strip() for path in out[beg+1:end].split(',')]
        if len(data) > 0 and data[0] == '':
            return []
        return data

    def get_dictionary_as_str(self, dictionary):
        ret = str(dict(dictionary)).replace(' ','')
        print(ret)
        return ret.replace("'", "\"")

    def make_wheel_target(self, py_src_targets, root_files_targets, deps):
        py_script = os.path.join(self.source_dir, 'scripts', 'wheel_gen_ex.py')
        major_ver = sys.version_info.major
        minor_ver = sys.version_info.minor
        name = '{0}-{1}-cp{2}{3}-cp{2}{3}m-linux_x86_64.whl'.format(self.name, self.version, major_ver, minor_ver)
        src_copy = copy(self.sources)
        for dir, files in self.process_bins(True).items():
            for file in files:
                src_copy[dir].append(file)
        cmd = ['python3', py_script,
                '--module', self.name,
                '--version', self.version,
                '--build_dir', self.pkg_dir,
                '--sources', self.get_dictionary_as_str(src_copy)]
        custom_kwargs = {
            'input': py_src_targets + root_files_targets,
            'output': name,
            'command': cmd,
            'depends': py_src_targets + root_files_targets + deps,
            'build_by_default' : True
        }
        return build.CustomTarget(name + self.suffix, self.pkg_dir, self.subproject, custom_kwargs)

    def make_conda_target(self, py_src_targets, root_files_targets, deps):
        py_script = os.path.join(self.source_dir, 'scripts', 'conda_gen_ex.py')
        major_ver = sys.version_info.major
        minor_ver = sys.version_info.minor
        distro_name = self.run_subprocess(['lsb_release', '-is']).lower()
        distro_ver = self.run_subprocess(['lsb_release', '-rs']).lower()
        name = "{0}_{1}_py{2}{3}".format(distro_name, distro_ver, major_ver, minor_ver)
        src_copy = copy(self.sources)
        for dir, files in self.process_bins(False).items():
            for file in files:
                src_copy[dir].append(file)
        cmd = ['python3', py_script,
                '--module', self.name,
                '--version', self.version,
                '--build_dir', self.pkg_dir,
                '--sources', self.get_dictionary_as_str(src_copy)]
        custom_kwargs = {
            'input': py_src_targets + root_files_targets + deps,
            'output': name,
            'command': cmd,
            'depends': py_src_targets + root_files_targets,
            'build_by_default' : True
        }
        return build.CustomTarget(name + self.suffix, self.pkg_dir, self.subproject, custom_kwargs)

    def process_extensions(self):
        deps = []
        targets = []
        for extension in self.extensions:
            if hasattr(extension, 'held_object'):
                extension = extension.held_object
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
                self.sources[os.path.join(self.name, os.path.dirname(extension[pos+1:]))].append( os.path.join(self.pkg_dir, os.path.dirname(extension[pos+1:]), os.path.basename(extension)))
                targets.append(build.CustomTarget(extension.replace('/', '_'), os.path.join(self.pkg_dir, os.path.dirname(extension[pos+1:])), self.subproject, custom_kwargs))
            elif isinstance(extension, build.BuildTarget):
                subdir = extension.get_subdir()
                subdir_ = ''
                if subdir != 'lib':
                    subdir_ = subdir[subdir.find('/')+1:]
                for output in extension.get_outputs():
                    self.sources[os.path.join(self.name, subdir_)].append(os.path.join(self.build_dir, subdir, output))
                deps.append(extension)
        return [targets, deps]

def initialize(*args, **kwargs):
  return HadronModule(*args, **kwargs)
