project('mir python gen', 'cpp','c')

pymod = import('python')
hadron = import('hadron')

python = pymod.find_installation(required: true)
python_version = python.language_version().split('.')
if (python_version[0].to_int() < 3 or python_version[1].to_int() < 7)
  error('support python version 3.7 and higher')
endif

mir_files = files(
  'mir-sources/aliases.mir',
  'mir-sources/point.mir',
  'mir-sources/utility.mir'
)

c_sources = files(
    'aliases_source.c',
    'point_source.c',
    'utility_source.c'
)


base_package = hadron.package('pythongen',
            dependencies : [python.dependency(embed:true)],
            mir_headers: mir_files,
            c_sources: c_sources,
            python: python,
            )
message(meson.source_root())
test('pythongen-test', python,
     args : [meson.source_root()+'/test.py'],
     env : ['PYTHONPATH='+meson.build_root()+'/package/pythongen'])
