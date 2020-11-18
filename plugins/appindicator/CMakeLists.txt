include (Translations)
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/src/lib/)

set (PLUGIN_NAME "appindicator")

set (VALA_PACKAGES
    gtk+-3.0
    libpeas-1.0
)

pkg_check_modules (APPINDICATOR_PLUGIN_DEPS
    ayatana-appindicator3-0.1
)

if (APPINDICATOR_PLUGIN_DEPS_FOUND)
    set (VALA_PACKAGES ${VALA_PACKAGES} ayatana-appindicator3-0.1)
else ()
    pkg_check_modules (APPINDICATOR_PLUGIN_DEPS
        appindicator3-0.1
    )
    set (VALA_PACKAGES ${VALA_PACKAGES} appindicator3-0.1)
endif ()

if (APPINDICATOR_PLUGIN_DEPS_FOUND)
    include(ValaPrecompile)
    vala_precompile(VALA_C ${PLUGIN_NAME}
        appindicator.vala

    # tell what libraries to use when compiling
    PACKAGES
        ${VALA_PACKAGES}

    CUSTOM_VAPIS
        ${CMAKE_BINARY_DIR}/src/${LIBNAME}.vapi
    OPTIONS
        ${VALAC_OPTIONS}
    )

    add_definitions(${APPINDICATOR_PLUGIN_DEPS_CFLAGS})
    link_directories (${APPINDICATOR_PLUGIN_DEPS_LIBRARY_DIRS})

    add_library(${PLUGIN_NAME} MODULE ${VALA_C})
    target_link_libraries(${PLUGIN_NAME} ${LIBNAME} ${APPINDICATOR_PLUGIN_DEPS_LIBRARIES})

    configure_file_translation (${PLUGIN_NAME}.plugin ${CMAKE_CURRENT_BINARY_DIR}/${PLUGIN_NAME}.plugin ${CMAKE_SOURCE_DIR}/po/)

    install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
    install(FILES "icons/status-break-symbolic.svg" DESTINATION ${PLUGINDIR}/${PLUGIN_NAME}/icons/)
    install(FILES "icons/status-task-symbolic.svg" DESTINATION ${PLUGINDIR}/${PLUGIN_NAME}/icons/)
    message("-- Ayatana indicator plugin will be compiled")
else ()
    message("-- Ayatana indicator plugin will not be compiled")
endif ()