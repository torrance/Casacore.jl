project(casacorecxx)

cmake_minimum_required(VERSION 3.10)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

# Find JLCxx
find_package(JlCxx REQUIRED)
get_target_property(JlCxx_location JlCxx::cxxwrap_julia LOCATION)
get_filename_component(JlCxx_location ${JlCxx_location} DIRECTORY)
set(CMAKE_INSTALL_RPATH "$(CMAKE_INSTALL_PREFIX)/lib;$(JLCxx_location)")
message(STATUS "Found JlCxx at ${JlCxx_location}")

# Find casacore
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
find_package(Casacore REQUIRED)

# Add our library
add_library(casacorecxx SHARED
  src/tables.cpp)

# Link to JLCxx and of course casa
target_link_libraries(casacorecxx JlCxx::cxxwrap_julia JlCxx::cxxwrap_julia_stl ${CASACORE_LIBRARIES})

# Install
install(TARGETS casacorecxx
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION lib
)
