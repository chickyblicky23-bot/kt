cmake_minimum_required(VERSION 3.21)
project(KeyTrainer VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(KeyTrainer main.cpp)
set_target_properties(KeyTrainer PROPERTIES WIN32_EXECUTABLE TRUE)

qt_add_qml_module(KeyTrainer
    URI KeyTrainer
    VERSION 1.0
    QML_FILES qml/Main.qml
)

target_link_libraries(KeyTrainer PRIVATE Qt6::Quick)
