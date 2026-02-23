# ============================================================================
# Author
# ============================================================================
# This module is a friendly contribution by NLATP (openxlsx.genetics016@passinbox.com)
#

# ============================================================================
# Policy Settings
# ============================================================================
if(POLICY CMP0077)
    cmake_policy(SET CMP0077 NEW)  # Respect BUILD_SHARED_LIBS
endif()

# ============================================================================
# Configuration Options, to be configured in caller CMakeLists.txt
# ============================================================================
# option(PREFER_STATIC "Prefer static linking over shared libraries" ON)
# option(USE_SYSTEM_LIBS "Use system-installed libraries when available" ON)
# option(FETCH_DEPS_AUTO "Automatically fetch missing dependencies" ON)
# option(FORCE_FETCH_ALL "Ignore system libraries and fetch all deps" OFF)

# ============================================================================
# Safety Checks
# ============================================================================
if(FORCE_FETCH_ALL)
    set(USE_SYSTEM_LIBS OFF CACHE BOOL "" FORCE)
    message(STATUS "FORCE_FETCH_ALL enabled: ignoring system libraries")
endif()

# ============================================================================
# Enhanced Helper Functions
# ============================================================================

# Function: manage_dependency
# Purpose:  Safely finds or fetches a dependency
function(manage_dependency)
    set(options "")
    set(oneValueArgs 
        LIB_NAME     # arbitrary label for the desired dependency for logging output
        PACKAGE_NAME # library name in the OS repositories for find_package
        VERSION      # use this to supply a local required version for find_package with PACKAGE_NAME
        COMPONENTS   # use if find_package shall only make available certain components
        TARGET_NAME  # the installation target that should be provided by the dependency
        #
        GITHUB_REPO  # use for github repositories only
        GIT_REPOSITORY  # use to provide a full repository URL
        GIT_TAG      # use this to supply the github version tag (can be preceeded by a 'v' whereas VERSION is typically(?) numerical only
        #
        URL          # URL & URL_HASH can be used together instead of GITHUB_REPO (GIT_REPOSITORY) & GIT_TAG
        URL_HASH     #
        #
        HEADER_FILE  # TBD: what is the point of HEADER_FILE?
    )
    set(multiValueArgs EXTRA_ARGS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Save global state
    set(SAVED_BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS})
    set(SAVED_CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH})

    set(should_fetch FALSE) # 2026-01-25: default initialization

    # Determine search strategy
    if(FORCE_FETCH_ALL)
        set(should_fetch TRUE)
    elseif(NOT USE_SYSTEM_LIBS)
        set(should_fetch TRUE)
    else()
        # Try system first
        if(PREFER_STATIC)
            # Look for static first
            set(CMAKE_FIND_LIBRARY_SUFFIXES_SAVED ${CMAKE_FIND_LIBRARY_SUFFIXES})
            if(WIN32)
                set(CMAKE_FIND_LIBRARY_SUFFIXES ".lib" ".a" ${CMAKE_FIND_LIBRARY_SUFFIXES})
            else()
                set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ${CMAKE_FIND_LIBRARY_SUFFIXES})
            endif()
        endif()

        # 2026-01-25: test whether components are specified & call find_package accordingly
        if("${ARG_COMPONENTS}" STREQUAL "")
            message( NOTICE "manage_dependency: attempting to find_package ${ARG_PACKAGE_NAME} ${ARG_VERSION} with ${ARG_EXTRA_ARGS} QUIET" )
            find_package(${ARG_PACKAGE_NAME} ${ARG_VERSION}
                ${ARG_EXTRA_ARGS}
                QUIET 
            )
        else()
            message( NOTICE "manage_dependency: attempting to find_package ${ARG_PACKAGE_NAME} ${ARG_VERSION} with ${ARG_EXTRA_ARGS} COMPONENTS ${ARG_COMPONENTS} QUIET" )
            find_package(${ARG_PACKAGE_NAME} ${ARG_VERSION}
                ${ARG_EXTRA_ARGS}
                COMPONENTS ${ARG_COMPONENTS}
                QUIET 
            )
        endif()

        if(PREFER_STATIC)
            set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES_SAVED})
        endif()

        if(${ARG_PACKAGE_NAME}_FOUND)
            set(should_fetch FALSE)
            message(STATUS "Found system ${ARG_LIB_NAME}: ${${ARG_PACKAGE_NAME}_VERSION}")
        else()
            set(should_fetch ${FETCH_DEPS_AUTO}) # BUGFIX 2026-01-25: was previously not evaluating variable FETCH_DEPS_AUTO
        endif()
    endif()

    # Fetch if needed
    if(should_fetch)
        if( NOT "${ARG_GITHUB_REPO}" STREQUAL "" )
            set( ARG_GIT_REPOSITORY "https://github.com/${ARG_GITHUB_REPO}.git" )
        endif()
        message(STATUS "Fetching ${ARG_LIB_NAME} from ${ARG_GIT_REPOSITORY}")

        include(FetchContent)

# message( NOTICE "FetchContent_Declare(" )
# message( NOTICE "    ${ARG_LIB_NAME}_fetch" )
# if( "${ARG_URL}" STREQUAL "" OR "${ARG_URL_HASH}" STREQUAL "" )
#     message( NOTICE "    GIT_REPOSITORY ${ARG_GIT_REPOSITORY}" )
#     message( NOTICE "    GIT_TAG        ${ARG_GIT_TAG}" )
# else()
#     message( NOTICE "    URL            ${ARG_URL}" )
#     message( NOTICE "    URL_HASH       ${ARG_URL_HASH}" )
# endif()
# message( NOTICE "    GIT_SHALLOW    TRUE" )
# message( NOTICE "    OVERRIDE_FIND_PACKAGE  # Important: override system package" )
# message( NOTICE ")" )
        if( "${ARG_URL}" STREQUAL "" OR "${ARG_URL_HASH}" STREQUAL "" )
            message( NOTICE "Fetching via github repository ${ARG_GIT_REPOSITORY} with tag ${ARG_GIT_TAG}" )
            FetchContent_Declare(
                ${ARG_LIB_NAME}_fetch
                GIT_REPOSITORY ${ARG_GIT_REPOSITORY}
                GIT_TAG        ${ARG_GIT_TAG}
                GIT_SHALLOW    TRUE
                OVERRIDE_FIND_PACKAGE  # Important: override system package
            )
        else()
            message( NOTICE "Fetching via URL ${ARG_URL}" )
            FetchContent_Declare(
                ${ARG_LIB_NAME}_fetch
                URL      ${ARG_URL}
                URL_HASH ${ARG_URL_HASH}
                OVERRIDE_FIND_PACKAGE  # Important: override system package
            )
        endif()

        # Set appropriate build type
        if(PREFER_STATIC)
            set(${ARG_LIB_NAME}_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
        else()
            set(${ARG_LIB_NAME}_BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
        endif()

        # Make available but don't build yet
        FetchContent_MakeAvailable(${ARG_LIB_NAME}_fetch)

        set(${ARG_LIB_NAME}_FETCHED TRUE PARENT_SCOPE)
    endif()

    # Verify target exists
    if(NOT TARGET ${ARG_TARGET_NAME})
        message(FATAL_ERROR 
            "Dependency ${ARG_LIB_NAME} (target ${ARG_TARGET_NAME}) not available. "
            "Check your system installation or enable FETCH_DEPS_AUTO."
        )
    endif()

    # Restore global state
    set(BUILD_SHARED_LIBS ${SAVED_BUILD_SHARED_LIBS} PARENT_SCOPE)
    set(CMAKE_PREFIX_PATH ${SAVED_CMAKE_PREFIX_PATH} PARENT_SCOPE)
endfunction()
