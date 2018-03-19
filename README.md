## Building Boost for iOS

I've seen a number of solutions to getting Boost built for iOS. I wanted a simple, standalone way of getting an Boost library into an Xcode project without downloading pre-built binaries or adopting a dependency manager like Hunter.

Furthermore, getting CMake to not suck is pretty hard when it comes to building things outside of CMake's control. I had to go to a great amount of trouble to compile Boost only when it updates, and check the servers each time. Generally speaking this means you cannot use anything but `add_custom_command` because the second you use ExternalProject_add or add_custom_target you end up with some undesirable features like always downloading and compiling.

If you want to reduce the number of architectures built you can define the `BOOST_TARGET_ARCHITECTURES_${SDK}` variables and list the specific architectures that should be built for each. 


### CMakeLists.txt

    set( BOOST_TARGET_ARCHITECTURES_iphoneos arm64 )
    set( BOOST_TARGET_ARCHITECTURES_iphonesimulator x86_64 )


### boost.cmake

You can adjust the version of Boost built and define a SHA1 checksum with these variables

    set( BOOST_URL "http://www.openssl.org/source/boost-1_63_0.tar.bz2" )
    set( BOOST_SHA1 "" )


### Build Boost Latest

  1. Checkout to boost/ 
  2. mkdir boost-build/
  3. cd boost-build/
  4. cmake -GNinja ../boost
  5. cmake --build .
