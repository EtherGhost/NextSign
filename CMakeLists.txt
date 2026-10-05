cmake_minimum_required(VERSION 3.0.0)
project(nextsign C CXX)

set(CMAKE_AUTOMOC ON)

find_package(Qt5Core REQUIRED)
find_package(Qt5Gui REQUIRED)
find_package(Qt5Network REQUIRED)
find_package(Qt5Qml REQUIRED)
find_package(Qt5Quick REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(POPPLERQT5 REQUIRED poppler-qt5)

set(PROJECT_NAME "nextsign")
set(FULL_PROJECT_NAME "nextsign.cloudsite")
set(NEXTSIGN_VERSION "0.4.0")
set(DATA_DIR /)
set(DESKTOP_FILE_NAME ${PROJECT_NAME}.desktop)

configure_file(manifest.json.in ${CMAKE_CURRENT_BINARY_DIR}/manifest.json @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/manifest.json DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES ${PROJECT_NAME}.apparmor DESTINATION ${DATA_DIR})
install(FILES ${PROJECT_NAME}.accounts DESTINATION ${DATA_DIR})
install(FILES ${PROJECT_NAME}-contenthub.json DESTINATION ${DATA_DIR})
install(FILES assets/logo.svg DESTINATION assets)

qt5_add_resources(QT_RESOURCES qml/qml.qrc assets/assets.qrc)

add_executable(${PROJECT_NAME}
    main.cpp
    DocumentDownloader.cpp
    DocumentDownloader.h
    LibreSignNetwork.cpp
    LibreSignNetwork.h
    SignatureImageEncoder.cpp
    SignatureImageEncoder.h
    DocumentFileEncoder.cpp
    DocumentFileEncoder.h
    PdfPageRenderer.cpp
    PdfPageRenderer.h
    ${QT_RESOURCES}
)
set_target_properties(${PROJECT_NAME} PROPERTIES LINK_FLAGS_RELEASE -s)
target_compile_definitions(${PROJECT_NAME} PRIVATE NEXTSIGN_VERSION="${NEXTSIGN_VERSION}")
target_include_directories(${PROJECT_NAME} PRIVATE ${POPPLERQT5_INCLUDE_DIRS})
target_link_libraries(${PROJECT_NAME} Qt5::Core Qt5::Gui Qt5::Network Qt5::Qml Qt5::Quick ${POPPLERQT5_LIBRARIES})
install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX})

configure_file(${DESKTOP_FILE_NAME}.in ${CMAKE_CURRENT_BINARY_DIR}/${DESKTOP_FILE_NAME})
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${DESKTOP_FILE_NAME} DESTINATION ${DATA_DIR})

file(GLOB_RECURSE I18N_SRC_FILES
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    qml/*.qml
    qml/*.js
    vendor/NextCommon/qml/NextCommon/*.qml
    vendor/NextCommon/js/*.js
    vendor/UTControls/qml/UTControls/*.qml
    *.cpp
    *.h
)

add_subdirectory(po)

file(GLOB_RECURSE PROJECT_SRC_FILES
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    qml/*.qml
    qml/*.js
    vendor/NextCommon/qml/NextCommon/*.qml
    vendor/NextCommon/js/*.js
    assets/*
    *.json
    *.json.in
    *.apparmor
    *.accounts
    *-contenthub.json
    *.desktop.in
    *.yaml
    po/*.po
    po/*.pot
    main.cpp
    DocumentDownloader.cpp
    DocumentDownloader.h
    LibreSignNetwork.cpp
    LibreSignNetwork.h
    SignatureImageEncoder.cpp
    SignatureImageEncoder.h
    DocumentFileEncoder.cpp
    DocumentFileEncoder.h
    PdfPageRenderer.cpp
    PdfPageRenderer.h
)

add_custom_target(${PROJECT_NAME}_FILES ALL SOURCES ${PROJECT_SRC_FILES})
