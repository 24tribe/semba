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
    'semba_error.nim',
    'util.nim',
    'api_stable/adventure.nim',
    'api_stable/battle.nim',
    'api_stable/character.nim',
    'api_stable/dungeon.nim',
    'api_stable/event.nim',
    'api_stable/formation.nim',
    'api_stable/gacha.nim',
    'api_stable/mail.nim',
    'api_stable/news.nim',
    'api_stable/tension_card.nim',
    'api_stable/tip.nim',
    'api_stable/user.nim',
    'api_stable/xb.nim',
    'model_stable/adventure_variable.nim',
    'model_stable/area_change_lock.nim',
    'model_stable/area_group.nim',
    'model_stable/area_item.nim',
    'model_stable/area.nim',
    'model_stable/area_object.nim',
    'model_stable/battle.nim',
    'model_stable/challenge.nim',
    'model_stable/challenge_progress.nim',
    'model_stable/challenge_task.nim',
    'model_stable/character.nim',
    'model_stable/city.nim',
    'model_stable/dungeon.nim',
    'model_stable/enemy.nim',
    'model_stable/entity.nim',
    'model_stable/formation.nim',
    'model_stable/gacha.nim',
    'model_stable/item.nim',
    'model_stable/lux_phantasma.nim',
    'model_stable/magic_orb.nim',
    'model_stable/mail.nim',
    'model_stable/mission.nim',
    'model_stable/nine_sequence.nim',
    'model_stable/notification.nim',
    'model_stable/resources.nim',
    'model_stable/reward.nim',
    'model_stable/sequence_request.nim',
    'model_stable/tension_card.nim',
    'model_stable/timestamp.nim',
    'model_stable/tip.nim',
    'model_stable/total_task.nim',
    'model_stable/tutorial_state.nim',
    'model_stable/user.nim',
    'model_stable/wallet.nim',
    'model_stable/warp_point.nim',
    'model_stable/xb.nim',
]

nim_release_args = []

# always static link libc with windows (to avoid shipping mingw dlls)
if host_machine.system() == 'windows'
    nim_release_args += ['--passL:-static']
endif

if get_option('buildtype') == 'release'
    nim_release_args += ['-d:release']
endif

if build_machine.system() != 'windows' and host_machine.system() == 'windows'
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
    if host_machine.system() == 'windows'
        semba_output = 'libsemba.dll'
    else
        semba_output = 'libsemba.so'
    endif
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

test_semba = custom_target(
    depends : [sqlite3_c, semba_db],
    depend_files : semba_core_files,
    input : ['test_semba.nim'],
    output : 'test_semba.exe',
    command : [
        nim, 'c', '-d:staticSqlite', '--app:console', nim_release_args,
        '-o:@OUTPUT@', '@INPUT@'
    ],
    build_by_default : get_option('build_tests')
)

test_wrapper = executable('test_wrapper', 'test_wrapper.c')

test('test semba', test_wrapper, args: test_semba)

semba_dep = declare_dependency(
    link_with : libsemba,
    include_directories : include_directories('.')
)