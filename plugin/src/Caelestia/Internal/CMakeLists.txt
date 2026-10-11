qml_module(caelestia-internal
    URI Caelestia.Internal
    INCLUDE_PREFIX internal
    SOURCES
        compositor/backend.hpp
        compositor/detect.hpp compositor/detect.cpp
        compositor/platform.hpp compositor/platform.cpp
        compositor/niri/niri_backend.hpp compositor/niri/niri_backend.cpp
        compositor/niri/nirisocket.hpp compositor/niri/nirisocket.cpp
        compositor/umbriel/umbriel_backend.hpp compositor/umbriel/umbriel_backend.cpp
        compositor/umbriel/umbrielsocket.hpp compositor/umbriel/umbrielsocket.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        Qt::Network
        caelestia-config
    DEPENDENCIES
        Caelestia.Config
)

# qmltyperegistrar emits __has_include(<basename.hpp>) for the QML type header;
# ours lives in compositor/, so put that dir on the include path.
target_include_directories(caelestia-internal PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/compositor")
