# sudo racket -S ../mesonbuild/tools ../mesonbuild/tools/mir/mir-generator.rkt -d api-gen/pythongen -s "../test cases/mir/1 python gen/mir-sources/callable.mir"  -I "../test cases/mir/1 python gen" -r ../test\ cases/mir/1\ python\ gen/ -c
# PYTHONPATH=build/lib.linux-x86_64-3.8 python3 ../test\ cases/mir/1\ python\ gen/callable.py build
# PYTHONPATH=build/lib.linux-x86_64-3.8 python3 ../test\ cases/mir/1\ python\ gen/test_callable.py build
from distutils.core import setup, Extension
import subprocess


def get_src(command):
    src_info = subprocess.run(command.split(","), stdout=subprocess.PIPE)
    print(src_info.stdout.decode("utf-8"))
    data = src_info.stdout.decode("utf-8").replace("\"", "") .split("\n")[-2].split(", ")
    return [item for item in data if item[-1] == 'c']

src = get_src('racket,-S,../mesonbuild/tools,../mesonbuild/tools/mir/mir-generator.rkt,-d,api-gen/pythongen,-s,../test cases/mir/1 python gen/mir-sources/callable.mir,-I,../test cases/mir/1 python gen,-i,-r,../test cases/mir/1 python gen/')
src_c = get_src('racket,-S,../mesonbuild/tools,../mesonbuild/tools/mir/mir-generator.rkt,-d,api-gen/pythongen,-s,../test cases/mir/1 python gen/mir-sources/callable.mir,-I,../test cases/mir/1 python gen,-i,-c,-r,../test cases/mir/1 python gen/')
sources = [
    "../test cases/mir/1 python gen/callable_source.c",
    "../mesonbuild/tools/mir/pythongen/utils.c",
] + src + src_c


includes = [
    ".",
    "api-gen/pythongen",
    "../include",
    "../mesonbuild/tools",
    "../test cases/mir/1 python gen"
]


def main():
    setup(name="_mir_wrapper",
          version="1.0.0",
          description="Graph",
          author="Featuremine",
          author_email="your_email@gmail.com",
          ext_modules=[Extension("_mir_wrapper", sources=sources, include_dirs=includes)])


if __name__ == "__main__":
    main()
