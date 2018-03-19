include( ExternalProject )

set_property( DIRECTORY PROPERTY EP_BASE third_party )

set( BOOST_SCRIPTS_DIR ${CMAKE_SOURCE_DIR} )
set( BOOST_TARBALL boost_1_63_0.tar.bz2 )
set( BOOST_URL "http://sourceforge.net/projects/boost/files/boost/1.63.0/${BOOST_TARBALL}" )
set( BOOST_SHA1 "9f1dd4fa364a3e3156a77dc17aa562ef06404ff6" )

#set( BOOST_GIT_REPO https://git.dev.promon.no/cameron/Boost.git )
#set( BOOST_GIT_TAG 1.63.0 )
set( BOOST_SHORT_VERSION 1.63.0 )

set( BOOST_STANDARD_MODULES date_time filesystem system )

function( BuildBoost )
    set( options FRAMEWORK DYLIB BITCODE )
    set( oneValueArgs SDK SDK_PATH INSTALL_DIR )
    set( multiValueArgs TARGET_ARCHITECTURES MODULES )
    cmake_parse_arguments( BuildBoost "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    set( SDK ${BuildBoost_SDK} )
    set( SDK_PATH ${BuildBoost_SDK_PATH} )
    set( TARGET_ARCHITECTURES ${BuildBoost_TARGET_ARCHITECTURES} )
    set( INSTALL_DIR ${BuildBoost_INSTALL_DIR} )
    set( BOOST_MODULES ${BuildBoost_MODULES} )

    if( BuildBoost_FRAMEWORK )
        set( GENERATE_FRAMEWORK true )
    endif()
    if( BuildBoost_DYLIB )
        set( BUILD_SHARED true )
    endif()
    if( BuildBoost_BITCODE )
        set( EMBED_BITCODE true )
    endif()

    set( BOOST_INCLUDES_${SDK} )

    set ( BOOST_CXXFLAGS )
    list( APPEND BOOST_CXXFLAGS -std=c++11 )
    list( APPEND BOOST_CXXFLAGS -stdlib=libc++ )
    list( APPEND BOOST_CXXFLAGS -fPIC )
    list( APPEND BOOST_CXXFLAGS -fvisibility=hidden )
    list( APPEND BOOST_CXXFLAGS -fvisibility-inlines-hidden )
    list( APPEND BOOST_CXXFLAGS -isysroot ${XCODE_SDK_PATH} )
    list( APPEND BOOST_CXXFLAGS -mios-version-min=8.0 )
    if( EMBED_BITCODE )
        list( APPEND BOOST_CXXFLAGS -fembed-bitcode )
    endif()

    BOOST_${BOOST_MODULE}_STATIC_LIBS_TARGET_ARCHITECTURES
    BOOST_${BOOST_MODULE}_SHARED_LIBS_TARGET_ARCHITECTURES
    foreach( TARGET_ARCHITECTURE ${TARGET_ARCHITECTURES} )
        set( BOOST_TARGET boost_${SDK}_${TARGET_ARCHITECTURE} )
        set( TARGET_INSTALL_DIR ${INSTALL_DIR}/${TARGET_ARCHITECTURE} )
        set( BOOST_STATIC_LIBS )
        set( BOOST_SHARED_LIBS )

        foreach( BOOST_MODULE ${BOOST_MODULES} )
            #        set( BOOST_THIN_${BOOST_MODULE}_STATIC_LIBS_${SDK} )
            ## Set up the name for the modules to be built libboost_filesystem.a for example
            set( BOOST_${BOOST_MODULE}_STATIC_LIB ${CMAKE_STATIC_LIBRARY_PREFIX}boost_${BOOST_MODULE}${CMAKE_STATIC_LIBRARY_SUFFIX} )
            list( APPEND BOOST_STATIC_LIBS_${TARGET_ARCHITECTURE} ${TARGET_INSTALL_DIR}/${BOOST_${BOOST_MODULE}_STATIC_LIB} )
            if( BUILD_SHARED )
                #            set( BOOST_THIN_${BOOST_MODULE}_SHARED_LIBS_${SDK} )
                set( BOOST_${BOOST_MODULE}_SHARED_LIB ${CMAKE_SHARED_LIBRARY_PREFIX}boost_${BOOST_MODULE}${CMAKE_SHARED_LIBRARY_SUFFIX} )
                list( APPEND BOOST_SHARED_LIBS_${TARGET_ARCHITECTURE} ${TARGET_INSTALL_DIR}/${BOOST_${BOOST_MODULE}_SHARED_LIB} )
            endif()
        endforeach( BOOST_MODULE )

        set( BOOST_SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/build/Source/${BOOST_TARGET} )

        ## CXXFLAGS Check
        string( REPLACE ";" " " CXXFLAGS_STRING "${BOOST_CXXFLAGS}" )
        set( CXXFLAGS_FILE_PATH ${TARGET_INSTALL_DIR}/boost-cxxflags )
        file( WRITE ${CXXFLAGS_FILE_PATH} ${CXXFLAGS_STRING} )

        ## Modules Check
        string( REPLACE ";" " " MODULES_STRING "${BOOST_MODULES}" )
        set( MODULES_FILE_PATH ${TARGET_INSTALL_DIR}/boost-modules )
        file( WRITE ${MODULES_FILE_PATH} ${MODULES_STRING} )

        execute_process( COMMAND ${CMAKE_COMMAND} -E make_directory ${BOOST_SOURCE_DIR} )

        ### This is key
        ### A dependency that is never satisfied drives the next command to always check if Boost is up-to-date
        ### without needing add_custom_target. It is marked symbolic so it doesn't add restat=1 to build.ninja
        set( CMAKE_RUN ${BOOST_SOURCE_DIR}/cmake_run.txt )
        add_custom_command( OUTPUT ${CMAKE_RUN} COMMAND true
                COMMENT "Starting Boost build for ${BOOST_TARGET}" )
        set_source_files_properties( ${CMAKE_RUN} PROPERTIES SYMBOLIC true )

        set( BOOST_TARBALL_PATH ${BOOST_SOURCE_DIR}/${BOOST_TARBALL} )
        set( TIME_CONDITION )
        if( EXISTS ${BOOST_TARBALL_PATH} )
            set( TIME_CONDITION --time-cond ${BOOST_TARBALL_PATH} )
        endif()

        ### Download the tarball if it has changed using the current copy for the timestamp
        add_custom_command( OUTPUT ${BOOST_TARBALL_PATH}
                WORKING_DIRECTORY ${BOOST_SOURCE_DIR}
                DEPENDS ${CMAKE_RUN}
                COMMAND curl ${TIME_CONDITION} -o ${BOOST_TARBALL_PATH} --silent --location ${BOOST_URL}
                COMMENT "Downloading Boost source, if needed, for ${BOOST_TARGET}" )

        ### Untar and build
        add_custom_command(
                OUTPUT
                    ${BOOST_STATIC_LIBS_${TARGET_ARCHITECTURE}}
                    ${BOOST_SHARED_LIBS_${TARGET_ARCHITECTURE}}
                DEPENDS ${BOOST_TARBALL_PATH}
                WORKING_DIRECTORY ${BOOST_SOURCE_DIR}
                COMMAND tar xfz ${BOOST_TARBALL_PATH} --strip-components 1 -C ${BOOST_SOURCE_DIR}
                COMMAND ${BOOST_SCRIPTS_DIR}/boost-compile.sh
                    ${SDK}
                    ${TARGET_ARCHITECTURE}
                    ${BOOST_SOURCE_DIR}
                    ${TARGET_INSTALL_DIR}
                    ${CXXFLAGS_FILE_PATH}
                    ${MODULES_FILE_PATH} )
    endforeach( TARGET_ARCHITECTURE )


    set( INSTALL_DIR_LIB ${INSTALL_DIR}/lib )
    set( INSTALL_DIR_INCLUDE ${INSTALL_DIR}/include )
    foreach( BOOST_MODULE ${BOOST_MODULES} )
        #        set( BOOST_THIN_${BOOST_MODULE}_STATIC_LIBS_${SDK} )
        ## Set up the name for the modules to be built libboost_filesystem.a for example
        set( BOOST_${BOOST_MODULE}_STATIC_LIB ${CMAKE_STATIC_LIBRARY_PREFIX}boost_${BOOST_MODULE}${CMAKE_STATIC_LIBRARY_SUFFIX} )
        list( APPEND BOOST_STATIC_LIBS_${SDK} ${INSTALL_DIR_LIB}/${BOOST_${BOOST_MODULE}_STATIC_LIB} )
        if( BUILD_SHARED )
            #            set( BOOST_THIN_${BOOST_MODULE}_SHARED_LIBS_${SDK} )
            set( BOOST_${BOOST_MODULE}_SHARED_LIB ${CMAKE_SHARED_LIBRARY_PREFIX}boost_${BOOST_MODULE}${CMAKE_SHARED_LIBRARY_SUFFIX} )
            list( APPEND BOOST_SHARED_LIBS_${SDK} ${INSTALL_DIR_LIB}/${BOOST_${BOOST_MODULE}_SHARED_LIB} )
        endif()
    endforeach( BOOST_MODULE )

    foreach( BOOST_MODULE ${BOOST_MODULES} )
        set( ${BOOST_MODULE}_INSTALL_PATH ${INSTALL_DIR_LIB}/${BOOST_MODULE_STATIC} )
        Lipo( INPUTS ${${BOOST_MODULE}_STATIC_LIBS} OUTPUT ${${BOOST_MODULE}_INSTALL_PATH} )

        if( BUILD_SHARED )
            set( INSTALL_PATH_SSL_SHARED ${INSTALL_DIR_LIB}/${OPENSSL_LIBSSL_SHARED} )
            Lipo( INPUTS ${OPENSSL_THIN_SSL_SHARED_LIBS_${SDK}} OUTPUT ${INSTALL_PATH_SSL_SHARED} )
        endif()
    endif()

    list( GET BOOST_INCLUDES_${SDK} 0 BOOST_INCLUDES_DIR )
    set( BOOST_INCLUDES_STAMP ${INSTALL_DIR}/boost_include.stamp)
    add_custom_command( OUTPUT ${BOOST_INCLUDES_STAMP}
            DEPENDS
                ${BOOST_STATIC_LIBS}
                ${BOOST_SHARED_LIBS}
            COMMAND ${CMAKE_COMMAND} -E copy_directory ${BOOST_INCLUDES_DIR} ${INSTALL_DIR_INCLUDE}
            COMMAND touch ${BOOST_INCLUDES_STAMP}
            COMMENT "Copying Boost ${BOOST_INCLUDES_DIR} to ${INSTALL_DIR_INCLUDE}" )

    set( BOOST_TARGET_${SDK} copy_boost_includes_${SDK} PARENT_SCOPE )

endfunction( BuildBoost )