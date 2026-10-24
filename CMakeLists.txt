cmake_minimum_required(VERSION 3.24)

set(cwhip_sdk_prefix "$ENV{CWHIP_SDK}")
if(cwhip_sdk_prefix STREQUAL "")
    set(cwhip_config_home "$ENV{XDG_CONFIG_HOME}")
    if(cwhip_config_home STREQUAL "" AND NOT "$ENV{HOME}" STREQUAL "")
        set(cwhip_config_home "$ENV{HOME}/.config")
    endif()
    if(NOT cwhip_config_home STREQUAL "")
        if(NOT IS_ABSOLUTE "${cwhip_config_home}")
            message(FATAL_ERROR
                "Cannot discover sdk_prefix: config home '${cwhip_config_home}' is not absolute")
        endif()
        cmake_path(APPEND cwhip_config_home "cwhip"
            OUTPUT_VARIABLE cwhip_settings_directory)
        cmake_path(NORMAL_PATH cwhip_settings_directory)
        # EXISTS checks readability; listing lets the parser diagnose unreadable files.
        file(GLOB cwhip_settings_entries "${cwhip_settings_directory}/*")
        set(cwhip_settings "${cwhip_settings_directory}/sdk.toml")
        if(NOT "${cwhip_settings}" IN_LIST cwhip_settings_entries)
            set(cwhip_settings "${cwhip_settings_directory}/settings.toml")
        endif()
        if("${cwhip_settings}" IN_LIST cwhip_settings_entries)
            find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)
            execute_process(
                COMMAND "${Python3_EXECUTABLE}"
                    "${CMAKE_CURRENT_SOURCE_DIR}/scripts/sdk-prefix.py" "${cwhip_settings}"
                RESULT_VARIABLE cwhip_settings_result
                OUTPUT_VARIABLE cwhip_sdk_prefix
                ERROR_VARIABLE cwhip_settings_error)
            if(NOT cwhip_settings_result STREQUAL "0")
                message(FATAL_ERROR "${cwhip_settings_error}")
            endif()
        endif()
    endif()
endif()

if(NOT cwhip_sdk_prefix STREQUAL "")
    message(STATUS "Using Cwhip SDK prefix: ${cwhip_sdk_prefix}")
    unset(Cwhip_DIR CACHE)
    unset(Cwhip_DIR)
    find_package(Cwhip 0.0.2 EXACT CONFIG REQUIRED
        PATHS "${cwhip_sdk_prefix}" NO_DEFAULT_PATH)
else()
    find_package(Cwhip 0.0.2 EXACT CONFIG REQUIRED)
endif()

if(NOT Cwhip_SDK_ABI STREQUAL "numeric-v2")
    message(FATAL_ERROR
        "CVM requires the Cwhip numeric-v2 SDK ABI; selected SDK reports "
        "'${Cwhip_SDK_ABI}'. Rebuild CVM's Cwhip dependencies with chucktilbury/cwhip#25.")
endif()
if(NOT EXISTS "${Cwhip_INCLUDE_DIR}/cwhip/Stdlib.h")
    message(FATAL_ERROR
        "Selected Cwhip SDK is missing ${Cwhip_INCLUDE_DIR}/cwhip/Stdlib.h")
endif()
file(READ "${Cwhip_INCLUDE_DIR}/cwhip/Stdlib.h" cwhip_sdk_header)
if(NOT cwhip_sdk_header MATCHES "#define CWHIP_SDK_ABI \"numeric-v2\"")
    message(FATAL_ERROR
        "CVM requires CWHIP_SDK_ABI \"numeric-v2\" in the selected SDK's Stdlib.h")
endif()

cwhip_apply_application_defaults()

project(cvm LANGUAGES C)
include(CTest)

set(CWHIP_BIN_DIR "${PROJECT_SOURCE_DIR}/bin" CACHE PATH
    "Directory for project executables")
set(CWHIP_LIB_DIR "${PROJECT_SOURCE_DIR}/lib" CACHE PATH
    "Directory for project libraries and archives")
get_filename_component(CWHIP_BIN_DIR "${CWHIP_BIN_DIR}" ABSOLUTE
    BASE_DIR "${PROJECT_SOURCE_DIR}")
get_filename_component(CWHIP_LIB_DIR "${CWHIP_LIB_DIR}" ABSOLUTE
    BASE_DIR "${PROJECT_SOURCE_DIR}")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CWHIP_LIB_DIR}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CWHIP_LIB_DIR}")
foreach(configuration DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${configuration} "${CWHIP_BIN_DIR}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${configuration} "${CWHIP_LIB_DIR}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${configuration} "${CWHIP_LIB_DIR}")
endforeach()

if(NOT Cwhip_APPLICATION_OUTPUT_DIRECTORIES)
    message(FATAL_ERROR
        "The selected Cwhip SDK does not support configurable application output directories. "
        "Install an SDK that provides Cwhip_APPLICATION_OUTPUT_DIRECTORIES.")
endif()

cwhip_add_program(hello
    SOURCE "${PROJECT_SOURCE_DIR}/src/main.cw"
    OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}")
get_target_property(hello_executable hello CWHIP_EXECUTABLE)
install(PROGRAMS "${hello_executable}" DESTINATION bin)
install(DIRECTORY "${PROJECT_SOURCE_DIR}/modules/cvm/"
    DESTINATION share/cwhip/modules/cvm)
install(DIRECTORY "${PROJECT_SOURCE_DIR}/modules/cvmfile/"
    DESTINATION share/cwhip/modules/cvmfile)
install(DIRECTORY "${PROJECT_SOURCE_DIR}/modules/cvmrun/"
    DESTINATION share/cwhip/modules/cvmrun)

find_program(CPARSEGEN_EXECUTABLE NAMES cparsegen
    DOC "Installed cparsegen executable supporting --library")
if(NOT CPARSEGEN_EXECUTABLE OR NOT EXISTS "${CPARSEGEN_EXECUTABLE}")
    message(FATAL_ERROR
        "CVM assembler requires installed cparsegen. Put it on PATH or set "
        "-DCPARSEGEN_EXECUTABLE=/absolute/path/to/cparsegen (build-time only).")
endif()
set(cvm_system_source "${Cwhip_MODULE_DIR}/system/0.1.0/system.cw")
if(NOT EXISTS "${cvm_system_source}")
    message(FATAL_ERROR "CVM assembler requires public SDK system/0.1.0 with binary File APIs")
endif()
file(READ "${cvm_system_source}" cvm_system_api)
foreach(method "buffer readBytes\\(int64 size\\)" "buffer readAllBytes\\(\\)" "int64 writeBytes\\(buffer data\\)")
    if(NOT cvm_system_api MATCHES "${method}")
        message(FATAL_ERROR
            "Selected SDK lacks public File binary APIs (Cwhip PR #20 or newer required)")
    endif()
endforeach()

set(assembler_work "${PROJECT_BINARY_DIR}/assembler")
set(assembler_binary "${CWHIP_BIN_DIR}/cvm-as")
get_filename_component(assembler_runtime_directory "${Cwhip_RUNTIME_LIBRARY}" DIRECTORY)
file(MAKE_DIRECTORY "${assembler_work}" "${assembler_work}/home"
    "${assembler_work}/config" "${assembler_work}/data"
    "${assembler_work}/cache" "${assembler_work}/state")
file(GLOB assembler_sources CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/src/assembler/*.cw")
file(GLOB_RECURSE cvm_modules CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/modules/*")
set(assembler_sdk_inputs)
foreach(sdk_directory IN ITEMS "${Cwhip_MODULE_DIR}" "${Cwhip_BUILTIN_DIR}" "${Cwhip_INCLUDE_DIR}")
    if(NOT sdk_directory STREQUAL "")
        file(GLOB_RECURSE sdk_inputs CONFIGURE_DEPENDS "${sdk_directory}/*")
        list(APPEND assembler_sdk_inputs ${sdk_inputs})
    endif()
endforeach()
add_custom_command(OUTPUT "${assembler_work}/parser.cw"
    COMMAND "${CMAKE_COMMAND}" -E rm -f "${assembler_work}/parser.cw"
    COMMAND "${CPARSEGEN_EXECUTABLE}" --library
        "${PROJECT_SOURCE_DIR}/grammar/assembly.cpg" "${assembler_work}/parser.cw"
    COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/scripts/migrate-generated-parser.py"
        "${assembler_work}/parser.cw"
    DEPENDS "${PROJECT_SOURCE_DIR}/grammar/assembly.cpg" "${CPARSEGEN_EXECUTABLE}"
        "${PROJECT_SOURCE_DIR}/scripts/migrate-generated-parser.py"
    VERBATIM)
add_custom_command(OUTPUT "${assembler_binary}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${CWHIP_BIN_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${assembler_sources} "${assembler_work}"
    COMMAND "${CMAKE_COMMAND}" -E env
        --unset=CWHIP_MODULE_DIR --unset=CWHIP_PACKAGE_PATH --unset=CWHIP_MODULE_REGISTRY
        --unset=DESTDIR --unset=XDG_RUNTIME_DIR
        "HOME=${assembler_work}/home" "XDG_CONFIG_HOME=${assembler_work}/config"
        "XDG_DATA_HOME=${assembler_work}/data" "XDG_CACHE_HOME=${assembler_work}/cache"
        "XDG_STATE_HOME=${assembler_work}/state" "CWHIP_HOME=${Cwhip_PREFIX}"
        "CWHIP_SDK=${Cwhip_PREFIX}" "CWHIP_INCLUDE_DIR=${Cwhip_INCLUDE_DIR}"
        "CWHIP_RUNTIME_DIR=${assembler_runtime_directory}"
        "CWHIP_BUILTIN_DIR=${Cwhip_BUILTIN_DIR}"
        "CWHIP_STDLIB_MODULE_DIR=${Cwhip_MODULE_DIR}" "CC=${Cwhip_CLANG_EXECUTABLE}"
        "${Cwhip_COMPILER}" "${assembler_work}/assembler.cw"
        -M "${PROJECT_SOURCE_DIR}/modules" -o "${assembler_binary}"
    DEPENDS ${assembler_sources} ${cvm_modules} ${assembler_sdk_inputs}
        "${assembler_work}/parser.cw" "${Cwhip_COMPILER}" "${Cwhip_RUNTIME_LIBRARY}"
    WORKING_DIRECTORY "${assembler_work}"
    COMMAND_EXPAND_LISTS VERBATIM)
add_custom_target(cvm-as ALL DEPENDS "${assembler_binary}")
install(PROGRAMS "${assembler_binary}" DESTINATION bin)

set(runner_work "${PROJECT_BINARY_DIR}/runner")
set(runner_binary "${CWHIP_BIN_DIR}/cvm-run")
file(MAKE_DIRECTORY "${runner_work}" "${runner_work}/home"
    "${runner_work}/config" "${runner_work}/data"
    "${runner_work}/cache" "${runner_work}/state")
file(GLOB_RECURSE runner_modules CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/modules/*")
add_custom_command(OUTPUT "${runner_binary}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${CWHIP_BIN_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E env
        --unset=CWHIP_MODULE_DIR --unset=CWHIP_PACKAGE_PATH --unset=CWHIP_MODULE_REGISTRY
        --unset=DESTDIR --unset=XDG_RUNTIME_DIR
        "HOME=${runner_work}/home" "XDG_CONFIG_HOME=${runner_work}/config"
        "XDG_DATA_HOME=${runner_work}/data" "XDG_CACHE_HOME=${runner_work}/cache"
        "XDG_STATE_HOME=${runner_work}/state" "CWHIP_HOME=${Cwhip_PREFIX}"
        "CWHIP_SDK=${Cwhip_PREFIX}" "CWHIP_INCLUDE_DIR=${Cwhip_INCLUDE_DIR}"
        "CWHIP_RUNTIME_DIR=${assembler_runtime_directory}"
        "CWHIP_BUILTIN_DIR=${Cwhip_BUILTIN_DIR}"
        "CWHIP_STDLIB_MODULE_DIR=${Cwhip_MODULE_DIR}" "CC=${Cwhip_CLANG_EXECUTABLE}"
        "${Cwhip_COMPILER}" "${PROJECT_SOURCE_DIR}/src/runner/main.cw"
        -M "${PROJECT_SOURCE_DIR}/modules" -o "${runner_binary}"
    DEPENDS "${PROJECT_SOURCE_DIR}/src/runner/main.cw" ${runner_modules}
        ${assembler_sdk_inputs} "${Cwhip_COMPILER}" "${Cwhip_RUNTIME_LIBRARY}"
    WORKING_DIRECTORY "${runner_work}"
    VERBATIM)
add_custom_target(cvm-run ALL DEPENDS "${runner_binary}")
install(PROGRAMS "${runner_binary}" DESTINATION bin)

if(BUILD_TESTING)
    find_program(Python3_EXECUTABLE NAMES python3 REQUIRED)
    add_test(NAME cvm_installed_library
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tests/test_cvm_library.py")
    set_tests_properties(cvm_installed_library PROPERTIES
        ENVIRONMENT "CWHIP_SDK=${Cwhip_PREFIX};CVM_BUILD_DIR=${PROJECT_BINARY_DIR}")
    add_test(NAME cvm_assembler
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tests/test_assembler.py")
    set_tests_properties(cvm_assembler PROPERTIES
        ENVIRONMENT "CWHIP_SDK=${Cwhip_PREFIX};CVM_BUILD_DIR=${PROJECT_BINARY_DIR}")
    add_test(NAME cvm_interpreter
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tests/test_runner.py")
    set_tests_properties(cvm_interpreter PROPERTIES
        ENVIRONMENT "CWHIP_SDK=${Cwhip_PREFIX};CVM_BUILD_DIR=${PROJECT_BINARY_DIR}")
endif()
