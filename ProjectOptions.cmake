include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(image_histogram_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(image_histogram_setup_options)
  option(image_histogram_ENABLE_HARDENING "Enable hardening" ON)
  option(image_histogram_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    image_histogram_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    image_histogram_ENABLE_HARDENING
    OFF)

  image_histogram_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR image_histogram_PACKAGING_MAINTAINER_MODE)
    option(image_histogram_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(image_histogram_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(image_histogram_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(image_histogram_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(image_histogram_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(image_histogram_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(image_histogram_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(image_histogram_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(image_histogram_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(image_histogram_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(image_histogram_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(image_histogram_ENABLE_PCH "Enable precompiled headers" OFF)
    option(image_histogram_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(image_histogram_ENABLE_IPO "Enable IPO/LTO" ON)
    option(image_histogram_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(image_histogram_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(image_histogram_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(image_histogram_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(image_histogram_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(image_histogram_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(image_histogram_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(image_histogram_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(image_histogram_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(image_histogram_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(image_histogram_ENABLE_PCH "Enable precompiled headers" OFF)
    option(image_histogram_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      image_histogram_ENABLE_IPO
      image_histogram_WARNINGS_AS_ERRORS
      image_histogram_ENABLE_USER_LINKER
      image_histogram_ENABLE_SANITIZER_ADDRESS
      image_histogram_ENABLE_SANITIZER_LEAK
      image_histogram_ENABLE_SANITIZER_UNDEFINED
      image_histogram_ENABLE_SANITIZER_THREAD
      image_histogram_ENABLE_SANITIZER_MEMORY
      image_histogram_ENABLE_UNITY_BUILD
      image_histogram_ENABLE_CLANG_TIDY
      image_histogram_ENABLE_CPPCHECK
      image_histogram_ENABLE_COVERAGE
      image_histogram_ENABLE_PCH
      image_histogram_ENABLE_CACHE)
  endif()

  image_histogram_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (image_histogram_ENABLE_SANITIZER_ADDRESS OR image_histogram_ENABLE_SANITIZER_THREAD OR image_histogram_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(image_histogram_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(image_histogram_global_options)
  if(image_histogram_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    image_histogram_enable_ipo()
  endif()

  image_histogram_supports_sanitizers()

  if(image_histogram_ENABLE_HARDENING AND image_histogram_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR image_histogram_ENABLE_SANITIZER_UNDEFINED
       OR image_histogram_ENABLE_SANITIZER_ADDRESS
       OR image_histogram_ENABLE_SANITIZER_THREAD
       OR image_histogram_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${image_histogram_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${image_histogram_ENABLE_SANITIZER_UNDEFINED}")
    image_histogram_enable_hardening(image_histogram_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(image_histogram_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(image_histogram_warnings INTERFACE)
  add_library(image_histogram_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  image_histogram_set_project_warnings(
    image_histogram_warnings
    ${image_histogram_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(image_histogram_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(image_histogram_options)
  endif()

  include(cmake/Sanitizers.cmake)
  image_histogram_enable_sanitizers(
    image_histogram_options
    ${image_histogram_ENABLE_SANITIZER_ADDRESS}
    ${image_histogram_ENABLE_SANITIZER_LEAK}
    ${image_histogram_ENABLE_SANITIZER_UNDEFINED}
    ${image_histogram_ENABLE_SANITIZER_THREAD}
    ${image_histogram_ENABLE_SANITIZER_MEMORY})

  set_target_properties(image_histogram_options PROPERTIES UNITY_BUILD ${image_histogram_ENABLE_UNITY_BUILD})

  if(image_histogram_ENABLE_PCH)
    target_precompile_headers(
      image_histogram_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(image_histogram_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    image_histogram_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(image_histogram_ENABLE_CLANG_TIDY)
    image_histogram_enable_clang_tidy(image_histogram_options ${image_histogram_WARNINGS_AS_ERRORS})
  endif()

  if(image_histogram_ENABLE_CPPCHECK)
    image_histogram_enable_cppcheck(${image_histogram_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(image_histogram_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    image_histogram_enable_coverage(image_histogram_options)
  endif()

  if(image_histogram_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(image_histogram_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(image_histogram_ENABLE_HARDENING AND NOT image_histogram_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR image_histogram_ENABLE_SANITIZER_UNDEFINED
       OR image_histogram_ENABLE_SANITIZER_ADDRESS
       OR image_histogram_ENABLE_SANITIZER_THREAD
       OR image_histogram_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    image_histogram_enable_hardening(image_histogram_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
