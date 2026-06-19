# webkit-haskell

A lightweight Haskell framework for building native macOS desktop apps with WebKit (WKWebView), ported from Common Lisp `webkit-cl` and Rust `webkit-rust`.

Your Haskell code controls the native window, registers command handlers, and communicates with the web UI through a bidirectional, JSON-based message-passing bridge.

## Haskell Concepts Covered

| Concept | Description |
|---------|-------------|
| **C FFI (Foreign Function Interface)** | Importing compiled C/Objective-C functions (`foreign import ccall`) |
| **Haskell FunPtr Wrappers** | Creating dynamic function pointers using FFI wrapper stubs for event callbacks |
| **Stable Pointers (`StablePtr`)** | Passing references to Haskell data structures to C and back safely |
| **State Management** | Sharing and updating application state using `IORef` variables |
| **JSON Serialization** | Parsing and encoding message payloads using the `Data.Aeson` library |
| **Exception Handling** | Protecting the Cocoa main thread by catching Haskell exceptions inside handlers |
| **Cabal Compilation** | Compiling Objective-C files (`cc-options`) and linking system frameworks (`frameworks`) |

## API Reference

| Haskell Function | Description |
|------------------|-------------|
| `newWebKitApp title width height` | Initialize Cocoa application window and `WKWebView` |
| `runWebKitApp app` | Start the event runloop (blocks the main thread) |
| `quitWebKitApp app` | Request the application to quit |
| `destroyWebKitApp app` | Free internal FFI callbacks and stable pointers |
| `loadHTML app html` | Load inline HTML string |
| `loadURL app url` | Navigate WebView to a URL (http, https, file) |
| `loadFile app path` | Load local HTML file |
| `evalJS app js` | Run JavaScript in WebView context (fire-and-forget) |
| `setTitle app title` | Change the window title |
| `setSize app width height` | Resize the window |
| `setResizable app resizable` | Toggle window resizability |
| `registerHandler app command handler` | Register a JS callback message handler closure |

## Setup & Running Examples

This library only runs on **macOS** and compiles the Objective-C source file using the system `clang` compiler linked through Cabal/GHC.

To build the library and all examples:
```bash
cabal build
```

To run the simple Hello World example:
```bash
cabal run webkit-hello-world
```

To run the Counter bridge app:
```bash
cabal run webkit-counter-app
```

To run the Markdown Viewer (file-system bridge app):
```bash
cabal run webkit-markdown-viewer
```

## Source

Ported from [loving-common-lisp/src/webkit-cl](https://github.com/mark-watson/loving-common-lisp) and [webkit-rust](file:///Users/markwatson/GITHUB/rust_experiments/webkit-rust).

## License

Copyright Mark Watson. Apache 2 License.
