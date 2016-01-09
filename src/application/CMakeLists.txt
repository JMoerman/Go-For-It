include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/src/library/)

include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}
    Main.vala
    view/AboutDialog.vala
    view/ContributeDialog.vala
    view/SettingsDialog.vala
    view/TimerView.vala
    view/MainLayout.vala
    view/PluginSelector.vala
    view/MainWindow.vala

# tell what libraries to use when compiling
PACKAGES
    gtk+-3.0
    gee-0.8
    libnotify
    libpeas-1.0
    libpeas-gtk-1.0

CUSTOM_VAPIS
    ${CMAKE_BINARY_DIR}/src/library/${PACKAGE_NAME}.vapi
OPTIONS
    ${VALAC_OPTIONS}
)

# tell cmake what to call the executable we just made
add_executable(${EXEC_NAME} ${VALA_C})
target_link_libraries(${EXEC_NAME} ${LIBNAME})
# install the binaries we just made
install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)
