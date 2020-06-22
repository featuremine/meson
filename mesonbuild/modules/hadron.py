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
from ..interpreterbase import noKwargs, permittedKwargs, FeatureDeprecated, permittedKwargs
from ..build import known_shmod_kwargs
from .. import interpreter
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
import textwrap

hadron_package_kwargs = set([
    'version',
    'mir_headers',
    'c_sources',
    'py_sources',
    'root_files',
    'extensions',
    'bin_files',
    'suffix',
    'dependencies',
    'include_directories',
    'install',
    'verify'
])

class colors:
    RED = '\033[1;31m'
    NC = '\033[0m' 

class HadronModule(ExtensionModule):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.snippets.add('package')

    @permittedKwargs(hadron_package_kwargs)
    def package(self, interpr, state, args, kwargs):
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
        self.install = kwargs.get('install', False)
        self.verify = kwargs.get('verify', False)
        self.pkg_dir = os.path.join(state.environment.build_dir, 'package', self.version + self.suffix, self.name)
        self.api_gen_dir = os.path.join(state.environment.build_dir, 'api-gen', self.name, self.version + self.suffix)
        self.source_dir = state.environment.source_dir
        self.build_dir = state.environment.build_dir
        self.state = state
        self.subdir = state.subdir
        self.subproject = state.subproject
        self.sources = defaultdict(list)
        self.mir_targets_map = defaultdict(list)
        self.interpreter = interpr
        self.pymod = self.interpreter.func_import(None, ['python'], {})
        self.python3 = self.pymod.method_call('find_installation', [], {})
        verification_targets, py_targets = self.py_src_targets()
        root_targets = self.root_files_targets()
        [ext_targets, ext_deps] = self.process_extensions(self.extensions)
        mir_targets = self.process_mir_headers()
        ret = py_targets + verification_targets + root_targets + mir_targets + ext_targets
        shalib_target = self.generate_sharedlib(mir_targets, kwargs)
        if shalib_target is not None:
            init_target = self.gen_init_trgt(py_targets, root_targets, ext_deps, shalib_target)
            ret += [init_target, shalib_target]
            if self.install:
                wheel_target = self.make_wheel_target(py_targets, root_targets, ext_deps + [shalib_target, init_target])
                conda_target = self.make_conda_target(py_targets, root_targets, ext_deps + [shalib_target, init_target])
                ret += [wheel_target, conda_target]
        else:
            init_target = self.gen_init_trgt(py_targets, root_targets, ext_deps)
            ret += [init_target]
            if self.install:
                wheel_target = self.make_wheel_target(py_targets, root_targets, ext_deps + [init_target])
                conda_target = self.make_conda_target(py_targets, root_targets, ext_deps + [init_target])
                ret += [wheel_target, conda_target]
        for target in ret:
            if isinstance(target, interpreter.SharedModuleHolder):
                continue
            interpr.add_target(target.name, target)
        return interpr.holderify([init_target])

    def py_src_target(self, path, verification_targets = None):
        if not isinstance(path, mesonlib.File):
            raise mesonlib.MesonException("Expecting python source file '{}' to be File object".format(path))
        py = os.path.join(self.source_dir, path.subdir, path.fname)
        if not os.path.isfile(py):
            raise mesonlib.MesonException("Python source file '{0}' doesn't exist".format(py))
        custom_kwargs = {
            'input' : py,
            'output' : os.path.basename(path.fname),
            'command' : ['cp', '@INPUT@', '@OUTPUT@'],
            'build_by_default' : True
        }
        if verification_targets is not None:
            custom_kwargs['depends'] = verification_targets
        self.sources[os.path.join(self.name, os.path.dirname(path.fname))].append(os.path.join(self.pkg_dir, path.fname))
        return build.CustomTarget(py.replace('/', '_'), os.path.join(self.pkg_dir, os.path.dirname(path.fname)), self.subproject, custom_kwargs)

    def add_doctest_test(self, path, deps):
        """
        Add test to launch doctest.
        """

        if not isinstance(path, mesonlib.File):
            raise mesonlib.MesonException("Expecting python source file '{}' to be File object".format(path))

        module = f"{self.name}.{os.path.splitext(path.fname)[0].replace('/', '.')}"
        module_path = os.path.join(self.pkg_dir, '..')
        test_name = 'doctest_' + os.path.splitext(path.fname)[0].replace('/', '_')

        gen_script = textwrap.dedent(f"""\
            import doctest
            import {module}
            failure_count, _ = doctest.testmod({module})
            if failure_count > 0:
                exit(1)
        """)

        custom_kwargs = {
            'args': ['-c', gen_script],
            'depends': deps,
            'env': [f"PYTHONPATH={module_path}"],
            'timeout': 600,
            'is_parallel': True
        }
        args = [test_name, self.python3]
        self.interpreter.add_test(None, args, custom_kwargs, True)

    def target_name(self, prefix, path):
        if isinstance(path, mesonlib.File):
            path = os.path.join(path.subdir, path.fname)
        root, _ = os.path.splitext(path)
        return f"{prefix}_{root.replace('/', '_')}"

    def gen_mypy_trgt(self, path: mesonlib.File, deps) -> build.CustomTarget:
        """
        Generates custom target to run type annotation verification for that mypy is used.
        """

        if not isinstance(path, mesonlib.File):
            raise mesonlib.MesonException(f"Expecting python source file '{path}' to be File object")

        out_subdir = os.path.join(self.pkg_dir, os.path.dirname(path.fname))
        basename = os.path.basename(path.fname)
        in_path = os.path.join(self.source_dir, path.subdir, path.fname)
        out_path = os.path.join(out_subdir, basename + '.mypy')

        depfile_path = os.path.join(self.pkg_dir, os.path.dirname(path.fname), basename + '.mypy.d')

        gen_script = textwrap.dedent(f"""\
        import os
        import subprocess
        with open('{depfile_path}', 'w') as f:
            f.write('{os.path.basename(path.fname)}: {deps}')
        ps = subprocess.Popen(['mypy', '--disallow-untyped-defs', '--disallow-incomplete-defs', '--ignore-missing-imports', '{in_path}'],
                              stdout=subprocess.PIPE)
        cout, cerr = ps.communicate()
        cout = str(cout, 'utf-8').strip()
        if ps.returncode != 0:
            print("{colors.RED}ERROR: Invalid type verification for '{in_path}'.{colors.NC}")
            if cout:
                print(cout)
            print()
            if os.path.exists('{out_path}'):
                os.remove('{out_path}')
            exit(1)
        else:
            with open('{out_path}', 'w') as f:
                if cout:
                    f.write(cout)
        """)

        custom_kwargs = {
            'input': in_path,
            'output': basename + '.mypy',
            'command': ['python3', '-c', gen_script],
            'depfile': basename + '.mypy.d',
            'build_by_default': True,
            'depends': []
        }
        return build.CustomTarget(self.target_name('mypy', path), out_subdir, self.subproject, custom_kwargs)

    def gen_pylint_trgt(self, path: mesonlib.File, deps) -> build.CustomTarget:
        """
        Generates custom target to chech that every class and every method has docstring for that pylint is used.
        """

        if not isinstance(path, mesonlib.File):
            raise mesonlib.MesonException(f"Expecting python source file '{path}' to be File object")
        
        out_subdir = os.path.join(self.pkg_dir, os.path.dirname(path.fname))
        basename = os.path.basename(path.fname)
        in_path = os.path.join(self.source_dir, path.subdir, path.fname)
        out_path = os.path.join(out_subdir, basename + '.pylint')

        depfile_path = os.path.join(self.pkg_dir, os.path.dirname(path.fname), basename + '.pylint.d')

        gen_script = textwrap.dedent(f"""\
        import os
        import subprocess
        with open('{depfile_path}', 'w') as f:
            f.write('{os.path.basename(path.fname)}: {deps}')
        ps = subprocess.Popen(['pylint', '--disable=all', '--enable=missing-docstring', '{in_path}'],
                              stdout=subprocess.PIPE)
        cout, cerr = ps.communicate()
        cout = str(cout, 'utf-8').strip()
        if ps.returncode != 0:
            print("{colors.RED}ERROR: Missing docstring in '{in_path}'.{colors.NC}")
            if cout:
                print(cout)
            print()
            if os.path.exists('{out_path}'):
                os.remove('{out_path}')
            exit(1)
        else:
            with open('{out_path}', 'w') as f:
                if cout:
                    f.write(cout)
        """)

        custom_kwargs = {
            'input' : in_path,
            'output' : basename + '.pylint',
            'command' : ['python3', '-c', gen_script],
            'depfile': basename + '.pylint.d',
            'build_by_default' : True,
            'depends': []
        }
        return build.CustomTarget(self.target_name('pylint', path), out_subdir, self.subproject, custom_kwargs)

    def py_src_targets(self):
        self.make_pkg_dir()
        copy_targets = []
        verification_targets = []
        deps = " ".join([os.path.join(self.source_dir, path.subdir, path.fname) for path in self.py_sources])
        for py in self.py_sources:
            if self.verify:
                targets = [
                    self.gen_mypy_trgt(py, deps),
                    self.gen_pylint_trgt(py, deps)
                ]
                copy = self.py_src_target(py, targets)
                copy_targets.append(copy)
                self.add_doctest_test(py, copy)
                verification_targets += targets
            else:
                copy_targets.append(self.py_src_target(py))
        return [verification_targets, copy_targets]

    def root_file_target(self, path):
        if not isinstance(path, mesonlib.File):
            raise mesonlib.MesonException("Expecting root file '{}' to be File object".format(path))
        absolute_path = os.path.join(self.source_dir, path.subdir, path.fname)
        if not os.path.isfile(absolute_path):
            raise mesonlib.MesonException("The file '{0}' doesn't exist".format(absolute_path))
        custom_kwargs = {
            'input' : absolute_path,
            'output' : os.path.basename(path.fname),
            'command' : ['cp', '@INPUT@', '@OUTPUT@'],
            'build_by_default' : True
        }
        self.sources[""].append(os.path.join(self.build_dir, 'package', self.version + self.suffix, os.path.basename(path.fname)))
        return build.CustomTarget(absolute_path.replace('/', '_'), os.path.join(self.build_dir, 'package', self.version + self.suffix), self.subproject, custom_kwargs)

    def root_files_targets(self):
        self.make_pkg_dir()
        targets = []
        for root_file in self.root_files:
            targets.append(self.root_file_target(root_file))
        return targets

    def process_bins(self, wheel):
        data_dir = f"{self.name}-{self.version}{self.suffix}.data"
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

    def get_base_cmd(self):
        tools_dir = os.path.join(self.source_dir, 'tools')
        mir_gen = os.path.join(tools_dir, 'mir', 'mir-generator.rkt')
        dest_dir = self.api_gen_dir
        return ['racket', '-S', tools_dir, mir_gen, '-d', dest_dir, '-r', os.path.join(self.source_dir, self.subdir)]

    def run_mir_generation(self):
        self.make_api_gen_dir()
        base_cmd = self.get_base_cmd()
        for mir_header in self.mir_headers:
            self.make_racket_targets(base_cmd, mir_header)

    def make_abs_path(self, path):
        val = os.path.join(self.build_dir, path)
        return os.path.abspath(val)

    def make_relpath(self, path):
        return os.path.relpath(path, self.source_dir)

    def make_racket_targets(self, base_cmd, mir_header):
        if isinstance(mir_header, mesonlib.File):
            mir_path = os.path.join(self.source_dir, mir_header.subdir, mir_header.fname)
        elif isinstance(mir_header, str) and os.path.isabs(mir_header):
            mir_path = mir_header
        else:
            raise mesonlib.MesonException("Expecting mir header '{}' to be an absolute path or File object".format(mir_header))
        name = self.make_relpath(mir_path).replace('/', '_')
        if name in self.mir_targets_map:
            return self.mir_targets_map[name]
        cmd = base_cmd + ['-s', mir_path]
        sources = self.run_mir_subprocess(cmd + ['-i'])
        relative_sources = [os.path.relpath(source, self.build_dir) for source in sources]
        dependencies = self.run_mir_subprocess(cmd + ['-m'])
        deps = []
        for dep in dependencies:
            target = self.make_racket_targets(base_cmd, dep)
            if target is not None:
                deps.append(target)
            else:
                dep_mir_path = os.path.join(self.source_dir, 'lib', dep)
                dep_name = self.make_relpath(dep_mir_path).replace('/', '_')
                deps.append(self.mir_targets_map[dep_name])
        custom_kwargs = {
            'input': mir_path,
            'output': relative_sources,
            'command': cmd,
            'build_by_default': True,
            'depends': deps
        }
        target = build.CustomTarget(name, '', self.subproject, custom_kwargs)
        self.mir_targets_map[name] = target
        return target

    def process_mir_headers(self):
        if not self.mir_headers:
            return []
        self.run_mir_generation()
        targets = []
        for _, target in self.mir_targets_map.items():
            targets.append(target)
        common_mir_target = self.generate_common_mir_target(targets)
        targets.append(common_mir_target)
        return targets 

    def generate_sharedlib(self, mir_targets, kwargs):
        if not mir_targets:
            return None
        custom_kwargs = copy(kwargs)
        def remove_key(key):
            if custom_kwargs.get(key):
                del custom_kwargs[key]
        remove_key('mir_headers')
        remove_key('c_sources')
        remove_key('py_sources')
        remove_key('root_files')
        remove_key('extensions')
        remove_key('bin_files')
        remove_key('suffix')
        incdirs = custom_kwargs.get('include_directories')
        if incdirs:
            if hasattr(incdirs, 'held_object'):
                incdirs = incdirs.held_object
            if isinstance(incdirs, list):
                incdirs.append(build.IncludeDirs(self.api_gen_dir, ['.'], False))
                custom_kwargs['include_directories'] = incdirs
            elif isinstance(incdirs, build.IncludeDirs):
                custom_kwargs['include_directories'] = [incdirs , build.IncludeDirs(self.api_gen_dir, ['.'], False)]
            else:
                raise mesonlib.MesonException("Invalid include_directories in target {}{}{}".format(self.name, self.version, self.suffix))
        subdir = self.interpreter.subdir
        self.interpreter.subdir = self.pkg_dir
        holders = [interpreter.TargetHolder(target, self.interpreter) for target in mir_targets]
        shlib = self.python3.extension_module_method(['_mir_wrapper'] + self.c_sources + holders, custom_kwargs)
        self.sources[self.name].append(os.path.join(self.build_dir, self.interpreter.subdir, shlib.held_object.filename))
        self.interpreter.subdir = subdir
        return shlib

    def generate_common_mir_target(self, mir_targets):
        cmd = []
        headers = []
        for header in self.mir_headers:
            header = os.path.join(self.source_dir, header.subdir, header.fname)
            cmd += ['-s', header]
            headers += [header]
        cmd = self.get_base_cmd() + cmd
        sources = self.run_mir_subprocess(cmd + ['-i', '-c'])
        relative_sources = [os.path.relpath(source, self.build_dir) for source in sources]
        custom_kwargs = {
            'input': headers,
            'output': relative_sources,
            'command': cmd + ['-c'],
            'build_by_default': True,
            'depends': mir_targets
        }
        return build.CustomTarget('common_mir_target_'+self.name+self.version+self.suffix, '', self.subproject, custom_kwargs)

    def run_mir_subprocess(self, cmd):
        output = self.run_subprocess(cmd)
        return self.parse_mir_gen_output(output)

    def run_subprocess(self, cmd):
        ps = subprocess.Popen(cmd, stdout=subprocess.PIPE)
        cout, cerr = ps.communicate()
        if ps.returncode != 0:
            cmd_string_view = ''
            for elem in cmd:
                cmd_string_view += elem + ' '
            raise mesonlib.MesonException("Failed to execute '{0}' command line. Error: {1}".format(cmd_string_view, cerr))
        return str(cout, 'utf-8').strip()

    def parse_mir_gen_output(self, output):
        def find(s, ch):
            return [i for i, ltr in enumerate(s) if ltr == ch]
        quotes = find(output, '"')
        data = [path.strip() for path in output[quotes[-2]+1:quotes[-1]].split(',')]
        if data and data[0] == '':
            return []
        return data

    def get_dictionary_as_str(self, dictionary):
        ret = str(dict(dictionary)).replace(' ','')
        return ret.replace("'", "\"")

    def make_wheel_target(self, py_src_targets, root_files_targets, deps):
        py_script = os.path.join(self.source_dir, 'scripts', 'wheel_gen_ex.py')
        major_ver = sys.version_info.major
        minor_ver = sys.version_info.minor
        name = '{0}-{1}-cp{2}{3}-cp{2}{3}m-linux_x86_64.whl'.format(self.name, "".join([self.version, self.suffix]), major_ver, minor_ver)
        src_copy = copy(self.sources)
        for dir, files in self.process_bins(True).items():
            for file in files:
                src_copy[dir].append(file)
        cmd = ['python3', py_script,
                '--module', self.name,
                '--version', "".join([self.version, self.suffix]),
                '--build_dir', os.path.join(self.build_dir, 'package'),
                '--sources', self.get_dictionary_as_str(src_copy)]
        custom_kwargs = {
            'input': py_src_targets + root_files_targets + deps,
            'output': name,
            'command': cmd,
            'depends': py_src_targets + root_files_targets + deps,
            'build_by_default': True
        }
        if self.install:
            custom_kwargs['install'] = self.install
            custom_kwargs['install_dir'] = '.'
        return build.CustomTarget(name, os.path.join(self.build_dir, 'package'), self.subproject, custom_kwargs)

    def make_conda_target(self, py_src_targets, root_files_targets, deps):
        py_script = os.path.join(self.source_dir, 'scripts', 'conda_gen_ex.py')
        major_ver = sys.version_info.major
        minor_ver = sys.version_info.minor
        distro_name = self.run_subprocess(['lsb_release', '-is']).lower()
        distro_ver = self.run_subprocess(['lsb_release', '-rs']).lower()
        build_name = "{}_{}_py{}{}".format(distro_name, distro_ver, major_ver, minor_ver)
        name = '{}-{}-{}.tar.bz2'.format(self.name, "".join([self.version, self.suffix]), build_name)
        src_copy = copy(self.sources)
        for dir, files in self.process_bins(False).items():
            for file in files:
                src_copy[dir].append(file)
        cmd = ['python3', py_script,
                '--module', self.name,
                '--version', "".join([self.version, self.suffix]),
                '--build_dir', os.path.join(self.build_dir, 'package'),
                '--sources', self.get_dictionary_as_str(src_copy)]
        custom_kwargs = {
            'input': py_src_targets + root_files_targets + deps,
            'output': name,
            'command': cmd,
            'depends': py_src_targets + root_files_targets + deps,
            'build_by_default': True
        }
        if self.install:
            custom_kwargs['install'] = self.install
            custom_kwargs['install_dir'] = '.'
        return build.CustomTarget(name, os.path.join(self.build_dir, 'package'), self.subproject, custom_kwargs)

    def process_extensions(self, extensions):
        deps = []
        targets = []
        for extension in extensions:
            if hasattr(extension, 'held_object'):
                extension = extension.held_object
            if isinstance(extension, mesonlib.File):
                path = os.path.join(self.source_dir, extension.subdir, extension.fname)
                custom_kwargs = {
                    'input': path,
                    'output': extension.fname,
                    'command': ['cp', '@INPUT@', '@OUTPUT@'],
                    'build_by_default': True
                }
                self.sources[os.path.join(self.name)].append( os.path.join(self.pkg_dir, extension.fname))
                targets.append(build.CustomTarget(path.replace('/', '_'), os.path.join(self.pkg_dir), self.subproject, custom_kwargs))
            elif isinstance(extension, build.BuildTarget):
                subdir = extension.get_subdir()
                subdir_ = ''
                if subdir != 'lib':
                    subdir_ = subdir[subdir.find('/')+1:]
                for output in extension.get_outputs():
                    self.sources[os.path.join(self.name, subdir_)].append(os.path.join(self.build_dir, subdir, output))
                deps.append(extension)
                custom_kwargs = {
                    'input': extension,
                    'output': extension.get_outputs(),
                    'command': ['cp', '@INPUT@', self.pkg_dir],
                    'depends': extension,
                    'build_by_default' : True
                }
                targets.append(build.CustomTarget("_".join(['copy', extension.name, output]), self.pkg_dir, self.subproject, custom_kwargs))
            elif isinstance(extension, str):
                if os.path.isabs(extension):
                    name = os.path.basename(extension)
                    custom_kwargs = {
                        'input': extension,
                        'output': name,
                        'command': ['cp', '@INPUT@', self.pkg_dir],
                        'build_by_default' : True
                    }
                    self.sources[os.path.join(self.name)].append(os.path.join(self.pkg_dir, name))
                    targets.append(build.CustomTarget("_".join(['copy', name]), self.pkg_dir, self.subproject, custom_kwargs))
            elif isinstance(extension, list):
                t, d = self.process_extensions(extension)
                deps += d
                targets += t
        return [targets, deps]

    def gen_init_trgt(self, py_src_targets, root_files_targets, deps, shlib = None):
        """
        Generates custom target to create __init__.py in package folder.
        """

        out_path = os.path.join(self.pkg_dir, '__init__.py')
        depends = py_src_targets + root_files_targets + deps

        gen_script = textwrap.dedent(f"""\
        import os
        if not os.path.exists('{out_path}'):
            with open('{out_path}', 'w') as f:
                f.write('from ._mir_wrapper import *')""")

        if shlib is not None:
            depends += [shlib]
            cmd = ['python3', '-c',gen_script ]
        else:
            cmd = ['touch', '@OUTPUT@']
        custom_kwargs = {
            'input': depends,
            'output': '__init__.py',
            'command': cmd,
            'depends': depends,
            'build_by_default' : True
        }
        self.sources[self.name].append(out_path)
        return build.CustomTarget('__init__', self.pkg_dir, self.subproject, custom_kwargs)

def initialize(*args, **kwargs):
  return HadronModule(*args, **kwargs)
