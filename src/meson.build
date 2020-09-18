configurationData = configuration_data()
configurationData.set('PACKAGE_NAME', meson.project_name())
configurationData.set('LOCALE_DIR', LOCALE_DIR)
configure_file(input: 'config.h.in', output: 'config.h', configuration: configurationData)

install_data('PiTempMonitor.plugin', install_dir: LIB_INSTALL_DIR)

PiTempMonitorSources = [
'pi-tempmonitor.vala'
]

PiTempMonitorDependencies = [
dependency('gtk+-3.0'), 
dependency('budgie-1.0'),
dependency('libpeas-gtk-1.0'),
meson.get_compiler('c').find_library('m', required: false)
]

PiTempMonitorValaArgs = [
'--pkg=config', 
'--vapidir=' + VAPI_DIR, 
'--target-glib=2.38',
]

PiTempMonitorCArgs = [
'-include', 
'config.h',
'-lm'
]

shared_library(
    'pi-tempmonitor', 
    PiTempMonitorSources, 
    dependencies: PiTempMonitorDependencies, 
    vala_args: PiTempMonitorValaArgs, 
    c_args: PiTempMonitorCArgs, 
    install: true, 
    install_dir: LIB_INSTALL_DIR
)




