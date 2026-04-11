project('semba', 'c', default_options : 'warning_level=3', meson_version : '>=1.4.0')

fs = import('fs')

nim = find_program('nim', required : true)
sqlite3_c = fs.copyfile('sqlite3.c')

cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required : false)

sqlite3 = executable('sqlite3', 'shell.c', 'sqlite3.c', dependencies : m_dep)

semba_core_files = [
    'sembademo.nim',
    'sembastable.nim',
    'protojson.nim',
    'sembaprivate.nim',
    'dungeongen.nim',
    'extsqlite.nim',
    'sembasave.nim',
    'semba_error.nim',
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
    'model_stable/area_locator.nim',
    'model_stable/area_object.nim',
    'model_stable/area_object_lock.nim',
    'model_stable/battle.nim',
    'model_stable/challenge.nim',
    'model_stable/challenge_progress.nim',
    'model_stable/challenge_task.nim',
    'model_stable/character.nim',
    'model_stable/character_likability.nim',
    'model_stable/character_mounting_power.nim',
    'model_stable/character_piece.nim',
    'model_stable/city.nim',
    'model_stable/dungeon.nim',
    'model_stable/enemy.nim',
    'model_stable/entity.nim',
    'model_stable/formation.nim',
    'model_stable/graffiti_art.nim',
    'model_stable/gacha.nim',
    'model_stable/gear.nim',
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
    'model_stable/tutorial.nim',
    'model_stable/user.nim',
    'model_stable/wallet.nim',
    'model_stable/warp_point.nim',
    'model_stable/xb.nim',
    'model_semba/gear.nim',
]

nim_release_args = ['--cc:gcc', '--gcc.exe=cc', '--gcc.linkerexe=cc']

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

if host_machine.system() == 'windows'
    exe_suffix = '.exe'
else
    exe_suffix = ''
endif

libsemba = custom_target(
    'libsemba',
    depends : [sqlite3_c, semba_db],
    depend_files : semba_core_files,
    input : ['semba.nim'],
    output : semba_output,
    command : [
        nim, 'c', '-d:staticSqlite', app_arg, '--noMain:on', nim_release_args,
        '-o:@OUTPUT@', '@INPUT@'
    ],
    build_by_default : true
)

test_semba_depend_files = [
    'tests/test_adventure.nim',
    'tests/test_battle.nim',
    'tests/test_character.nim',
    'tests/test_extra.nim',
    'tests/test_reward.nim',
    'tests/test_semba_private.nim',
    'tests/test_tip.nim',
    'tests/utils.nim',
    'tests/test_graffiti_art.nim',
]

test_semba = custom_target(
    depends : [sqlite3_c, semba_db],
    depend_files : semba_core_files + test_semba_depend_files,
    input : ['tests/test_semba.nim'],
    output : 'test_semba' + exe_suffix,
    command : [
        nim, 'c', '-d:staticSqlite', '--app:console', nim_release_args,
        '-o:@OUTPUT@', '@INPUT@'
    ],
    build_by_default : get_option('build_tests')
)

test_saves_path = meson.current_source_dir() + '/test_saves'

if build_machine.system() == 'windows'
    test_wrapper = executable('test_wrapper', 'test_wrapper.c')
    test('test semba', test_wrapper, args : [test_semba, test_saves_path])
else
    test('test semba', test_semba)
endif

semba_dep = declare_dependency(
    link_with : libsemba,
    include_directories : include_directories('.')
)