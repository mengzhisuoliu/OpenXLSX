# ============================================================================
# Author
# ============================================================================
# The function manage_dependency is a friendly contribution by NLATP (openxlsx.genetics016@passinbox.com)
# The rest of the module is written by Lars Uffmann (coding23@uffmann.name) in an attempt to better understand CMake platform independency
#  (yes, this is still giving me headaches)

# ============================================================================
# Policy Settings - to be controlled by the main project file
# ============================================================================
# set(CMAKE_POLICY_DEFAULT_CMP0077 NEW) # Respect BUILD_SHARED_LIBS / suppress warning in nowide - TBD if this is unproblematic
# if(POLICY CMP0077)
#     cmake_policy(SET CMP0077 NEW)  # Respect BUILD_SHARED_LIBS
# endif()
#
# set(CMAKE_POLICY_DEFAULT_CMP0167 NEW)
# if(POLICY CMP0167)
#     cmake_policy(SET CMP0167 NEW) # find the upstream BoostConfig.cmake directly
# endif()

# ============================================================================
# Configuration Options, to be configured in caller CMakeLists.txt
# ============================================================================
# option(PREFER_STATIC "Prefer static linking over shared libraries" ON)
# option(USE_SYSTEM_LIBS "Use system-installed libraries when available" ON)
# option(FETCH_DEPS_AUTO "Automatically fetch missing dependencies" ON)
# option(FORCE_FETCH_ALL "Ignore system libraries and fetch all deps" OFF)

# ============================================================================
# Safety Checks - to be handled in main project file
# ============================================================================
# if(FORCE_FETCH_ALL)
#     set(USE_SYSTEM_LIBS OFF CACHE BOOL "" FORCE)
#     message(STATUS "FORCE_FETCH_ALL enabled: ignoring system libraries")
# endif()


# ============================================================================
# Enhanced Helper Functions
# ============================================================================

# Function:   FetchContent_Declare_custom
# Purpose:    Provide an alternative to FetchContent_Declare with the option to EXCLUDE_FROM_ALL
# Options:
#   EXCLUDE_FROM_ALL  if supported, pass EXCLUDE_FROM_ALL on to FetchContent_Declare
# Parameters:
#   LIB_NAME          name of the library to make available, as to be passed to FetchContent_Declare
#   URL               if provided together with a hash, declare content for fetching from URL
#   URL_HASH          must be provided with URL or URL won't be used
#   GIT_REPOSITORY    if URL or URL_HASH are missing: declare content for fetching from this repository
#   GIT_TAG           must be provided with GIT_REPOSITORY
# Author:     Lars Uffmann (coding23@uffmann.name)
function(FetchContent_Declare_custom)
    set(options "EXCLUDE_FROM_ALL")
    set(oneValueArgs
        LIB_NAME
        URL
        URL_HASH
        GIT_REPOSITORY
        GIT_TAG
    )
    set(multiValueArgs EXTRA_ARGS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # empty initializers for all parameters to FetchContent_Declare
    set( URL_PARAM )
    set( URL_HASH_PARAM )
    set( URL_EXTRA_PARAMS )
    set( GIT_REPO_PARAM )
    set( GIT_TAG_PARAM )
    set( GIT_EXTRA_PARAMS )
    set( SHARED_PARAMS )

    # initialize source parameters
    if( ( "${ARG_URL}" STREQUAL "" ) OR ( "${ARG_URL_HASH}" STREQUAL "" ) )
        message( NOTICE "Fetching ${ARG_LIB_NAME} from repository ${ARG_GIT_REPOSITORY} with GIT_TAG ${ARG_GIT_TAG}" )

        # set( GIT_REPO_PARAM "GIT_REPOSITORY;${ARG_GIT_REPOSITORY}" )
        # NOTE: separating param name and value with a semicolon (above) is equivalent to list( APPEND [..] ) as seen below
        list( APPEND GIT_REPO_PARAM      GIT_REPOSITORY             ${ARG_GIT_REPOSITORY} )
        list( APPEND GIT_TAG_PARAM       GIT_TAG                    ${ARG_GIT_TAG} )
        list( APPEND GIT_EXTRA_PARAMS    GIT_SHALLOW                TRUE )
    else()
        message( NOTICE "Fetching ${ARG_LIB_NAME} via URL ${ARG_URL}" )

        list( APPEND URL_PARAM           URL                        ${ARG_URL} )
        list( APPEND URL_HASH_PARAM      URL_HASH                   ${ARG_URL_HASH} )
        list( APPEND URL_EXTRA_PARAMS    DOWNLOAD_EXTRACT_TIMESTAMP OFF ) # set extracted file timestamps to current time to ensure extraction triggers compilation
    endif()
    list( APPEND     SHARED_PARAMS       OVERRIDE_FIND_PACKAGE )    # Important: override system package
    if( CMAKE_VERSION VERSION_GREATER_EQUAL "3.30" )
        if( ARG_EXCLUDE_FROM_ALL )
            message( NOTICE "FetchContent_Declare in CMake >= 3.30 will be invoked with EXCLUDE_FROM_ALL" )
            list( APPEND SHARED_PARAMS   EXCLUDE_FROM_ALL )
        endif()
    endif()

    FetchContent_Declare(
        ${ARG_LIB_NAME}
        ${URL_PARAM}
        ${URL_HASH_PARAM}
        ${URL_EXTRA_PARAMS}
        ${GIT_REPO_PARAM}
        ${GIT_TAG_PARAM}
        ${GIT_EXTRA_PARAMS}
        ${SHARED_PARAMS}
    )
endfunction()
# End of Function:   FetchContent_Declare_custom


# Function:   FetchContent_MakeAvailable_custom
# Purpose:    Provide an alternative to FetchContent_MakeAvailable with the option to EXCLUDE_FROM_ALL in case FetchContent_Declare
#              does not support it
# Options:
#   EXCLUDE_FROM_ALL  FetchContent_MakeAvailable (CMake >= 3.30) or add_subdirectory will be executed with EXCLUDE_FROM_ALL
# Parameters:
#   LIB_NAME          name of the library to make available, as previously prepared with FetchContent_Declare
# Author:     Lars Uffmann (coding23@uffmann.name)
function(FetchContent_MakeAvailable_custom)
    set(options "EXCLUDE_FROM_ALL")
    set(oneValueArgs
        LIB_NAME
    )
    set(multiValueArgs EXTRA_ARGS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # empty initializers for all parameters to FetchContent_MakeAvailable or add_subdirectory
    set( EXCLUDE_FROM_ALL_PARAM ) # ignored for CMake >= 3.30

    if( CMAKE_VERSION VERSION_GREATER_EQUAL "3.30" )
        # if CMake version >= 3.30: FetchContent_Declare was invoked with EXCLUDE_FROM_ALL, now use FetchContent_MakeAvailable nominally
        FetchContent_MakeAvailable(
            ${ARG_LIB_NAME}
        )
    else()
        # older versions of CMake: fall back to a combination of FetchContent_Populate and add_subdirectory

        # Logic from comment at  https://stackoverflow.com/questions/65527126/disable-install-for-fetchcontent
        FetchContent_GetProperties(${ARG_LIB_NAME})
        if(NOT ${ARG_LIB_NAME}_POPULATED)
            FetchContent_Populate(${ARG_LIB_NAME})
            string( TOLOWER ${ARG_LIB_NAME} LIB_NAME_LOWER ) # FetchContent_Populate populates variables with ARG_LIB_NAME in all lowercase
            if( ARG_EXCLUDE_FROM_ALL )
                message( NOTICE "-- FetchContent_MakeAvailable_custom (${ARG_LIB_NAME}): add_subdirectory will be used with EXCLUDE_FROM_ALL" )
                list( APPEND EXCLUDE_FROM_ALL_PARAM EXCLUDE_FROM_ALL )  # Ensure that the dependency is not installed if EXCLUDE_FROM_ALL is active
            endif()
            add_subdirectory(
                ${${LIB_NAME_LOWER}_SOURCE_DIR}
                ${${LIB_NAME_LOWER}_BINARY_DIR}
                ${EXCLUDE_FROM_ALL_PARAM}
            )
        endif()
    endif()
endfunction()
# End of Function:   FetchContent_MakeAvailable_custom


# Function: manage_dependency
# Purpose:  Safely finds or fetches a dependency
# Options:  -
# Parameters: (see below)
# Returns:
#   ${LIB_NAME}_FETCHED         (PARENT_SCOPE): TRUE if dependency was downloaded from a repository, FALSE if dependency was provided by find_package
#   ${LIB_NAME}_PROVIDED_TARGET (PARENT_SCOPE): (potentially aliased) target provided by the dependency
#   ${LIB_NAME}_INSTALL_TARGET  (PARENT_SCOPE): (alias resolved) install target to be used for the dependency, if any
# Author:   This function is a friendly contribution by NLATP (openxlsx.genetics016@passinbox.com)
function(manage_dependency)
    set(options "")
    set(oneValueArgs
        LIB_NAME        # an arbitrary library name, for which ${LIB_NAME}_FETCHED will be set to TRUE for the caller in case of success
        PACKAGE_NAME    # the system library package name
        COMPONENTS      #     system library components name(s)
        VERSION         # local required version for find_package with PACKAGE_NAME
        TYPICAL_NAMES   # typical names for the dependency to be used with find_library in determining whether a static library is installed
        #
        GITHUB_REPO     # use for github repositories only
        GIT_REPOSITORY  # use to provide a full repository URL
        GIT_TAG         # use this to supply the github version tag (can be preceeded by a 'v' whereas VERSION is typically(?) numerical only
        HEADER_FILE     # TBD: what is the point of HEADER_FILE?
        URL             # URL & URL_HASH can be used together instead of GITHUB_REPO & GIT_TAG
        URL_HASH        #
        #
        TARGET_NAME  # expected target (can be an alias) that should be provided by the dependency
        TARGET_NAME_SYSTEM  # this is the target that shold be provided when the library is provided by the system
        # NOTE: depending on how the dependency is made available, manage_dependency will set the variable ${LIB_NAME}_PROVIDED_TARGET to
        #        either TARGET_NAME or TARGET_NAME_SYSTEM, so that ${LIB_NAME}_PROVIDED_TARGET can be used as DEPENDENCY_TARGET in target_link_interface
    )
    set(multiValueArgs EXTRA_ARGS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Save global state
    set(SAVED_BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS})
    set(SAVED_CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH})

    # Initialize return values to defaults
    set(${ARG_LIB_NAME}_FETCHED FALSE PARENT_SCOPE)     # assume dependency will be found already installed
    set(${ARG_LIB_NAME}_PROVIDED_TARGET                 # this shall should be set to the name provided by a fetched dependency
        ${ARG_TARGET_NAME} PARENT_SCOPE)                #   (to be overridden by TARGET_NAME_SYSTEM if a system library is used)
    set(${ARG_LIB_NAME}_INSTALL_TARGET "" PARENT_SCOPE) # no install target for an already installed dependency

    set(should_fetch FALSE) # 2026-01-25: default initialization

    # Determine search strategy
    if(NOT USE_SYSTEM_LIBS)
        set(should_fetch TRUE)
    else()
        # Try system first
        if(PREFER_STATIC)
            # Look for static first
            set(CMAKE_FIND_LIBRARY_SUFFIXES_SAVED ${CMAKE_FIND_LIBRARY_SUFFIXES})
            if(WIN32)
                # set(CMAKE_FIND_LIBRARY_SUFFIXES ".lib" ".a" ${CMAKE_FIND_LIBRARY_SUFFIXES})
                set(CMAKE_FIND_LIBRARY_SUFFIXES ".lib" ".a")
            else()
                # set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ${CMAKE_FIND_LIBRARY_SUFFIXES})
                set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
            endif()
        endif()

        # 2026-01-25: test whether components are specified & call find_package accordingly
        set( COMPONENTS_PARAM )
        if( "${ARG_COMPONENTS}" STREQUAL "" )
            message( NOTICE "manage_dependency: attempting to find_package ${ARG_PACKAGE_NAME} ${ARG_VERSION} with ${ARG_EXTRA_ARGS} QUIET" )
        else()
            list( APPEND COMPONENTS_PARAM COMPONENTS ${ARG_COMPONENTS} )
            message( NOTICE "manage_dependency: attempting to find_package ${ARG_PACKAGE_NAME} ${ARG_VERSION} with ${ARG_EXTRA_ARGS} ${COMPONENTS_PARAM} QUIET" )
        endif()


        if(PREFER_STATIC)
            find_library(TARGET_STATIC
                # NAMES boost_nowide libboost_nowide nowide
                NAMES ${ARG_TYPICAL_NAMES}
                PATHS ${CMAKE_PREFIX_PATH} /usr/lib /usr/local/lib
                NO_DEFAULT_PATH
            )

            if (NOT TARGET_STATIC)
                find_library(TARGET_STATIC
                    # NAMES boost_nowide libboost_nowide nowide
                    NAMES ${ARG_TYPICAL_NAMES}
                )
            endif()

            if(TARGET_STATIC AND "${TARGET_STATIC}" MATCHES "\\.a$" )
                message( NOTICE "manage_dependency: TARGET_STATIC matches \\.a$" )
            else()
                set(TARGET_STATIC FALSE)
            endif()
        endif()

        # Only attempt to find_package if either the library type does not matter OR a static library should be locatable
        if(TARGET_STATIC OR NOT PREFER_STATIC)
            find_package(${ARG_PACKAGE_NAME} ${ARG_VERSION}
                ${ARG_EXTRA_ARGS}
                ${COMPONENTS_PARAM}
                QUIET
            )
        endif()

        if(PREFER_STATIC)
            set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES_SAVED})
        endif()

        if(${ARG_PACKAGE_NAME}_FOUND)
            # get_target_property(LIBRARY_TYPE ${ARG_TARGET_NAME} TYPE)
            get_target_property(LIBRARY_TYPE ${ARG_TARGET_NAME_SYSTEM} TYPE)

            message(STATUS "manage_dependency: ${ARG_TARGET_NAME_SYSTEM} target TYPE = ${LIBRARY_TYPE}")
            # get_target_property(LIBRARY_LOCATION ${ARG_TARGET_NAME} IMPORTED_LOCATION_RELEASE)
            # message(STATUS "${ARG_TARGET_NAME} target IMPORTED_LOCATION_RELEASE = ${LIBRARY_LOCATION}")
            # message(STATUS "${ARG_TARGET_NAME} variables: ${ARG_PACKAGE_NAME}_LIBRARIES=${${ARG_PACKAGE_NAME}_LIBRARIES}")
            if(PREFER_STATIC AND "${LIBRARY_TYPE}" STREQUAL "SHARED_LIBRARY" )
                message( FATAL_ERROR "manage_dependency: Found system ${ARG_LIB_NAME} as shared library, but static library is required" )
                set(should_fetch ${FETCH_DEPS_AUTO})
            else()  # else: PREFER_STATIC OFF OR LIBRARY_TYPE is not SHARED
                set(should_fetch FALSE)
                set(${ARG_LIB_NAME}_PROVIDED_TARGET             # ${ARG_LIB_NAME}_PROVIDED_TARGET should be the name as provided by an installed library
                    ${ARG_TARGET_NAME_SYSTEM} PARENT_SCOPE)     #
                set(ARG_TARGET_NAME ${ARG_TARGET_NAME_SYSTEM})  # also, the variable ${ARG_TARGET_NAME_SYSTEM}_FOUND will be set to TRUE, so adjust ARG_TARGET_NAME
                message(STATUS "manage_dependency: Found system ${ARG_LIB_NAME}: ${${ARG_PACKAGE_NAME}_VERSION}")
            endif()
        else()
            set(should_fetch ${FETCH_DEPS_AUTO})       # BUGFIX 2026-01-25: was previously not evaluating variable FETCH_DEPS_AUTO
        endif()
    endif()

    # Fetch if needed
    if(should_fetch)
        if( NOT "${ARG_GITHUB_REPO}" STREQUAL "" )
            set( ARG_GIT_REPOSITORY "https://github.com/${ARG_GITHUB_REPO}.git" )
        endif()

        include(FetchContent)

# message( NOTICE "FetchContent_Declare_custom(" )
# message( NOTICE "    LIB_NAME       ${ARG_LIB_NAME}_fetch" )
# message( NOTICE "    URL            ${ARG_URL}" )
# message( NOTICE "    URL_HASH       ${ARG_URL_HASH}" )
# message( NOTICE "    GIT_REPOSITORY ${ARG_GIT_REPOSITORY}" )
# message( NOTICE "    GIT_TAG        ${ARG_GIT_TAG}" )
# message( NOTICE "    EXCLUDE_FROM_ALL" )
# message( NOTICE ")" )
        FetchContent_Declare_custom(
                LIB_NAME       ${ARG_LIB_NAME}_fetch
                URL            ${ARG_URL}
                URL_HASH       ${ARG_URL_HASH}
                GIT_REPOSITORY ${ARG_GIT_REPOSITORY}
                GIT_TAG        ${ARG_GIT_TAG}
                EXCLUDE_FROM_ALL
        )

        # Set appropriate build type
        if(PREFER_STATIC)
            set(${ARG_LIB_NAME}_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
        else()
            set(${ARG_LIB_NAME}_BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
        endif()

        # Make available but don't build yet
        FetchContent_MakeAvailable_custom(
            LIB_NAME         ${ARG_LIB_NAME}_fetch
            EXCLUDE_FROM_ALL
        )

        set(${ARG_LIB_NAME}_FETCHED TRUE PARENT_SCOPE)
    endif()

    # Verify target exists
    if(NOT TARGET ${ARG_TARGET_NAME})
        message(FATAL_ERROR
            "manage_dependency: Dependency ${ARG_LIB_NAME} (target ${ARG_TARGET_NAME}) not available. "
            "Check your system installation or enable FETCH_DEPS_AUTO."
        )
    else() # target exists
        get_target_property(TARGET_IS_IMPORTED "${ARG_TARGET_NAME}" IMPORTED)
        if(TARGET_IS_IMPORTED)
            message( DEBUG "manage_dependency: target ${ARG_TARGET_NAME} is imported" )
            set(${ARG_LIB_NAME}_INSTALL_TARGET "" PARENT_SCOPE)  # imported targets do not need to be installed
        else()
            message( DEBUG "manage_dependency: target ${ARG_TARGET_NAME} is not imported and must be installed" )
            # unfortunately, ARG_TARGET_NAME can be an alias, which does not behave well with cmake install
            # so: get the aliased target, if any
            get_target_property(ALIASED_INSTALL_TARGET "${ARG_TARGET_NAME}" ALIASED_TARGET)
            if(ALIASED_INSTALL_TARGET)
                message( STATUS "manage_dependency: target ${ARG_TARGET_NAME} is an alias, resolved to ${ALIASED_INSTALL_TARGET}" )
                set(${ARG_LIB_NAME}_INSTALL_TARGET "${ALIASED_INSTALL_TARGET}" PARENT_SCOPE)
            else()
                message( DEBUG "manage_dependency: target ${ARG_TARGET_NAME} is already the final target" )
                set(${ARG_LIB_NAME}_INSTALL_TARGET "${ARG_TARGET_NAME}" PARENT_SCOPE)
            endif()

        endif()
    endif()

    # Restore global state
    set(BUILD_SHARED_LIBS ${SAVED_BUILD_SHARED_LIBS} PARENT_SCOPE)
    set(CMAKE_PREFIX_PATH ${SAVED_CMAKE_PREFIX_PATH} PARENT_SCOPE)
endfunction()
# End of Function:   manage_dependency


# Function: target_link_interface
# Purpose:  link an interface library that does not inherit an install target from dependency
# Author:   Lars Uffmann (coding23@uffmann.name)
# NOTE: INTERFACE_NAME has to be included in install TARGETS by the caller
function(target_link_interface)
    set(options PUBLIC PRIVATE) # one option must be explicitly indicated:
    #                           #   PRIVATE: users of ${ARG_INTERFACE_NAME} shall not use features of ${ARG_DEPENDENCY_ALIAS}
    #                           #   PUBLIC:  users of ${ARG_INTERFACE_NAME} may use features of ${ARG_DEPENDENCY_ALIAS}
    set(oneValueArgs
        LIB_NAME           # the library that shall be linked versus an interface to dependency
        INTERFACE_NAME     # name of the interface library to be created (will be needed by caller in install targets)
        DEPENDENCY_ALIAS   # the name (can be alias) of the actual underlying dependency
        DEPENDENCY_TARGET  # the name (not alias) of the underlying dependency
    )
    set(multiValueArgs EXTRA_ARGS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(ARG_PUBLIC AND ARG_PRIVATE)
        message( FATAL_ERROR "target_link_interface: flags PUBLIC and PRIVATE are mutually exclusive")
    endif()
    if(NOT (ARG_PUBLIC OR ARG_PRIVATE))
        message( FATAL_ERROR "target_link_interface: PUBLIC or PRIVATE must be specified")
    endif()

    # Ridiculous workaround part 1: Define an IMPORTED library to properly inherit INTERFACE_INCLUDE_DIRECTORIES from DEPENDENCY_NAME
    set(IMPORTED_NAME "${ARG_INTERFACE_NAME}_imported")  # NOTE: this name is assumed to be unique within project
    add_library(${IMPORTED_NAME} STATIC IMPORTED)
    set_target_properties(${IMPORTED_NAME} PROPERTIES
        # What we do not care about: imported location
        # IMPORTED_LOCATION "" # using a FAKE target that exists, the imported library can be used to fetch nowide INTERFACE_INCLUDE_DIRECTORIES
        # to omit the requirement for this fake target, a second abstraction level via Ridiculous workaround part 2 is needed

        # What we are actually interested in: interface include directories and compile definitions
        INTERFACE_INCLUDE_DIRECTORIES "$<TARGET_PROPERTY:${ARG_DEPENDENCY_ALIAS},INTERFACE_INCLUDE_DIRECTORIES>"
        INTERFACE_COMPILE_DEFINITIONS "$<TARGET_PROPERTY:${ARG_DEPENDENCY_ALIAS},INTERFACE_COMPILE_DEFINITIONS>"
    )

    # Ridiculous workaround part 2: Define an INTERFACE library to the IMPORTED ${IMPORTED_NAME}, while eliminating the need for an IMPORTED_LOCATION
    add_library(${ARG_INTERFACE_NAME} INTERFACE)
    # NOTE: INTERFACE_NAME will expose INTERFACE_INCLUDE_DIRECTORIES and INTERFACE_COMPILE_DEFINITIONS of DEPENDENCY_ALIAS via the IMPORTED library
    target_include_directories(${ARG_INTERFACE_NAME} INTERFACE $<TARGET_PROPERTY:${IMPORTED_NAME},INTERFACE_INCLUDE_DIRECTORIES> )
    target_compile_definitions(${ARG_INTERFACE_NAME} INTERFACE $<TARGET_PROPERTY:${IMPORTED_NAME},INTERFACE_COMPILE_DEFINITIONS> )
    # CAUTION: do *NOT* use target_link_libraries to link to the IMPORTED library, this would re-activate the need for an IMPORTED_LOCATION

    # Ridiculous workaround part 3: Link LIB_NAME against the INTERFACE library
    if(ARG_PUBLIC)
        set( ARG_PRIVACY "PUBLIC" )
    else()
        set( ARG_PRIVACY "PRIVATE" )   # begin of function has asserted that either ARG_PUBLIC or ARG_PRIVATE must be true
    endif()
    target_link_libraries(${ARG_LIB_NAME}
        ${ARG_PRIVACY}        # PRIVATE means users of ${ARG_INTERFACE_NAME} shall not use features of ${ARG_DEPENDENCY_ALIAS}
        ${ARG_INTERFACE_NAME} # this links INTERFACE_INCLUDE_DIRECTORIES
    )

    # Ridiculous workaround part 4: link to the built archive file so that ARG_LIB_NAME does not require DEPENDENCY_TARGET to be in the export set
    target_link_libraries(${ARG_LIB_NAME}
        ${ARG_PRIVACY}  # TBD: would always PRIVATE mangle symbols so that users can not access them from the static LIB_NAME?
        $<TARGET_FILE:${ARG_DEPENDENCY_TARGET}>
    )

    # Ridiculous workaround part 5: ensure DEPENDENCY_ALIAS is built before LIB_NAME (so that archive exists at link time)
    add_dependencies(${ARG_LIB_NAME} ${ARG_DEPENDENCY_ALIAS})
endfunction()
# End of Function:   target_link_interface
