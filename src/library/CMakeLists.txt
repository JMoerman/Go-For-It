configure_file (${CMAKE_CURRENT_SOURCE_DIR}/Constants.vala.cmake ${CMAKE_CURRENT_SOURCE_DIR}/Constants.vala)
configure_file (${CMAKE_CURRENT_SOURCE_DIR}/${PACKAGE_NAME}.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}.pc)

include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}
    Constants.vala
    Utils.vala
    application/SettingsManager.vala
    application/PluginManager.vala
    TaskTimer.vala
    TodoTask.vala
    Interface.vala
    TodoPlugin.vala

# tell what libraries to use when compiling
PACKAGES
    gtk+-3.0
    gee-0.8
    libpeas-1.0
    libpeas-gtk-1.0

OPTIONS
    ${VALAC_OPTIONS}
GENERATE_VAPI
    ${PACKAGE_NAME}
GENERATE_HEADER
    ${PACKAGE_NAME}
)

set (LIB_FILES ${C_SOURCES} ${VALA_C})

add_library (${LIBNAME} SHARED
    ${LIB_FILES}
)

set_target_properties (${LIBNAME} PROPERTIES
    VERSION ${LIBVERSION}.0
    SOVERSION ${SOVERSION})
    
list(APPEND VAPIFILES "${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}.vapi")

install (TARGETS ${LIBNAME} DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR})

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}.pc DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}.h DESTINATION ${CMAKE_INSTALL_FULL_INCLUDEDIR}/${PACKAGE_NAME}/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}.vapi DESTINATION ${CMAKE_INSTALL_FULL_DATAROOTDIR}/vala/vapi/)
