project (go-for-it)

cmake_minimum_required (VERSION 2.6)
# tell cmake where its modules can be found in our project directory
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
include (GNUInstallDirs)
# where we install data directory (if we have any)
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")

set (PKGDATADIR "${DATADIR}/go-for-it")
set (PLUGINDIR "${CMAKE_INSTALL_FULL_LIBDIR}/${CMAKE_PROJECT_NAME}/plugins")
set (CONF_DIR_NAME "go-for-it")
set (FILE_CONF "go-for-it.conf")

set (APP_NAME "Go For It!")
set (APP_ID "de.manuel-kehl.go-for-it")
set (EXEC_NAME "go-for-it")
set (RELEASE_NAME "A stylish to-do list with built-in productivity timer.")
set (LIBNAME "gofi")
set (LIBVERSION "0")
set (SOVERSION 0)
set (PACKAGE_NAME "go-for-it")

set (VERSION "1.4.3")
set (VERSION_INFO "wip git branch")

set (PROJECT_WEBSITE "http://manuel-kehl.de/projects/go-for-it/")
set (PROJECT_REPO "https://github.com/mank319/Go-For-It")
set (PROJECT_DONATIONS "http://manuel-kehl.de/donations/")

set (DEFAULT_PLUGINS "{\"classic\",\"todo_txt\"}")

set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

# find pkgconfig to make sure dependencies are installed
find_package(PkgConfig)
# check for the required dependencies
pkg_check_modules(DEPS REQUIRED
    gtk+-3.0
    glib-2.0
    gee-0.8
    libnotify
    libpeas-1.0
    libpeas-gtk-1.0
)

set (GLOBAL_VALAC_OPTIONS)

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

# disable c compiler warnings
add_definitions(-w)
add_definitions(-DGETTEXT_PACKAGE="go-for-it")

# make sure we have vala
find_package(Vala REQUIRED)
# make sure we use vala
include(ValaVersion)
# make sure it's the desired version of vala
ensure_vala_version("0.24" MINIMUM)
# files we want to compile

add_subdirectory (src)
add_subdirectory (plugins)

# install .desktop file so the Applications menu will display it
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/go-for-it.desktop DESTINATION ${DATADIR}/applications/)
# install the application's stylesheet
install (DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/style DESTINATION ${PKGDATADIR})
# install the application's icons
set(SYSTEM_DEFAULT_THEME ${CMAKE_INSTALL_PREFIX}/share/icons/hicolor)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/16x16/apps/go-for-it.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/16x16/apps)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/24x24/apps/go-for-it.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/24x24/apps)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/32x32/apps/go-for-it.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/32x32/apps)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/48x48/apps/go-for-it.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/48x48/apps)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/64x64/apps/go-for-it.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/64x64/apps)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/128x128/apps/go-for-it.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/128x128/apps)
# install the fallback menu icon
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/24x24/actions/go-for-it-open-menu-fallback.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/24x24/actions)


install(
    CODE
    "execute_process (COMMAND gtk-update-icon-cache -t -f ${SYSTEM_DEFAULT_THEME})"
    CODE
    "message (STATUS \"Updated icon cache in ${SYSTEM_DEFAULT_THEME}\")"
    )
