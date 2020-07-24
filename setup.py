#!/usr/bin/env python3

# Copyright 2016 The Meson development team

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys
import os

if sys.version_info < (3, 5, 0):
    print('Tried to install with an unsupported version of Python. '
          'Meson requires Python 3.5.0 or greater')
    sys.exit(1)

from mesonbuild.coredata import version
from setuptools import setup

# On windows, will create Scripts/meson.exe and Scripts/meson-script.py
# Other platforms will create bin/meson
entries = {'console_scripts': ['meson=mesonbuild.mesonmain:main']}
packages = ['mesonbuild',
            'mesonbuild.ast',
            'mesonbuild.backend',
            'mesonbuild.compilers',
            'mesonbuild.dependencies',
            'mesonbuild.modules',
            'mesonbuild.scripts',
            'mesonbuild.wrap']

# include mir staff
mir_data = ['tools/mir/utils.rkt',
            'tools/mir/c-generator.rkt',
            'tools/mir/mir-generator.rkt',
            'tools/mir/main.rkt',
            'tools/mir/common-c.rkt',
            'tools/mir/core.rkt',
            'tools/mir/python-generator.rkt',
            'tools/mir/pythongen/common_c.h',
            'tools/mir/pythongen/utils.h',
            'tools/mir/pythongen/utils.c']

package_data = {'mesonbuild': mir_data,
                'mesonbuild.dependencies': ['data/CMakeLists.txt', 'data/CMakeListsLLVM.txt', 'data/CMakePathInfo.txt']}

data_files = []
if sys.platform != 'win32':
    # Only useful on UNIX-like systems
    data_files = [('share/man/man1', ['man/meson.1']),
                  ('share/polkit-1/actions', ['data/com.mesonbuild.install.policy'])]

# load requirements
lib_path = os.path.dirname(os.path.realpath(__file__))
req_path = os.path.join(lib_path, 'requirements.txt')
reqs = []
if os.path.isfile(req_path):
    with open(req_path) as f:
        reqs = [line for line in f.read().splitlines() if len(line) > 0 and not line.startswith('#')]

if __name__ == '__main__':
    setup(name='meson',
          version=version,
          description='A high performance build system',
          author='Jussi Pakkanen',
          author_email='jpakkane@gmail.com',
          url='http://mesonbuild.com',
          license=' Apache License, Version 2.0',
          python_requires='>=3.5',
          packages=packages,
          package_data=package_data,
          entry_points=entries,
          data_files=data_files,
          install_requires=reqs,
          classifiers=['Development Status :: 5 - Production/Stable',
                       'Environment :: Console',
                       'Intended Audience :: Developers',
                       'License :: OSI Approved :: Apache Software License',
                       'Natural Language :: English',
                       'Operating System :: MacOS :: MacOS X',
                       'Operating System :: Microsoft :: Windows',
                       'Operating System :: POSIX :: BSD',
                       'Operating System :: POSIX :: Linux',
                       'Programming Language :: Python :: 3 :: Only',
                       'Topic :: Software Development :: Build Tools',
                       ],
          long_description='''Meson is a cross-platform build system designed to be both as
    fast and as user friendly as possible. It supports many languages and compilers, including
    GCC, Clang and Visual Studio. Its build definitions are written in a simple non-turing
    complete DSL.''')
