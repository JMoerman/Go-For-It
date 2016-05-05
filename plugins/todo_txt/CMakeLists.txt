include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/src/library/)

set (PLUGIN_NAME "todo_txt")

include(ValaPrecompile)
vala_precompile(VALA_C ${PLUGIN_NAME}
    src/Filter.vala
    src/Plugin.vala
    src/SettingsManager.vala
    src/TaskManager.vala
    src/TaskStore.vala
    src/TXTTask.vala
    src/view/TaskRow.vala
    src/view/BottomBar.vala
    src/view/TodoView.vala

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

message("-- Todo.txt plugin will be compiled")
