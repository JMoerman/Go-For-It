include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/src/lib/)

set (PLUGIN_NAME "launcherindicator")

option (USE_BUILTIN_LIBUNITY "Use builtin libunity library " OFF)
set (USE_LIBUNITY !${USE_BUILTIN_LIBUNITY})
if (USE_LIBUNITY)
    pkg_check_modules (PLUGIN_DEPS
        unity
    )
else ()
    pkg_check_modules (PLUGIN_DEPS
        dbusmenu-glib-0.4
        dee-1.0
    )
endif ()

if (PLUGIN_DEPS_FOUND)
    include(ValaPrecompile)

    if (USE_LIBUNITY)
        vala_precompile(VALA_C ${PLUGIN_NAME}
            LauncherIndicator.vala

        # tell what libraries to use when compiling
        PACKAGES
            gtk+-3.0
            libpeas-1.0
            unity

        CUSTOM_VAPIS
            ${CMAKE_BINARY_DIR}/src/${LIBNAME}.vapi
        OPTIONS
            ${VALAC_OPTIONS}
        )
    else ()
        vala_precompile(VALA_C ${PLUGIN_NAME}
            libunity/unity-launcher.vala
            LauncherIndicator.vala

        # tell what libraries to use when compiling
        PACKAGES
            gtk+-3.0
            libpeas-1.0
            dee-1.0

        CUSTOM_VAPIS
            ${CMAKE_BINARY_DIR}/src/${LIBNAME}.vapi
            ${CMAKE_CURRENT_SOURCE_DIR}/libunity/dbusmenu-glib-0.4.vapi
        OPTIONS
            ${VALAC_OPTIONS}
        )
    endif ()

    add_definitions(${PLUGIN_DEPS_CFLAGS})
    link_directories (${PLUGIN_DEPS_LIBRARY_DIRS})

    add_library(${PLUGIN_NAME} MODULE ${VALA_C})
    target_link_libraries(${PLUGIN_NAME} ${LIBNAME} ${PLUGIN_DEPS_LIBRARIES})

    install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
    install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})

    message("-- Launcher inidicator plugin (libunity) will be compiled")
else ()
    message("-- Launcher inidicator plugin (libunity) will not be compiled")
endif ()
