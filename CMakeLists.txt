cmake_minimum_required( VERSION 3.8 )

project( boost )

include( BuildBoost.cmake )
include( Lipo.cmake )

set( BOOST_MODULES ${BOOST_STANDARD_MODULES} )

set( INSTALL_DIR ${CMAKE_BINARY_DIR}/boost )
set( INSTALL_DIR_LIB ${INSTALL_DIR}/lib )
set( INSTALL_DIR_INCLUDE ${INSTALL_DIR}/include )

set( SDKS iphoneos iphonesimulator )
set( BOOST_TARGET_ARCHITECTURES_iphoneos armv7 armv7s arm64 )
set( BOOST_TARGET_ARCHITECTURES_iphonesimulator i386 x86_64 )

set( BUILD_FRAMEWORK on CACHE BOOL "" )
set( BITCODE_ENABLED on CACHE BOOL "" )
set( BUILD_SHARED on CACHE BOOL "" )

set( BOOST_BOOL_OPTIONS )
if( BUILD_FRAMEWORK )
    list( APPEND BOOST_BOOL_OPTIONS FRAMEWORK )
endif()
if( BUILD_SHARED )
    list( APPEND BOOST_BOOL_OPTIONS DYLIB )
endif()
if( BITCODE_ENABLED )
    list( APPEND BOOST_BOOL_OPTIONS BITCODE )
endif()

foreach( BOOST_MODULE ${BOOST_MODULES} )
    set( BOOST_THIN_${BOOST_MODULE}_STATIC_LIBS_${SDK})
    if( BUILD_SHARED )
        set( BOOST_THIN_${BOOST_MODULE}_SHARED_LIBS_${SDK} )
    endif()
endforeach( BOOST_MODULE )

set( BOOST_INCLUDES )
foreach( SDK ${SDKS} )
    execute_process( COMMAND xcrun --sdk ${SDK} --show-sdk-path
            OUTPUT_VARIABLE XCODE_SDK_PATH
            OUTPUT_STRIP_TRAILING_WHITESPACE )

    set( PER_SDK_INSTALL_DIR ${INSTALL_DIR}/${SDK} )
    BuildBoost( SDK ${SDK}
            SDK_PATH ${XCODE_SDK_PATH}
            TARGET_ARCHITECTURES ${BOOST_TARGET_ARCHITECTURES_${SDK}}
            MODULES ${BOOST_MODULES}
            INSTALL_DIR ${PER_SDK_INSTALL_DIR}
            ${BOOST_BOOL_OPTIONS} )

    list( APPEND BOOST_INCLUDES_STAMPS ${BOOST_INCLUDES_STAMP_${SDK}} )
    list( APPEND BOOST_INCLUDES ${BOOST_INCLUDES_${SDK}} )
    foreach( BOOST_MODULE ${BOOST_MODULES} )
        list( APPEND BOOST_THIN_${BOOST_MODULE}_STATIC_LIBS ${BOOST_THIN_${BOOST_MODULE}_STATIC_LIB_${SDK}} )
        if( BUILD_SHARED )
            list( APPEND BOOST_THIN_${BOOST_MODULE}_SHARED_LIBS ${BOOST_THIN_${BOOST_MODULE}_SHARED_LIB_${SDK}} )
        endif()
    endforeach( BOOST_MODULE )
endforeach( SDK )

set( BOOST_LIPO_DEPENDENCIES )
foreach( BOOST_MODULE ${BOOST_MODULES} )
    set( BOOST_${BOOST_MODULE}_STATIC ${CMAKE_STATIC_LIBRARY_PREFIX}boost_${BOOST_MODULE}${CMAKE_STATIC_LIBRARY_SUFFIX} )
    set( BOOST_INSTALL_PATH_${BOOST_MODULE}_STATIC ${BOOST_INSTALL_DIR_LIB}/${BOOST_${BOOST_MODULE}_STATIC} )
    Lipo( INPUTS ${BOOST_THIN_${BOOST_MODULE}_STATIC_LIBS}
            OUTPUT ${BOOST_INSTALL_PATH_${BOOST_MODULE}_STATIC} )

    if( BUILD_SHARED )
        set( BOOST_${BOOST_MODULE}_SHARED ${CMAKE_SHARED_LIBRARY_PREFIX}boost_${BOOST_MODULE}${CMAKE_SHARED_LIBRARY_SUFFIX} )
        set( BOOST_INSTALL_PATH_${BOOST_MODULE}_SHARED ${BOOST_INSTALL_DIR_LIB}/${BOOST_${BOOST_MODULE}_SHARED} )
        Lipo( INPUTS ${BOOST_THIN_${BOOST_MODULE}_SHARED_LIBS}
                OUTPUT ${BOOST_INSTALL_PATH_${BOOST_MODULE}_SHARED} )
    endif()
endforeach( BOOST_MODULE )

list( GET BOOST_INCLUDES 0 BOOST_INCLUDES_DIR )
set( BOOST_INCLUDES_STAMP ${INSTALL_DIR}/boost_include.stamp)
add_custom_command( OUTPUT ${BOOST_INCLUDES_STAMP}
        DEPENDS ${BOOST_INCLUDES_STAMPS}
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${BOOST_INCLUDES_DIR} ${INSTALL_DIR_INCLUDE}
        COMMAND touch ${BOOST_INCLUDES_STAMP}
        COMMENT "Copying Boost ${BOOST_INCLUDES_DIR} to ${INSTALL_DIR_INCLUDE}" )

add_custom_target( boost_build ALL
        DEPENDS ${BOOST_INCLUDES_STAMP} )

# Package Boost as a static, dynamic or framework
if( BUILD_SHARED_LIBS AND BUILD_FRAMEWORK )
    add_library( Boost SHARED ${INSTALL_PATH_CRYPTO_SHARED} ${INSTALL_PATH_SSL_SHARED} )
    set_target_properties( Boost PROPERTIES
            FRAMEWORK TRUE
            MACOSX_FRAMEWORK_IDENTIFIER org.boost.boost_framework
            MACOSX_FRAMEWORK_INFO_PLIST Info.plist
            # "current version" in semantic format in Mach-O binary file
            VERSION 1.63
            # "compatibility version" in semantic format in Mach-O binary file
            SOVERSION 1.63
            PUBLIC_HEADER dynamicFramework.h )
endif()
