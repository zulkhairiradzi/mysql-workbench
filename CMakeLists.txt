cmake_minimum_required (VERSION 2.8)
# 2.8 needed because of ExternalProject

# Detect build type, fallback to release and throw a warning if use didn't specify any
if(NOT CMAKE_BUILD_TYPE)
  message(WARNING "Build type not set, falling back to Release mode.
 To specify build type use:
 -DCMAKE_BUILD_TYPE=<mode> where <mode> is Debug or Release.")
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING
       "Choose the type of build, options are: Debug Release RelWithDebInfo"
       FORCE)
endif(NOT CMAKE_BUILD_TYPE)

project(WORKBENCH)

# Retrieve current Workbench version variables
execute_process(COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tools/get_wb_version.sh major
                OUTPUT_VARIABLE WB_MAJOR_VERSION)
execute_process(COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tools/get_wb_version.sh minor
                OUTPUT_VARIABLE WB_MINOR_VERSION)
execute_process(COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tools/get_wb_version.sh revision
                OUTPUT_VARIABLE WB_RELEASE_VERSION)
execute_process(COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tools/get_wb_version.sh full_version
                OUTPUT_VARIABLE WB_VERSION)

string(STRIP ${WB_MAJOR_VERSION} WB_MAJOR_VERSION)
string(STRIP ${WB_MINOR_VERSION} WB_MINOR_VERSION)
string(STRIP ${WB_RELEASE_VERSION} WB_RELEASE_VERSION)
string(STRIP ${WB_VERSION} WB_VERSION)


#  About MySQL and CMake
#  http://dev.mysql.com/doc/internals/en/autotools-to-cmake.html
#  http://www.lenzg.net/archives/291-Building-MySQL-Server-with-CMake-on-LinuxUnix.html

#-----------------------------------------------------------------------
# Find packages and other useful checks
#-----------------------------------------------------------------------

# Look for our custom modules in cmake/Modules:
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/build/cmake/Modules/")

if(ENABLE_COTIRE AND CMAKE_VERSION VERSION_GREATER "2.8.11")
  include(cotire)
  set_property(DIRECTORY PROPERTY COTIRE_UNITY_LINK_LIBRARIES_INIT "COPY_UNITY")
endif()
find_package(PkgConfig REQUIRED)
find_package(Java QUIET)
find_package(X11)



set(ANTLR_JAR_FILENAME "antlr-4.7.1-complete.jar")
get_filename_component(SOURCE_PARENT_DIR ${CMAKE_SOURCE_DIR} DIRECTORY)
set(LINUX_RES_BIN_DIR ${SOURCE_PARENT_DIR}/linux-res/bin)
if(WITH_ANTLR_JAR)
  get_filename_component(ANTLR_JAR_USER_DIR ${WITH_ANTLR_JAR} DIRECTORY)
  find_path(ANTLR_JAR_PATH ${ANTLR_JAR_FILENAME} ${LINUX_RES_BIN_DIR} ${ANTLR_JAR_USER_DIR})
else(WITH_ANTLR_JAR)
  find_path(ANTLR_JAR_PATH ${ANTLR_JAR_FILENAME} ${LINUX_RES_BIN_DIR})
endif(WITH_ANTLR_JAR)
if(ANTLR_JAR_PATH AND Java_JAVA_EXECUTABLE) 
  set(ANTLR_JAR_PATH ${ANTLR_JAR_PATH}/${ANTLR_JAR_FILENAME})
  message(STATUS "ANTLR jar: " ${ANTLR_JAR_PATH})
else()
  message(WARNING ${ANTLR_JAR_FILENAME} " or java runtime wasn't found which is required if you'd like to rebuild Lexer and Parser files")
endif()

#find_package(GTK3 REQUIRED gtk+-3.0 gtkmm-3.0)
pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
pkg_check_modules(GTKMM REQUIRED gtkmm-3.0)
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
pkg_check_modules(GMODULE REQUIRED gmodule-2.0)
#set(GTK3_INCLUDE_DIRS ${GTK3_INCLUDE_DIRS} ${GTHREAD_INCLUDE_DIRS} ${GMODULE_INCLUDE_DIRS})
set(GTK3_INCLUDE_DIRS ${GTK3_INCLUDE_DIRS} ${GTKMM_INCLUDE_DIRS} ${GTHREAD_INCLUDE_DIRS} ${GMODULE_INCLUDE_DIRS})
list(REMOVE_DUPLICATES GTK3_INCLUDE_DIRS)
#set(GTK3_LIBRARIES ${GTK3_LIBRARIES} ${GTHREAD_LIBRARIES} ${GMODULE_LIBRARIES})
set(GTK3_LIBRARIES ${GTK3_LIBRARIES} ${GTKMM_LIBRARIES} ${GTHREAD_LIBRARIES} ${GMODULE_LIBRARIES})
list(REMOVE_DUPLICATES GTK3_LIBRARIES)

pkg_check_modules(GLIB REQUIRED glib-2.0>=2.30)

if (USE_BUNDLED_MYSQLDUMP)
  set(USE_BUNDLED_MYSQLDUMP -DHAVE_BUNDLED_MYSQLDUMP=1)
endif ()

find_package(Threads)
find_package(SWIG REQUIRED)
include(${SWIG_USE_FILE})

find_package(ANTLR4 REQUIRED)

# In Ubuntu 13.04, the built-in check for python fails.. so we have to resort to the check with pkg-config (which doesn't work in many distros)
find_package(PythonLibs 2.6)
if (NOT PYTHONLIBS_FOUND)
    pkg_check_modules(PYTHON REQUIRED python)
endif ()


# We need to be able to detect python module versions and packages hence this function

FIND_PROGRAM(PYTHON_EXEC "python2")
include(FindPackageHandleStandardArgs)

find_package(MySQL 5.6.0 REQUIRED)
if (UNIX)
	set(MYSQL_DEFINITIONS "-DBIG_JOINS=1"  "-fno-strict-aliasing")
endif()



find_package(LibXml2 REQUIRED)

find_package(OpenGL REQUIRED)

find_package(MySQLCppConn 1.1.8 REQUIRED)
find_package(VSqlite REQUIRED)
find_package(GDAL REQUIRED)
find_package(Boost REQUIRED)
find_package(LibSSH 0.8.5 REQUIRED)
find_package(OpenSSL REQUIRED)
set(PRECOMPILED_HEADERS_EXCLUDE_PATHS "/usr/include/gdal;/usr/include/arpa;${CMAKE_SOURCE_DIR};${PROJECT_SOURCE_DIR}/ext/antlr-runtime;${PROJECT_BINARY_DIR};${MySQL_INCLUDE_DIRS};${MYSQLNG_INCLUDE_DIR};${Boost_INCLUDE_DIRS}")

if (UNIX)
  option(USE_UNIXODBC "Use unixODBC instead of iODBC" OFF)
  find_package(IODBC)
  find_package(UNIXODBC)

  if (USE_UNIXODBC)
    if (UNIXODBC-NOTFOUND)
      message(FATAL_ERROR "You've selected Unixodbc, but it cannot be found, CMake will exit.")
    else()
		  set(ODBC_LIBRARIES ${UNIXODBC_LIBRARIES})
  		set(ODBC_INCLUDE_DIRS ${UNIXODBC_INCLUDE_DIRS})
	  	set(ODBC_DEFINITIONS ${UNIXODBC_DEFINITIONS})
    endif()
  else()
    if (IODBC_FOUND)
      message("Found iodbc, using it as ODBC library.")
      set(ODBC_LIBRARIES ${IODBC_LIBRARIES})
      set(ODBC_INCLUDE_DIRS ${IODBC_INCLUDE_DIRS})
      set(ODBC_DEFINITIONS ${IODBC_DEFINITIONS})
    elseif (UNIXODBC_FOUND)
      message("Found unixodbc, using it as ODBC library.")
      set(ODBC_LIBRARIES ${UNIXODBC_LIBRARIES})
      set(ODBC_INCLUDE_DIRS ${UNIXODBC_INCLUDE_DIRS})
      set(ODBC_DEFINITIONS ${UNIXODBC_DEFINITIONS})
    else()
      message(FATAL_ERROR "Workbench required iodbc or Unixodbc, none was found, CMake will exit.")
    endif()
  endif(USE_UNIXODBC)

endif(UNIX)


pkg_check_modules(PCRE REQUIRED libpcre libpcrecpp)
pkg_check_modules(CAIRO REQUIRED cairo>=1.5.12)
pkg_check_modules(UUID REQUIRED uuid)
pkg_check_modules(LIBZIP REQUIRED libzip)
if (UNIX)
  pkg_check_modules(LIBSECRET REQUIRED libsecret-1)
	if (LIBSECRET_FOUND)
		set(KEYRING_DEFINITION     "HAVE_LIBSECRET_KEYRING")
	endif()
endif()

if (UNIX)
  include (CheckIncludeFiles)
  CHECK_INCLUDE_FILES ("sys/prctl.h" HAVE_PRCTL)
  if (HAVE_PRCTL)
    add_definitions(-DHAVE_PRCTL_H)
  endif()
endif()

include (CheckFunctionExists)
check_function_exists (strtol HAVE_STRTOL)
check_function_exists (strtoll HAVE_STRTOLL)
check_function_exists (strtold HAVE_STRTOLD)
check_function_exists (strtoull HAVE_STRTOULL)
check_function_exists (strtoimax HAVE_STRTOIMAX)
check_function_exists (strtoumax HAVE_STRTOUMAX)

if (UNIX)
	if (NOT LIB_INSTALL_DIR)
		set(LIB_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}/lib")
	endif()
	if (NOT SHARE_INSTALL_PREFIX)
		set(SHARE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/share")
	endif()
	if (NOT ETC_INSTALL_DIR)
		set(ETC_INSTALL_DIR "/etc")
	endif()
	if (NOT REAL_EXECUTABLE_DIR)
		set(REAL_EXECUTABLE_DIR "${CMAKE_INSTALL_PREFIX}/bin")
	endif()

	set(WB_INSTALL_DIR              "${CMAKE_INSTALL_PREFIX}")
	set(WB_INSTALL_DIR_EXECUTABLE   "${REAL_EXECUTABLE_DIR}")
	set(WB_INSTALL_BIN_DIR          "${CMAKE_INSTALL_PREFIX}/bin")
	set(WB_INSTALL_LIB_DIR          "${LIB_INSTALL_DIR}/mysql-workbench")
	set(WB_PYTHON_MODULES_DIR       "${WB_INSTALL_LIB_DIR}/modules")
	set(WB_INSTALL_SHARED_DIR       "${SHARE_INSTALL_PREFIX}")
	set(WB_INSTALL_ETC_DIR          "${ETC_INSTALL_DIR}")
	set(WB_PACKAGE_SHARED_DIR       "${SHARE_INSTALL_PREFIX}/mysql-workbench")
	set(WB_PACKAGE_PLUGINS_DIR      "${LIB_INSTALL_DIR}/mysql-workbench/plugins")
	set(WB_PYTHON_MODULES_DATA_DIR  "${SHARE_INSTALL_PREFIX}/mysql-workbench/modules/data")
	set(WB_INSTALL_DOC_DIR          "${SHARE_INSTALL_PREFIX}/doc/mysql-workbench")
endif()

include(ExternalProject)

#include(CheckCXXCompilerFlag)
#check_cxx_compiler_flag(-Wall  HAS_ALL_WARNS)
#if (HAS_ALL_WARNS)
#	add_definitions(-Wall)
#endif()
#check_cxx_compiler_flag(-Wsign-compare  HAS_SIGN_COMPARE)
#if (HAS_SIGN_COMPARE)
#	add_definitions(-Wsign-compare)
#endif()
add_definitions(-D__STDC_FORMAT_MACROS)
add_definitions(-DGTK_DISABLE_SINGLE_INCLUDES)
add_definitions(-DGDK_DISABLE_DEPRECATED)
add_definitions(-DGTK_DISABLE_DEPRECATED)
add_definitions(-DGSEAL_ENABLE)
add_definitions(-DTIXML_USE_STL=1)

set(BUILD_SHARED_LIBS ON)  # By default all libs will be built as shared libs
# SET(GCOV OFF CACHE BOOL "Add gcov flags")

# Determine std c++ version
if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
  set(CMAKE_CXX_STANDARD 11)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  if(CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL "5.0" OR CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "5.0")
    set(CMAKE_CXX_STANDARD 14)
  endif()
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  set(CMAKE_CXX_STANDARD 11)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "4.7")
    message(FATAL_ERROR "Insufficient gcc version. You need gcc v4.7 or newer to build this project")
  elseif(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "5.0")
    message("Using C++11 standard")
    set(CMAKE_CXX_STANDARD 11)
  elseif(CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL "5.0" OR CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "5.0")
    message("Using C++14 standard")
    set(CMAKE_CXX_STANDARD 14)
  endif()
  # C++17 requires gcc7
endif()



set(WB_CXXFLAGS -Werror -Wall -Wextra -Wno-unused-parameter -Wno-deprecated)
set(WB_CFLAGS -Werror -Wall -Wextra -Wno-unused-parameter -Wno-deprecated)

if(BUILD_FOR_GCOV)
    message ("Enable GCOV due to BUILD_FOR_GCOV")
    set(WB_CXXFLAGS ${WB_CXXFLAGS} -fprofile-arcs -ftest-coverage)
    set(WB_CFLAGS ${WB_CFLAGS} -fprofile-arcs -ftest-coverage)
endif()

#-----------------------------------------------------------------------
# Define some useful variables and options
#-----------------------------------------------------------------------

#set(NCORES 3)  # Use this number of cores when compiling
#if(CMAKE_COMPILER_IS_GNUCXX)
#	set(CMAKE_CXX_FLAGS "${CMAKE_CKK_FLAGS} -j${NCORES}")
#	message(STATUS "CMAKE_CXX_FLAGS = ${CMAKE_CXX_FLAGS}")
#	set(CMAKE_EXE_LINKER_FLAGS_DEBUG "-s")  ## Strip binary
#endif()


set(GRT_LIBRARIES ${PYTHON_LIBRARIES} ${LIBXML2_LIBRARIES})
set(GRT_INCLUDE_DIRS ${PYTHON_INCLUDE_DIRS} ${LIBXML2_INCLUDE_DIR})

configure_file(${PROJECT_SOURCE_DIR}/mysql-workbench.desktop.in mysql-workbench.desktop)

# FIXME: Should this go here? ---v
include_directories(${PROJECT_SOURCE_DIR}/plugins/migration/copytable ${PROJECT_SOURCE_DIR}/library/base)
include_directories(${GTK3_INCLUDE_DIRS})

add_subdirectory(tools)
add_subdirectory(backend)
add_subdirectory(ext)
add_subdirectory(frontend)
add_subdirectory(images)
add_subdirectory(library)
add_subdirectory(modules)
add_subdirectory(plugins)
add_subdirectory(res)
if (IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/internal)
  add_subdirectory(internal)
endif()

install(FILES ${CMAKE_BINARY_DIR}/mysql-workbench.desktop DESTINATION ${WB_INSTALL_SHARED_DIR}/applications)

if (IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/internal)
    install(FILES README-commercial.md License-commercial.txt DESTINATION ${WB_INSTALL_DOC_DIR})
else()
    install(FILES README.md License.txt DESTINATION ${WB_INSTALL_DOC_DIR})
endif()
install(FILES build/mysql-workbench-commercial.sharedmimeinfo DESTINATION ${WB_INSTALL_SHARED_DIR}/mime/packages RENAME mysql-workbench.xml)
install(FILES build/mysql-workbench-commercial.mime DESTINATION ${WB_INSTALL_SHARED_DIR}/mime-info RENAME mysql-workbench.mime)


install(FILES build/build_freetds.sh
        PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ
        DESTINATION ${WB_PACKAGE_SHARED_DIR}/extras)

install(FILES samples/models/sakila_full.mwb
        DESTINATION ${WB_PACKAGE_SHARED_DIR}/extras)
       
