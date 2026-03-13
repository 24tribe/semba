project('semba', 'c', default_options : 'warning_level=3', meson_version : '>=1.4.0')

fs = import('fs')

nim = find_program('nim', required : true)
sqlite3_c = fs.copyfile('sqlite3.c')

cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required : false)

sqlite3 = executable('sqlite3', 'shell.c', 'sqlite3.c', dependencies : m_dep)

semba_core_files = [
    'sembacore.nim',
    'sembademo.nim',
    'sembastable.nim',
    'protojson.nim',
    'sembaprivate.nim',
    'dungeongen.nim',
    'extsqlite.nim',
    'sembasave.nim',
]

nim_release_args = ['--passL:-static']

if get_option('buildtype') == 'release'
    nim_release_args += ['-d:release']
endif

if build_machine.system() != 'windows'
    nim_release_args += ['-d:mingw']
endif

semba_db = custom_target(
    'semba_db',
    input : 'semba.sql',
    output : 'semba.db',
    command : [sqlite3, '@OUTPUT@'],
    feed : true,
    build_by_default : true,
    install : true,
    install_dir : '.'
)

if get_option('default_library') == 'static'
    semba_output = 'libsemba.a'
    app_arg = '--app:staticlib'
else
    semba_output = 'libsemba.dll'
    app_arg = '--app:lib'
endif

libsemba = custom_target(
    'libsemba',
    depends : [sqlite3_c],
    depend_files : semba_core_files,
    input : ['semba.nim'],
    output : semba_output,
    command : [
        nim, 'c', '-d:staticSqlite', app_arg, '--noMain:on', nim_release_args,
        '-o:@OUTPUT@', '@INPUT@'
    ],
    build_by_default : true
)

if get_option('build_semba_server')

sembaserver = custom_target(
    'sembaserver',
    depends : [sqlite3_c, semba_db],
    depend_files : semba_core_files,
    input : ['sembaserver.nim'],
    output : 'sembaserver.exe',
    command : [
        nim, 'c', '-d:staticSqlite', '--app:console', '--threadAnalysis:off', nim_release_args,
        '-o:@OUTPUT@', '@INPUT@'
    ],
    build_by_default : true
)

endif

if get_option('build_tests')

test_semba = custom_target(
    depends : [sqlite3_c, semba_db],
    depend_files : semba_core_files,
    input : ['test_semba.nim'],
    output : 'test_semba.exe',
    command : [
        nim, 'c', '-d:staticSqlite', '--app:console', nim_release_args,
        '-o:@OUTPUT@', '@INPUT@'
    ],
    build_by_default : true
)

test_wrapper = executable('test_wrapper', 'test_wrapper.c')

test('test semba', test_wrapper, args: test_semba)

endif

semba_dep = declare_dependency(
    link_with : libsemba,
    include_directories : include_directories('.')
)