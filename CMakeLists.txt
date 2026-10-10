cmake_minimum_required(VERSION 3.22)

project(Rimution VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt 6.4 is the baseline available on the Ubuntu 24.04 CI runner.
find_package(Qt6 6.4 REQUIRED COMPONENTS Quick Qml QuickControls2 Multimedia)
qt_standard_project_setup(REQUIRES 6.4)

qt_add_executable(rimution
    src/main.cpp
    src/app/ProjectController.cpp
    src/app/ProjectController.h
    src/app/MediaController.cpp
    src/app/MediaController.h
)

set_source_files_properties(src/ui/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)
qt_add_qml_module(rimution
    URI Rimution
    VERSION 1.0
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES
        src/ui/Main.qml
)

target_link_libraries(rimution PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::Multimedia
)

target_compile_options(rimution PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>
)

install(TARGETS rimution RUNTIME DESTINATION bin)
