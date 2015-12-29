project (classic-plugin)

cmake_minimum_required (VERSION 2.6)
# tell cmake where its modules can be found in our project directory
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
include (GNUInstallDirs)
set (PLUGINDIR "${CMAKE_INSTALL_FULL_LIBDIR}/go-for-it/plugins")

set (PLUGIN_NAME "classic")

# find pkgconfig to make sure dependencies are installed
find_package(PkgConfig)
# check for the required dependencies
pkg_check_modules(DEPS REQUIRED
    gtk+-3.0
    glib-2.0
    gee-0.8
    libpeas-1.0
    libpeas-gtk-1.0
    go-for-it
)

set (GLOBAL_VALAC_OPTIONS)

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

# disable c compiler warnings
add_definitions(-w)
add_definitions(-DGETTEXT_PACKAGE="go-for-it-classic")

# make sure we have vala
find_package(Vala REQUIRED)
# make sure we use vala
include(ValaVersion)
# make sure it's the desired version of vala
ensure_vala_version("0.16" MINIMUM)
# files we want to compile
include(ValaPrecompile)
vala_precompile(VALA_C ${PLUGIN_NAME}
    src/TaskStore.vala
    src/TaskManager.vala
    src/Task.vala
    src/SettingsManager.vala
    src/Classic.vala
    src/view/TaskList.vala
    src/view/SettingsWidget.vala

# tell what libraries to use when compiling
PACKAGES
    gtk+-3.0
    gee-0.8
    libpeas-1.0
    libpeas-gtk-1.0
    go-for-it

OPTIONS
    ${VALAC_OPTIONS}
)

add_library(${PLUGIN_NAME} MODULE ${VALA_C})
add_dependencies(${PLUGIN_NAME} ${LIBNAME} scratch)

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
