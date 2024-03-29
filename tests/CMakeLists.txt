set (TEST_EXEC_NAME ${APP_ID}-tests)

# files we want to compile
include (ValaPrecompile)
vala_precompile (VALA_C ${TEST_EXEC_NAME}
    TestCase.vala
    DragListTest.vala
    Tests.vala
    todo.txt/TodoTaskTest.vala
    todo.txt/TaskStoreTest.vala
    todo.txt/TaskManagerTest.vala

# tell what libraries to use when compiling
PACKAGES
    ${DEPS_VALA_PACKAGES}
OPTIONS
    ${VALAC_OPTIONS}
CUSTOM_VAPIS
    ${CMAKE_BINARY_DIR}/${LIBRARY_PATH}/${LIBNAME}_internal.vapi
CUSTOM_VAPIS
    ${CUSTOM_VAPIS}
)

# tell cmake what to call the executable we just made
add_executable (${TEST_EXEC_NAME} ${VALA_C})
add_dependencies (${TEST_EXEC_NAME} ${LIBNAME})
target_link_libraries (${TEST_EXEC_NAME} ${DEPS_LIBRARIES} ${LIBNAME})

set_target_properties (${TEST_EXEC_NAME} PROPERTIES
    INCLUDE_DIRECTORIES ${CMAKE_BINARY_DIR}/${LIBRARY_PATH}
)
