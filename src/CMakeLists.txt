# Create Constants.vala
configure_file (${CMAKE_CURRENT_SOURCE_DIR}/Constants.vala.cmake ${CMAKE_CURRENT_SOURCE_DIR}/Constants.vala)
configure_file (${CMAKE_CURRENT_SOURCE_DIR}/go-for-it.pc.in ${CMAKE_CURRENT_BINARY_DIR}/${LIBNAME}.pc)

if (${NO_CONTRIBUTE_DIALOG})
    set (VALAC_OPTIONS ${VALAC_OPTIONS} -D NO_CONTRIBUTE_DIALOG)
endif ()
if (${SHOW_ABOUT})
    set (VALAC_OPTIONS ${VALAC_OPTIONS} -D SHOW_ABOUT)
endif ()

add_definitions(-DG_LOG_DOMAIN="${LIBNAME}")

# checking if have a recent version of Gtk+-3.0
pkg_check_modules( GTK3 gtk+-3.0 )
if (${GTK3_VERSION} VERSION_GREATER 3.21)
    set (VALAC_OPTIONS ${VALAC_OPTIONS} -D HAS_GTK322)
else ()
    message ("-- No recent Gtk+-3.0 found... Using pre 3.22 features.")
endif ()

set (VALA_PACKAGES ${DEPS_VALA_PACKAGES})

if (USE_GRANITE)
    set (VALAC_OPTIONS ${VALAC_OPTIONS} -D USE_GRANITE)
    set (VALA_PACKAGES ${VALA_PACKAGES} granite)
endif ()

if (ENABLE_PLUGINS)
    set (VALA_PACKAGES ${VALA_PACKAGES} libpeas-1.0 libpeas-gtk-1.0)
else ()
    set (VALAC_OPTIONS ${VALAC_OPTIONS} -D NO_PLUGINS)
endif ()

# files we want to compile
include (ValaPrecompile)
vala_precompile (VALA_C ${LIBNAME}
    Constants.vala
    Date.vala
    Utils.vala
    ListIdentifier.vala
    TodoListInfo.vala
    Schedule.vala
    TodoTask.vala
    TaskList.vala
    SequentialList.vala
    PluginInterface.vala
    Services/SettingsManager.vala
    Services/PluginManager.vala
    Services/ListManager.vala
    Services/FileWatcher.vala
    Services/TaskTimer.vala
    Services/Shortcuts.vala
    Services/ActivityLog.vala
    Services/SoundPlayer.vala
    Services/Notifications.vala
    Widgets/TodoListInfoRow.vala
    Widgets/DragListModel.vala
    Widgets/DragListRowBox.vala
    Widgets/DragList.vala
    Widgets/ViewSwitcher.vala
    Widgets/TimerScheduleWidget.vala
    Widgets/TimerView.vala
    Widgets/FileChooserWidget.vala
    Pages/TaskListPage.vala
    Pages/SelectionPage.vala
    Dialogs/FileConflictDialog.vala
    Dialogs/DialogUtils.vala
    Dialogs/SettingsDialog.vala
    Dialogs/SettingsPages/AppearancePage.vala
    Dialogs/SettingsPages/BehaviorPage.vala
    Dialogs/SettingsPages/NotificationsPage.vala
    Dialogs/SettingsPages/ShortcutsPage.vala
    Dialogs/AboutDialog.vala
    Dialogs/ContributeDialog.vala

    Recurrence/RecurrenceFrequency.vala
    Recurrence/RecurrenceMode.vala
    Recurrence/RecurrenceRule.vala
    Recurrence/RecurrenceIterator.vala

    Todo.txt/Constants.vala
    Todo.txt/TxtTask.vala
    Todo.txt/TxtUtils.vala
    Todo.txt/TaskStore.vala
    Todo.txt/TaskManager.vala
    Todo.txt/ListSettings.vala
    Todo.txt/Filter.vala
    Todo.txt/TxtList.vala
    Todo.txt/TxtListManager.vala
    Todo.txt/Widgets/TaskListWidget.vala
    Todo.txt/Widgets/TaskRow.vala
    Todo.txt/Widgets/DynOrientationBox.vala
    Todo.txt/Dialogs/TxtListEditDialog.vala

    MainWindow.vala
    Main.vala

# tell what libraries to use when compiling
PACKAGES
    ${VALA_PACKAGES}
OPTIONS
    ${VALAC_OPTIONS}
GENERATE_VAPI
    ${LIBNAME}
GENERATE_HEADER
    ${LIBNAME}
GENERATE_INTERNAL_VAPI
    ${LIBNAME}_internal
GENERATE_INTERNAL_HEADER
    ${LIBNAME}_internal
)

set (LIBS ${DEPS_LIBRARIES} -lm)
set (LIB_PATHS ${DEPS_LIBRARY_DIRS})
link_directories (${LIB_PATHS})

set (LIB_FILES ${C_SOURCES} ${VALA_C})

add_library (${LIBNAME} SHARED
    ${LIB_FILES}
)

set_target_properties (${LIBNAME} PROPERTIES
    VERSION ${LIBVERSION}.0
    SOVERSION ${SOVERSION})

target_link_libraries (${LIBNAME} ${LIBS})

install (TARGETS ${LIBNAME} DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR})

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${LIBNAME}.pc DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${LIBNAME}.h DESTINATION ${CMAKE_INSTALL_FULL_INCLUDEDIR}/${PACKAGE_NAME}/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${LIBNAME}.vapi DESTINATION ${CMAKE_INSTALL_FULL_DATAROOTDIR}/vala/vapi/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/go-for-it.deps DESTINATION ${CMAKE_INSTALL_FULL_DATAROOTDIR}/vala/vapi/ RENAME ${LIBNAME}.deps)
