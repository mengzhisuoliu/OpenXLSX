#=======================================================================================================================
# Preamble
#=======================================================================================================================
cmake_minimum_required(VERSION 3.15 FATAL_ERROR)
set(OPENXLSX_MAJOR_VERSION 0)
set(OPENXLSX_MINOR_VERSION 4)
set(OPENXLSX_MICRO_VERSION 2)
project(OpenXLSX VERSION 0.4.2 LANGUAGES CXX)

set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN YES)

#=======================================================================================================================
# Set C/C++ compiler version
#=======================================================================================================================
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(IGNORE_ME ${CMAKE_C_COMPILER}) # Suppress CMake warning message

# ============================================================================
# Policy Settings
# ============================================================================
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW) # Respect BUILD_SHARED_LIBS / suppress warning in nowide - TBD if this is unproblematic

#=======================================================================================================================
# Build options
#=======================================================================================================================
# 2026-02-23 working configurations:
# - static library build (BUILD_SHARED_LIBS OFF)
# - either setting for OPENXLSX_LOCAL_PACKAGES_ONLY (OFF = automatically fetch dependencies, ON = error out if dependency is not available locally)
#
# 2026-02-23 remaining issues:
# - shared libraries with FETCH_DEPS_AUTO: target pugixml::shared is not available
# - shared libraries with FORCE_FETCH_ALL: linker errors when compiling the demos
# - manage_dependency shall handle different targets for local and remote library version
# -  PREFER_STATIC currently not working
option(OPENXLSX_CREATE_DOCS           "Build library documentation (requires Doxygen and Graphviz/Dot to be installed)" ON)
option(OPENXLSX_BUILD_SAMPLES         "Build sample programs" ON)
option(OPENXLSX_BUILD_TESTS           "Build and run library tests" OFF) # TBD: are these still functional?
option(OPENXLSX_BUILD_BENCHMARKS      "Build and run library benchmarks" OFF)
option(OPENXLSX_ENABLE_LIBZIP         "Enable using libzip" OFF) # when OFF, default zip library is miniz
option(OPENXLSX_FORCE_NOWIDE          "Force use of boost nowide, even on non-Windows systems (testing)" OFF)
option(OPENXLSX_ENABLE_LIBZIP_EXAMPLE "Build Demo1A example using libzip - requires libbz2-dev" OFF)
option(         BUILD_SHARED_LIBS     "Builds the shared library" OFF) # cmake option reserved for that purpose
option(OPENXLSX_BUNDLED_STATIC_LIB    "(static library only) Link library dependencies into a bundled OpenXLSX library file" OFF)
option(OPENXLSX_COMPACT_MODE          "Build library in compact mode (slower, but uses less memory)" OFF)
option(OPENXLSX_LOCAL_PACKAGES_ONLY   "only use dependencies already installed on the host OS, otherwise fail" OFF)

#=======================================================================================================================
# Include CPM package manager
#=======================================================================================================================
# include(${CMAKE_CURRENT_LIST_DIR}/cmake/CPM.cmake)

#=======================================================================================================================
# Options for tool manage_dependency
#=======================================================================================================================
# actual options are replaced with below variables, controlled by OpenXLSX options
# # option(         BUILD_SHARED_LIBS     "Builds the shared library" OFF) # already defined above for OpenXLSX
# option(PREFER_STATIC "Prefer static linking over shared libraries" OFF)
# option(USE_SYSTEM_LIBS "Use system-installed libraries when available" OFF)
# option(FETCH_DEPS_AUTO "Automatically fetch missing dependencies" OFF)
# option(FORCE_FETCH_ALL "Ignore system libraries and fetch all deps" OFF)
#                          # Default: all off
set(PREFER_STATIC OFF)     # Prefer static linking over shared libraries
set(USE_SYSTEM_LIBS OFF)   # Use system-installed libraries when available
set(FETCH_DEPS_AUTO OFF)   # Automatically fetch missing dependencies
#                          # NOTE: with default settings, FETCH_DEPS_AUTO will get enabled because USE_SYSTEM_LIBS is OFF
set(FORCE_FETCH_ALL OFF)   # Ignore system libraries and fetch all deps

#=======================================================================================================================
# Manage configurations
#=======================================================================================================================
if(${OPENXLSX_BUNDLED_STATIC_LIB})
    set(PREFER_STATIC ON) # TODO: test / debug manage_dependency behavior for PREFER_STATIC
endif()
if(${OPENXLSX_LOCAL_PACKAGES_ONLY})
    set(USE_SYSTEM_LIBS ON)
    set(FETCH_DEPS_AUTO OFF)
    set(FORCE_FETCH_ALL OFF)
else()
    set(USE_SYSTEM_LIBS ON)
    set(FETCH_DEPS_AUTO ON)
    set(FORCE_FETCH_ALL OFF)
endif()
# test FORCE_FETCH_ALL BEGIN
# # set(FORCE_FETCH_ALL ON)
# test FORCE_FETCH_ALL END

# TODO: manage_dependency LOCAL_TARGET_NAME vs TARGET_NAME
if(${OPENXLSX_LOCAL_PACKAGES_ONLY}) # TODO: make manage_dependency handle the different alias as LOCAL_TARGET_NAME
    set(NOWIDE_ALIAS Boost::nowide)
    set(NOWIDE_INSTALL_TARGET "")

    # if(${BUILD_SHARED_LIBS})
        set(PUGIXML_TARGET pugixml) # for local packages, pugixml::shared does not seem to be defined. Just pugixml seems to always work
    # else()
        # set(PUGIXML_TARGET pugixml::static)
    # endif()
    set(PUGIXML_STATIC_LIBRARY "pugixml") # TBD how to handle this one
    set(PUGIXML_INSTALL_TARGET "")                 # needed for manage_dependency
else()
    set(NOWIDE_ALIAS nowide::nowide)
    set(NOWIDE_INSTALL_TARGET "nowide")
    set(NOWIDE_INSTALL OFF)

    if(${BUILD_SHARED_LIBS})
        set(PUGIXML_TARGET pugixml::shared) # actually, just pugixml seems to work fine for a target - but let's be explicit
    else()
        set(PUGIXML_TARGET pugixml::static) # see above
    endif()
    set(PUGIXML_STATIC_LIBRARY "pugixml-static")
    set(PUGIXML_INSTALL_TARGET "")                 # needed for manage_dependency
endif()

#  NOTE: when building an executable against the *shared object* OpenXLSX library, /usr/local/lib will not be in the (ldconfig) default libraries search path
#        and needs to be configured, e.g. by LD_LIBRARY_PATH=/usr/local/lib ./a.out
if(${OPENXLSX_BUNDLED_STATIC_LIB} AND ${BUILD_SHARED_LIBS})
    message( FATAL_ERROR "Can not use option OPENXLSX_BUNDLED_STATIC_LIB with shared library" )
endif()

if(${OPENXLSX_BUNDLED_STATIC_LIB} AND ${OPENXLSX_LOCAL_PACKAGES_ONLY})
    message( WARNING "option OPENXLSX_BUNDLED_STATIC_LIB with OPENXLSX_LOCAL_PACKAGES_ONLY may fail when locally a installed dependency is not available as a static library" )
endif()

if(${OPENXLSX_LOCAL_PACKAGES_ONLY} AND NOT ${OPENXLSX_ENABLE_LIBZIP})
    message( WARNING "option OPENXLSX_LOCAL_PACKAGES_ONLY without option OPENXLSX_ENABLE_LIBZIP may fail unless libminiz is preinstalled on the system" )
endif()

if(${OPENXLSX_BUNDLED_STATIC_LIB})
    message( NOTICE "NOTE: bundled static library libOpenXLSX-bundled.a will NOT be installed to the target system by this build configuration" )
endif()


#=======================================================================================================================
# Include tool to manage dependencies
#=======================================================================================================================
include(${CMAKE_CURRENT_LIST_DIR}/cmake/manage-dependency.cmake)

#=======================================================================================================================
# Include tool to get git commit metadata
#=======================================================================================================================
include(${CMAKE_CURRENT_LIST_DIR}/cmake/get-git-HEAD-ID.cmake)

#=======================================================================================================================
# Output Directories.
#=======================================================================================================================
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/output)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/output)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/output)

#=======================================================================================================================
# Add project configurations (#ifdef / #ifndef testable)
#=======================================================================================================================
if(WIN32 OR ${OPENXLSX_FORCE_NOWIDE})
    set(OPENXLSX_ENABLE_NOWIDE ON)
endif()

if(OPENXLSX_ENABLE_NOWIDE)
    manage_dependency(
        LIB_NAME        Nowide
        PACKAGE_NAME    Boost
        COMPONENTS      nowide
        TARGET_NAME     ${NOWIDE_ALIAS}
        GIT_REPOSITORY  https://codeberg.org/lars_uffmann/nowide_standalone.git
        GIT_TAG         v11.3.1-fixed
        # GITHUB_REPO  boostorg/nowide
        # GIT_TAG   1.73.0
        #
        # OPTIONS currently not supported by manage_dependency
        # OPTIONS
        #     "NOWIDE_INSTALL OFF"
    )
endif()

if (OPENXLSX_ENABLE_LIBZIP)
    # NOTE: libzip 1.11.4 is the newest version as of 2025-08-16 and not available on most host systems, so a lower version tag should be used.
    #        However, 1.11.4 is the first version that allows building libzip separately from the (unneeded) components zipcmp zipmerge ziptool
    #        Maybe check for available version & if 1.11.4 is available, exclude unneeded components - or does this happen automatically?
# message( NOTICE     "LibZip_FOUND: ${LibZip_FOUND}" )
#     find_package(LibZip 1.11.3 # was 1.7
#         CONFIG
#         COMPONENTS zip
#         QUIET OPTIONAL_COMPONENTS zipcmp zipmerge ziptool # requires the following tools to be installed: zipcmp zipmerge ziptool
#     )
# message( NOTICE     "LibZip_FOUND: ${LibZip_FOUND}" )

    set(ZIP_LIBRARY libzip) # to be identified as dependency in package config
    # CPMFindPackage(
    #         NAME libzip
    #         GITHUB_REPOSITORY nih-at/libzip
    #         GIT_TAG v1.11.4
    #         OPTIONS "COMPONENTS zip"                                    # only relevant for find_package (i.e. OPENXLSX_LOCAL_PACKAGES_ONLY=ON)
    #         OPTIONS "QUIET OPTIONAL_COMPONENTS zipcmp zipmerge ziptool" # "
    #         OPTIONS "BUILD_TOOLS OFF"                                   # only relevant for CPMFindPackage (i.e. OPENXLSX_LOCAL_PACKAGES_ONLY=OFF)
    #         OPTIONS "BUILD_REGRESS OFF"                                 # "
    #         OPTIONS "BUILD_OSSFUZZ OFF"                                 # "
    #         OPTIONS "BUILD_EXAMPLES OFF"                                # "
    #         OPTIONS "BUILD_DOC OFF"                                     # "
    # )
    manage_dependency(
        LIB_NAME     libzip
        PACKAGE_NAME LibZip
        TARGET_NAME  libzip::zip
        GITHUB_REPO  nih-at/libzip
        GIT_TAG      v1.11.3
        VERSION      1.11.3
        COMPONENTS   zip
            # OPTIONS "COMPONENTS zip"                                    # only relevant for find_package (i.e. OPENXLSX_LOCAL_PACKAGES_ONLY=ON)
            # OPTIONS "QUIET OPTIONAL_COMPONENTS zipcmp zipmerge ziptool" # "
            OPTIONS "BUILD_TOOLS OFF"                                   # only relevant for CPMFindPackage (i.e. OPENXLSX_LOCAL_PACKAGES_ONLY=OFF)
            OPTIONS "BUILD_REGRESS OFF"                                 # "
            OPTIONS "BUILD_OSSFUZZ OFF"                                 # "
            OPTIONS "BUILD_EXAMPLES OFF"                                # "
            OPTIONS "BUILD_DOC OFF"                                     # "
    )

    set(ZIP_LIBRARY_INSTALL_TARGET libzip)
else()
    if(WIN32)
        set(OPENXLSX_MINIZ_BUILD_MODE "OFF") # for miniz on windows, the shared library fails to build - so build the shared OpenXLSX library against the static miniz lib in that case
    else()
        set(OPENXLSX_MINIZ_BUILD_MODE "${BUILD_SHARED_LIBS}")
    endif()

    # CPMFindPackage(
    #         NAME miniz
    #         GITHUB_REPOSITORY richgel999/miniz
    #         GIT_TAG 3.0.2
    #         OPTIONS "BUILD_SHARED_LIBS ${OPENXLSX_MINIZ_BUILD_MODE}"
    # )
    manage_dependency(
        LIB_NAME     miniz
        PACKAGE_NAME miniz
        TARGET_NAME  miniz
        GITHUB_REPO  richgel999/miniz
        GIT_TAG      3.0.2
    )

    set(ZIP_LIBRARY miniz) # to be identified as dependency in package config
    set(ZIP_LIBRARY_INSTALL_TARGET miniz)
endif ()

# CPMFindPackage(
#         NAME pugixml
#         GITHUB_REPOSITORY zeux/pugixml
#         GIT_TAG v1.15
#         OPTIONS
#         "PUGIXML_COMPACT ${OPENXLSX_COMPACT_MODE}"
#         # use of reserved BUILD_SHARED_LIBS automatically passes this option through
# )
manage_dependency(
    LIB_NAME     pugixml
    PACKAGE_NAME pugixml
    TARGET_NAME  ${PUGIXML_TARGET}
    GITHUB_REPO  zeux/pugixml
    GIT_TAG      v1.15
    OPTIONS "PUGIXML_COMPACT ${OPENXLSX_COMPACT_MODE}"
)


#=======================================================================================================================
# Add project subdirectories
#=======================================================================================================================
add_subdirectory(OpenXLSX)

if(${OPENXLSX_CREATE_DOCS})
    add_subdirectory(Documentation)
endif()

if(${OPENXLSX_BUILD_SAMPLES})
    add_subdirectory(Examples)
endif()

if(${OPENXLSX_BUILD_TESTS})
    add_subdirectory(Tests)
endif()

if(${OPENXLSX_BUILD_BENCHMARKS})
    add_subdirectory(Benchmarks)
endif()


#=======================================================================================================================
# Summarize OpenXLSX configuration
#=======================================================================================================================
message(     NOTICE     "-- OpenXLSX configuration:" )
message(     NOTICE     "   ++ git HEAD (short):                      ${GIT_COMMIT_ID}" )
message(     NOTICE     "   ++ git HEAD commit timestamp:             ${GIT_COMMIT_ID_TIME}" )
message(     NOTICE     "   ++ Build library documentation:           ${OPENXLSX_CREATE_DOCS}" )
message(     NOTICE     "   ++ Build sample programs:                 ${OPENXLSX_BUILD_SAMPLES}" )
message(     NOTICE     "   ++ Build and run library tests:           ${OPENXLSX_BUILD_TESTS}" )
message(     NOTICE     "   ++ Build and run library benchmarks:      ${OPENXLSX_BUILD_BENCHMARKS}" )
message(     NOTICE     "   ++ Enable using libzip:                   ${OPENXLSX_ENABLE_LIBZIP}" )
message(     NOTICE     "   ++ Force use of boost nowide:             ${OPENXLSX_FORCE_NOWIDE}" )
message(     NOTICE     "   ++ Build Demo1A example using libzip:     ${OPENXLSX_ENABLE_LIBZIP_EXAMPLE}" )
if(OPENXLSX_ENABLE_LIBZIP_EXAMPLE AND NOT OPENXLSX_BUILD_SAMPLES)
    message( WARNING    "Demo1A will not be built because sample programs are disabled!" )
endif()
    message( NOTICE     "   ++ Build the shared library:              ${BUILD_SHARED_LIBS}" )
    message( NOTICE     "   ++ Make a bundled static library file:    ${OPENXLSX_BUNDLED_STATIC_LIB}" )
    message( NOTICE     "   ++ Build library in compact mode:         ${OPENXLSX_COMPACT_MODE}" )
    message( NOTICE     "   ++ Only use installed packages:           ${OPENXLSX_LOCAL_PACKAGES_ONLY}" )
    message( NOTICE     "   ++" )

if(BUILD_SHARED_LIBS)
    message( NOTICE     "   ++ Library type:                          shared" )
else()
    message( NOTICE     "   ++ Library type:                          static" )
endif()

if(OPENXLSX_ENABLE_NOWIDE)
    message( NOTICE     "   ++ Unicode support:                       Boost nowide" )
    if("${Boost_INCLUDE_DIR}" STREQUAL "")
        message( NOTICE "   ++ Boost_INCLUDE_DIR:                     (empty)" )
    else()
        message( NOTICE "   ++ Boost_INCLUDE_DIR:                     ${Boost_INCLUDE_DIR}" )
        # message( NOTICE "   ++ NOWIDE_INCLUDE_DIR:                    ${NOWIDE_INCLUDE_DIR}" )
    endif()
else()
    message( NOTICE     "   ++ Unicode support:                       (OS) native" )
endif()

if (OPENXLSX_ENABLE_LIBZIP)
    message( NOTICE     "   ++ zip library:                           libzip" )
else()
    message( NOTICE     "   ++ zip library:                           miniz" )
endif()

message(     NOTICE     "   manage_dependency configuration:" )
message(     NOTICE     "   ++ PREFER_STATIC:                         ${PREFER_STATIC}" )
message(     NOTICE     "   ++ USE_SYSTEM_LIBS:                       ${USE_SYSTEM_LIBS}" )
message(     NOTICE     "   ++ FETCH_DEPS_AUTO:                       ${FETCH_DEPS_AUTO}" )
message(     NOTICE     "   ++ FORCE_FETCH_ALL:                       ${FORCE_FETCH_ALL}" )

# message( NOTICE         "   TEST1 nowide_SOURCE_DIR:                  ${nowide_SOURCE_DIR}" ) # TBD - can this be fetched?
# message( NOTICE         "   TEST2 nowide_SOURCE_DIR:                  ${Nowide_SOURCE_DIR}" )
# message( NOTICE         "   TEST3 nowide_SOURCE_DIR:                  ${nowide_nowide_SOURCE_DIR}" )
# message( NOTICE         "   TEST4 nowide_SOURCE_DIR:                  ${Boost_nowide_SOURCE_DIR}" )
# NOTE: for some reason, cmake with --log-level VERBOSE (or DEBUG) prefixes message output with "-- "
message( VERBOSE        "   VERBOSE configuration information:" )
# message( VERBOSE        "   ++ pugixml_SOURCE_DIR:                    ${pugixml_SOURCE_DIR}" ) # TBD - can this be fetched?
message( VERBOSE        "   ++ NOWIDE_INSTALL_TARGET:                 ${NOWIDE_INSTALL_TARGET}" )
message( VERBOSE        "   ++ ZIP_LIBRARY_INSTALL_TARGET:            ${ZIP_LIBRARY_INSTALL_TARGET}" )
message( VERBOSE        "   ++ PUGIXML_INSTALL_TARGET:                ${PUGIXML_INSTALL_TARGET}" )


#=======================================================================================================================
# Configure CPack for debian package generation - thank you @ https://github.com/Jacob-Burckhardt for the suggestions
#=======================================================================================================================
configure_file ("${CMAKE_CURRENT_LIST_DIR}/cmake/libopenxlsxCPackOptions.cmake.in"
                "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libopenxlsxCPackOptions.cmake"
                @ONLY)

set (CPACK_PROJECT_CONFIG_FILE
     "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libopenxlsxCPackOptions.cmake")

# must include the CPack project config file here or the settings won't be used
include ("${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libopenxlsxCPackOptions.cmake")

# include( CPack ) must always be invoked after all CPACK\_\* variables are defined
include( CPack )
message(     NOTICE     "   ++ CPACK_PACKAGE_VERSION:                 ${CPACK_PACKAGE_VERSION}" )

message( NOTICE     "   ++ Prefer static linking over shared libraries: ${PREFER_STATIC}" )
message( NOTICE     "   ++ Use system-installed libraries when available: ${USE_SYSTEM_LIBS}" )
message( NOTICE     "   ++ Automatically fetch missing dependencies: ${FETCH_DEPS_AUTO}" )
message( NOTICE     "   ++ Ignore system libraries and fetch all deps: ${FORCE_FETCH_ALL}" )

# TODO: how to trigger cpack -G DEB from cmake
