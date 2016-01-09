include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/src/library/)

set (PLUGIN_NAME "classic")

include(ValaPrecompile)
vala_precompile(VALA_C ${PLUGIN_NAME}
    src/Task.vala
    src/TaskStore.vala
    src/TaskManager.vala
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

CUSTOM_VAPIS
    ${CMAKE_BINARY_DIR}/src/library/${PACKAGE_NAME}.vapi
OPTIONS
    ${VALAC_OPTIONS}
)

add_library(${PLUGIN_NAME} MODULE ${VALA_C})
target_link_libraries(${PLUGIN_NAME} ${LIBNAME})

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})

message("-- Classic plugin will be compiled")
