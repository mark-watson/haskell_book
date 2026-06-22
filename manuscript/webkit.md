# Native macOS GUI Applications with WebKit and Haskell FFI

Building graphical user interfaces (GUIs) in Haskell has historically been a challenging endeavor. While toolkits like GTK (via `gi-gtk`) or wxHaskell exist, they often require heavy dependencies, complex installations, and extensive boilerplate code. Another popular modern alternative is Electron, but it packages a complete Chromium browser, resulting in massive binary sizes and heavy memory footprints.

In this chapter, we explore a lightweight alternative: **webkit-haskell** (ported from Common Lisp's `webkit-cl` and Rust's `webkit-rust`). This framework allows you to build native macOS desktop applications using the operating system's built-in WebKit engine (`WKWebView`). 

By embedding WebKit, we can design beautiful, modern, responsive user interfaces using standard web technologies (HTML, CSS, and JavaScript) while keeping the application backend logic entirely in Haskell. Communication between the JavaScript front-end and the Haskell back-end is performed bidirectionally through a fast, JSON-based message-passing bridge.

The code for this project is located in the directory **haskell_book/source-code/webkit-haskell**.

---

## The FFI Architecture

Haskell's Foreign Function Interface (FFI) is natively designed to interoperate with C. Interfacing directly with Objective-C classes and methods (such as Cocoa's `NSWindow` or WebKit's `WKWebView`) is difficult because Objective-C is a dynamic language that relies on message passing via `objc_msgSend`.

To bridge this gap, we implement a thin **C wrapper** in Objective-C. This wrapper exposes a flat C API that Haskell's `foreign import ccall` can easily invoke.

```
+-------------------------------------------------------+
|                 JavaScript Web UI                     |
|        (window.webkit_haskell.invoke(cmd, arg))       |
+---------------------------+---------------------------+
                            |
                            v (WKScriptMessageHandler)
+-------------------------------------------------------+
|              Objective-C Wrapper (C API)              |
|        - Creates NSWindow & WKWebView                 |
|        - Implements Flat C function pointers          |
+---------------------------+---------------------------+
                            |
                            v (Haskell FunPtr Callback)
+-------------------------------------------------------+
|                  Haskell FFI Module                   |
|        - Decodes/encodes payloads using Aeson         |
|        - Looks up command handers in IORef map        |
+-------------------------------------------------------+
```

### Key FFI Concepts

1. **Stable Pointers (`StablePtr`)**: GHC manages Haskell objects in a garbage-collected heap and may move them during GC cycles. A `StablePtr` is a stable reference to a Haskell value that GHC guarantees will not move, allowing us to safely pass it to the C/Objective-C side as `userdata`.
2. **FunPtr Wrappers**: To allow the C side to call a Haskell function, GHC provides a `wrapper` generator that marshals a Haskell function into a C-compatible function pointer (`FunPtr`).
3. **Memory Handoff (Malloc/Free)**: Strings returned by Haskell callbacks to C are allocated on the standard C heap via GHC's FFI `newCString` (which calls standard `malloc`). The Objective-C code takes ownership of the string and calls C's `free()` after converting it to an Objective-C `NSString`.
4. **Exception Shielding**: Exceptions in Haskell callbacks are caught using `Control.Exception.catch` and returned as a JSON error object, preventing Haskell panics from crashing the macOS GUI thread.

---

## The C Interface: `webkit_haskell.h`

The header file defines the flat C interface exported by the Objective-C wrapper.

```c
/* webkit_haskell.h — C API for webkit-haskell */

#ifndef WEBKIT_HASKELL_H
#define WEBKIT_HASKELL_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void* wkhsk_app_t;

/* Callback type for bridge invocations from JavaScript */
typedef const char* (*wkhsk_bridge_callback_t)(const char* command,
                                               const char* payload,
                                               void* userdata);

/* Lifecycle */
wkhsk_app_t wkhsk_create(const char* title, int width, int height);
void wkhsk_run(wkhsk_app_t app);
void wkhsk_quit(wkhsk_app_t app);
void wkhsk_destroy(wkhsk_app_t app);

/* Content Loading */
void wkhsk_load_html(wkhsk_app_t app, const char* html);
void wkhsk_load_url(wkhsk_app_t app, const char* url);
void wkhsk_load_file(wkhsk_app_t app, const char* path);

/* JavaScript */
void wkhsk_eval_js(wkhsk_app_t app, const char* js);

/* Bridge */
void wkhsk_set_bridge_callback(wkhsk_app_t app,
                               wkhsk_bridge_callback_t callback,
                               void* userdata);

/* Window Management */
void wkhsk_set_title(wkhsk_app_t app, const char* title);
void wkhsk_set_size(wkhsk_app_t app, int width, int height);
void wkhsk_set_resizable(wkhsk_app_t app, int resizable);

#ifdef __cplusplus
}
#endif

#endif /* WEBKIT_HASKELL_H */
```

On the implementation side in `webkit_haskell.m`, Cocoa initializes a standard macOS application runloop (`[nsApp run]`), creates an `NSWindow` and a `WKWebView`, and injects a script into the browser context to establish `window.webkit_haskell.invoke`. When JavaScript calls this method, the message is serialized to JSON and passed to the registered Haskell callback.

---

## The Haskell FFI Wrapper: `WebKitHaskell.hs`

The Haskell wrapper handles the raw foreign function imports, manages the callback lifecycle, and handles the marshalling of JSON strings using `Data.Aeson`.

```haskell
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module WebKitHaskell
  ( WebKitApp
  , newWebKitApp
  , runWebKitApp
  , quitWebKitApp
  , destroyWebKitApp
  , loadHTML
  , loadURL
  , loadFile
  , evalJS
  , setTitle
  , setSize
  , setResizable
  , registerHandler
  ) where

import Foreign
import Foreign.C.String
import Foreign.C.Types
import Foreign.StablePtr
import Data.IORef
import qualified Data.Map.Strict as Map
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy.Char8 as LBS
import Control.Exception (catch, SomeException)

-- ---------------------------------------------------------------------------
-- Native FFI Declarations
-- ---------------------------------------------------------------------------

foreign import ccall unsafe "wkhsk_create"
  c_wkhsk_create :: CString -> CInt -> CInt -> IO (Ptr ())

foreign import ccall safe "wkhsk_run"
  c_wkhsk_run :: Ptr () -> IO ()

foreign import ccall unsafe "wkhsk_quit"
  c_wkhsk_quit :: Ptr () -> IO ()

foreign import ccall unsafe "wkhsk_destroy"
  c_wkhsk_destroy :: Ptr () -> IO ()

foreign import ccall unsafe "wkhsk_load_html"
  c_wkhsk_load_html :: Ptr () -> CString -> IO ()

foreign import ccall unsafe "wkhsk_load_url"
  c_wkhsk_load_url :: Ptr () -> CString -> IO ()

foreign import ccall unsafe "wkhsk_load_file"
  c_wkhsk_load_file :: Ptr () -> CString -> IO ()

foreign import ccall unsafe "wkhsk_eval_js"
  c_wkhsk_eval_js :: Ptr () -> CString -> IO ()

foreign import ccall unsafe "wkhsk_set_bridge_callback"
  c_wkhsk_set_bridge_callback :: Ptr () -> FunPtr BridgeCallback -> Ptr () -> IO ()

foreign import ccall unsafe "wkhsk_set_title"
  c_wkhsk_set_title :: Ptr () -> CString -> IO ()

foreign import ccall unsafe "wkhsk_set_size"
  c_wkhsk_set_size :: Ptr () -> CInt -> CInt -> IO ()

foreign import ccall unsafe "wkhsk_set_resizable"
  c_wkhsk_set_resizable :: Ptr () -> CInt -> IO ()

-- ---------------------------------------------------------------------------
-- Dynamic Callback Marshaller
-- ---------------------------------------------------------------------------

type BridgeCallback = CString -> CString -> Ptr () -> IO CString

foreign import ccall "wrapper"
  makeBridgeCallback :: BridgeCallback -> IO (FunPtr BridgeCallback)

-- ---------------------------------------------------------------------------
-- Haskell WebKitApp Type
-- ---------------------------------------------------------------------------

type Handlers = Map.Map String (Aeson.Value -> IO Aeson.Value)

data WebKitApp = WebKitApp
  { appHandle          :: Ptr ()
  , appHandlers        :: IORef Handlers
  , appStablePtr       :: StablePtr (IORef Handlers)
  , appCallbackFunPtr  :: FunPtr BridgeCallback
  }

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

newWebKitApp :: String -> Int -> Int -> IO WebKitApp
newWebKitApp title width height = do
  cTitle <- newCString title
  handle <- c_wkhsk_create cTitle (fromIntegral width) (fromIntegral height)
  free cTitle
  if handle == nullPtr
    then error "Failed to create native Cocoa/WebKit window"
    else do
      handlersRef <- newIORef Map.empty
      stablePtr <- newStablePtr handlersRef
      
      -- Create the dynamic callback function pointer referencing bridgeDispatch
      callbackFunPtr <- makeBridgeCallback (bridgeDispatch stablePtr)
      
      -- Connect the callback on the C side, passing stablePtr as userdata
      c_wkhsk_set_bridge_callback handle callbackFunPtr (castStablePtrToPtr stablePtr)
      
      return $ WebKitApp handle handlersRef stablePtr callbackFunPtr

runWebKitApp :: WebKitApp -> IO ()
runWebKitApp app = c_wkhsk_run (appHandle app)

quitWebKitApp :: WebKitApp -> IO ()
quitWebKitApp app = c_wkhsk_quit (appHandle app)

destroyWebKitApp :: WebKitApp -> IO ()
destroyWebKitApp app = do
  c_wkhsk_destroy (appHandle app)
  freeHaskellFunPtr (appCallbackFunPtr app)
  freeStablePtr (appStablePtr app)

loadHTML :: WebKitApp -> String -> IO ()
loadHTML app html = do
  cHtml <- newCString html
  c_wkhsk_load_html (appHandle app) cHtml
  free cHtml

loadURL :: WebKitApp -> String -> IO ()
loadURL app url = do
  cUrl <- newCString url
  c_wkhsk_load_url (appHandle app) cUrl
  free cUrl

loadFile :: WebKitApp -> String -> IO ()
loadFile app path = do
  cPath <- newCString path
  c_wkhsk_load_file (appHandle app) cPath
  free cPath

evalJS :: WebKitApp -> String -> IO ()
evalJS app js = do
  cJs <- newCString js
  c_wkhsk_eval_js (appHandle app) cJs
  free cJs

setTitle :: WebKitApp -> String -> IO ()
setTitle app title = do
  cTitle <- newCString title
  c_wkhsk_set_title (appHandle app) cTitle
  free cTitle

setSize :: WebKitApp -> Int -> Int -> IO ()
setSize app width height =
  c_wkhsk_set_size (appHandle app) (fromIntegral width) (fromIntegral height)

setResizable :: WebKitApp -> Bool -> IO ()
setResizable app resizable =
  c_wkhsk_set_resizable (appHandle app) (if resizable then 1 else 0)

registerHandler :: WebKitApp -> String -> (Aeson.Value -> IO Aeson.Value) -> IO ()
registerHandler app command handler =
  modifyIORef' (appHandlers app) (Map.insert command handler)

-- ---------------------------------------------------------------------------
-- Private Dispatcher
-- ---------------------------------------------------------------------------

bridgeDispatch :: StablePtr (IORef Handlers) -> CString -> CString -> Ptr () -> IO CString
bridgeDispatch stablePtr cmdPtr payloadPtr _ = do
  handlersRef <- deRefStablePtr stablePtr
  cmd <- peekCString cmdPtr
  payloadStr <- peekCString payloadPtr
  
  -- Decode payload as JSON
  let payloadJson = case Aeson.decode (LBS.pack payloadStr) of
                      Just val -> val
                      Nothing  -> Aeson.Null
  
  handlers <- readIORef handlersRef
  resultJson <- case Map.lookup cmd handlers of
    Just handler ->
      catch (handler payloadJson)
            (\(e :: SomeException) -> return $ Aeson.object ["error" Aeson..= show e])
    Nothing ->
      return $ Aeson.object ["error" Aeson..= ("Unknown command: " ++ cmd)]
      
  -- Encode response to JSON and allocate a standard C string to pass to C side
  let resultBytes = LBS.unpack (Aeson.encode resultJson)
  newCString resultBytes
```

### Explaining `bridgeDispatch`

* `deRefStablePtr` converts the pointer passed from Objective-C (`userdata`) back into a usable Haskell reference to our `IORef Handlers` map.
* `peekCString` reads the raw FFI C-string pointers (`cmdPtr`, `payloadPtr`) into standard Haskell `String` values.
* We lookup the command in the handlers map. If it exists, we run it and catch exceptions using `catch` to prevent any backend failure from terminating the native macOS loop.
* We encode the resulting `Aeson.Value` back into a JSON string and use `newCString` to allocate it as a raw C string. Because the Objective-C code calls `free()` on this pointer once it converts it to an `NSString`, this handoff avoids memory leaks.

---

## Cabal Build System Configuration

To compile Objective-C sources and correctly link macOS system frameworks, we write a simple Cabal description. The relevant portion of `webkit-haskell.cabal` looks like this:

```cabal
library
  exposed-modules:     WebKitHaskell
  build-depends:       base >= 4.7 && < 5
                     , aeson >= 1.0
                     , bytestring >= 0.10
                     , containers >= 0.6
                     , directory >= 1.3
                     , filepath >= 1.4
  hs-source-dirs:      src
  default-language:    Haskell2010
  ghc-options:         -Wall
  
  if os(darwin)
    c-sources:         cbits/webkit_haskell.m
    include-dirs:      cbits
    cc-options:        -fobjc-arc
    frameworks:        Cocoa WebKit
```

The `frameworks` attribute instructs GHC to link the platform-native libraries `Cocoa` and `WebKit`, while `cc-options: -fobjc-arc` compiles the Objective-C source using Apple's Automatic Reference Counting memory model.

---

## Example 1: Hello World

The Hello World application demonstrates how to initialize a native window, inject CSS for a modern, glassmorphic card design, and launch the event loop.

### Code Walkthrough (`examples/HelloWorld.hs`)

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Main where

import WebKitHaskell

main :: IO ()
main = do
  putStrLn "Starting webkit-haskell Hello World example..."

  -- Create a 600x400 window
  app <- newWebKitApp "Hello webkit-haskell" 600 400

  -- Beautiful inline HTML styled with glassmorphism and modern gradients
  let html = "<!DOCTYPE html>\
\<html>\
\<head>\
\<meta charset='utf-8'>\
\<style>\
\  * { margin: 0; padding: 0; box-sizing: border-box; }\
\  body {\
\    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;\
\    background: linear-gradient(135deg, #0f0c29 0%, #302b63 50%, #24243e 100%);\
\    color: #e0e0e0;\
\    display: flex;\
\    align-items: center;\
\    justify-content: center;\
\    height: 100vh;\
\    overflow: hidden;\
\  }\
\  .card {\
\    text-align: center;\
\    background: rgba(255,255,255,0.05);\
\    backdrop-filter: blur(20px);\
\    -webkit-backdrop-filter: blur(20px);\
\    border: 1px solid rgba(255,255,255,0.1);\
\    border-radius: 24px;\
\    padding: 48px 64px;\
\    box-shadow: 0 8px 32px rgba(0,0,0,0.3);\
\    animation: fadeIn 0.8s ease-out;\
\  }\
\  @keyframes fadeIn {\
\    from { opacity: 0; transform: translateY(20px) scale(0.95); }\
\    to   { opacity: 1; transform: translateY(0) scale(1); }\
\  }\
\  h1 {\
\    font-size: 2.5em;\
\    font-weight: 700;\
\    background: linear-gradient(90deg, #a78bfa, #60a5fa, #34d399);\
\    -webkit-background-clip: text;\
\    -webkit-text-fill-color: transparent;\
\    margin-bottom: 12px;\
\  }\
\  p {\
\    font-size: 1.1em;\
\    color: rgba(255,255,255,0.6);\
\    line-height: 1.6;\
\  }\
\  .badge {\
\    display: inline-block;\
\    margin-top: 20px;\
\    padding: 6px 16px;\
\    font-size: 0.85em;\
\    background: rgba(167,139,250,0.15);\
\    border: 1px solid rgba(167,139,250,0.3);\
\    border-radius: 999px;\
\    color: #a78bfa;\
\  }\
\</style>\
\</head>\
\<body>\
\  <div class='card'>\
\    <h1>Hello, webkit-haskell!</h1>\
\    <p>A native macOS window powered by Haskell<br>\
\       and WebKit (WKWebView).</p>\
\    <span class='badge'>Haskell + Cocoa + WebKit</span>\
\  </div>\
\</body>\
\</html>"

  -- Load the HTML string directly into the WebView
  loadHTML app html

  -- Run the Cocoa event loop (blocks main thread)
  runWebKitApp app

  -- Clean up resources when terminated
  destroyWebKitApp app
  putStrLn "App loop terminated successfully."
```

### Running the Example

Compile and run the Hello World executable using Cabal:

```bash
cabal run webkit-hello-world
```

This starts the application, opening a styled macOS window displaying the greeting card. Closing the window automatically terminates the process.

---

## Example 2: Stateful Counter App

This example goes a step further by implementing a stateful, interactive counter showing bidirectional messaging. The frontend user interface contains buttons that trigger functions on the Haskell backend, updating a counter value stored in a stateful Haskell variable.

### Code Walkthrough (`examples/CounterApp.hs`)

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Main where

import WebKitHaskell
import Data.IORef
import qualified Data.Aeson as Aeson
import qualified System.Info as SysInfo

main :: IO ()
main = do
  putStrLn "Starting webkit-haskell Counter App bridge example..."

  -- Create the window
  app <- newWebKitApp "Counter — webkit-haskell" 500 520

  -- Create mutable counter state using IORef
  counterRef <- newIORef (0 :: Int)

  -- Register bridge handlers
  registerHandler app "increment" $ \_payload -> do
    modifyIORef' counterRef (+ 1)
    val <- readIORef counterRef
    putStrLn $ "[Haskell] Handler 'increment' called. New count = " ++ show val
    return $ Aeson.object ["count" Aeson..= val]

  registerHandler app "decrement" $ \_payload -> do
    modifyIORef' counterRef (\x -> x - 1)
    val <- readIORef counterRef
    putStrLn $ "[Haskell] Handler 'decrement' called. New count = " ++ show val
    return $ Aeson.object ["count" Aeson..= val]

  registerHandler app "reset" $ \_payload -> do
    writeIORef counterRef 0
    putStrLn "[Haskell] Handler 'reset' called. Count reset to 0"
    return $ Aeson.object ["count" Aeson..= (0 :: Int)]

  registerHandler app "get-count" $ \_payload -> do
    val <- readIORef counterRef
    return $ Aeson.object ["count" Aeson..= val]

  registerHandler app "get-system-info" $ \_payload -> do
    putStrLn "[Haskell] Handler 'get-system-info' called."
    return $ Aeson.object
      [ "language" Aeson..= ("Haskell" :: String)
      , "version"  Aeson..= ("0.1.0" :: String)
      , "os"       Aeson..= SysInfo.os
      , "arch"     Aeson..= SysInfo.arch
      ]

  -- Beautiful UI with interactive counter controls
  let html = "<!DOCTYPE html>\
\<html>\
\<head>\
\<meta charset='utf-8'>\
\<style>\
\  * { margin: 0; padding: 0; box-sizing: border-box; }\
\  body {\
\    font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;\
\    background: #0a0a0a;\
\    color: #fafafa;\
\    display: flex;\
\    flex-direction: column;\
\    align-items: center;\
\    justify-content: center;\
\    height: 100vh;\
\    gap: 32px;\
\    user-select: none;\
\    -webkit-user-select: none;\
\  }\
\  .counter-display {\
\    font-size: 6rem;\
\    font-weight: 800;\
\    font-variant-numeric: tabular-nums;\
\    letter-spacing: -4px;\
\    background: linear-gradient(180deg, #fff 0%, rgba(255,255,255,0.5) 100%);\
\    -webkit-background-clip: text;\
\    -webkit-text-fill-color: transparent;\
\    transition: transform 0.15s ease;\
\    min-width: 200px;\
\    text-align: center;\
\  }\
\  .counter-display.bump {\
\    transform: scale(1.1);\
\  }\
\  .controls {\
\    display: flex;\
\    gap: 12px;\
\  }\
\  button {\
\    font-size: 1.1rem;\
\    font-weight: 600;\
\    padding: 12px 28px;\
\    border: none;\
\    border-radius: 12px;\
\    cursor: pointer;\
\    transition: all 0.2s ease;\
\    font-family: inherit;\
\  }\
\  button:active {\
\    transform: scale(0.95);\
\  }\
\  .btn-primary {\
\    background: linear-gradient(135deg, #7c3aed, #a855f7);\
\    color: white;\
\    box-shadow: 0 4px 14px rgba(124,58,237,0.4);\
\  }\
\  .btn-primary:hover {\
\    box-shadow: 0 6px 20px rgba(124,58,237,0.6);\
\    transform: translateY(-1px);\
\  }\
\  .btn-primary:active {\
\    transform: scale(0.95) translateY(0);\
\  }\
\  .btn-danger {\
\    background: linear-gradient(135deg, #dc2626, #ef4444);\
\    color: white;\
\    box-shadow: 0 4px 14px rgba(220,38,38,0.3);\
\  }\
\  .btn-danger:hover {\
\    box-shadow: 0 6px 20px rgba(220,38,38,0.5);\
\    transform: translateY(-1px);\
\  }\
\  .btn-secondary {\
\    background: rgba(255,255,255,0.08);\
\    color: rgba(255,255,255,0.7);\
\    border: 1px solid rgba(255,255,255,0.1);\
\  }\
\  .btn-secondary:hover {\
\    background: rgba(255,255,255,0.12);\
\    color: white;\
\  }\
\  .info {\
\    font-size: 0.8rem;\
\    color: rgba(255,255,255,0.3);\
\    text-align: center;\
\    line-height: 1.6;\
\  }\
\  .info span {\
\    color: rgba(255,255,255,0.5);\
\  }\
\  h2 {\
\    font-size: 0.9rem;\
\    font-weight: 500;\
\    color: rgba(255,255,255,0.4);\
\    letter-spacing: 3px;\
\    text-transform: uppercase;\
\  }\
\</style>\
\</head>\
\<body>\
\  <h2>Counter</h2>\
\  <div class='counter-display' id='counter'>0</div>\
\  <div class='controls'>\
\    <button class='btn-danger' onclick='decrement()'>− Minus</button>\
\    <button class='btn-secondary' onclick='reset()'>Reset</button>\
\    <button class='btn-primary' onclick='increment()'>+ Plus</button>\
\  </div>\
\  <div class='info' id='info'>Loading backend system info...</div>\
\  <script>\
\    const display = document.getElementById('counter');\
\    const info = document.getElementById('info');\
\    function updateDisplay(count) {\
\      display.textContent = count;\
\      display.classList.add('bump');\
\      setTimeout(() => display.classList.remove('bump'), 150);\
\    }\
\    async function fn_init() {\
\      try {\
\        const result = await window.webkit_haskell.invoke('get-count', {});\
\        updateDisplay(result.count);\
\        const sysInfo = await window.webkit_haskell.invoke('get-system-info', {});\
\        info.innerHTML =\
\          'Backend: <span>' + sysInfo.language + ' v' + sysInfo.version + '</span>' +\
\          '<br>Platform: <span>' + sysInfo.os + ' (' + sysInfo.arch + ')</span>';\
\      } catch(e) {\
\        info.textContent = 'JS ↔ Haskell bridge connection failed';\
\      }\
\    }\
\    async function increment() {\
\      const result = await window.webkit_haskell.invoke('increment', {});\
\      updateDisplay(result.count);\
\    }\
\    async function decrement() {\
\      const result = await window.webkit_haskell.invoke('decrement', {});\
\      updateDisplay(result.count);\
\    }\
\    async function reset() {\
\      const result = await window.webkit_haskell.invoke('reset', {});\
\      updateDisplay(result.count);\
\    }\
\    setTimeout(fn_init, 200);\
\  </script>\
\</body>\
\</html>"

  loadHTML app html
  runWebKitApp app
  destroyWebKitApp app
  putStrLn "App loop terminated successfully."
```

### Explaining the Bidirectional State

* In Haskell, we instantiate `counterRef` using `newIORef (0 :: Int)`.
* We register handlers for the commands `"increment"`, `"decrement"`, `"reset"`, and `"get-count"`.
* Each handler uses `modifyIORef'` or `writeIORef` to update the counter, reads the new value, prints a debug line on stdout, and yields a JSON object wrapping the result (`Aeson.object ["count" Aeson..= val]`).
* In the JavaScript frontend, the functions invoke these handlers asynchronously:
  ```javascript
  const result = await window.webkit_haskell.invoke('increment', {});
  updateDisplay(result.count);
  ```
  This returns a JS Promise that resolves to the decoded JSON object returned by our Haskell module.

### Running the Example

Run the Counter App via Cabal:

```bash
cabal run webkit-counter-app
```

Interact with the buttons. You will see both the counter value update in the visual display, and the debug log printing matching messages in your terminal.

---

## Example 3: Markdown Viewer

The final example shows how to bridge file system access, dynamically listing and reading local text files from the user's workspace, and displaying them in a split-pane layout.

### Code Walkthrough (`examples/MarkdownViewer.hs`)

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import WebKitHaskell
import GHC.Generics (Generic)
import System.Directory (listDirectory, doesFileExist, doesDirectoryExist)
import System.FilePath (takeExtension, (</>))
import Control.Monad (filterM)
import Control.Exception (catch, SomeException)
import qualified Data.Aeson as Aeson

-- Request payload structure for reading a file
newtype ReadFileRequest = ReadFileRequest
  { path :: String
  } deriving (Show, Generic)

instance Aeson.FromJSON ReadFileRequest

-- List markdown files in a directory
listMdFiles :: FilePath -> IO [FilePath]
listMdFiles dir = do
  exists <- doesDirectoryExist dir
  if not exists
    then return []
    else do
      entries <- listDirectory dir
      files <- filterM (\entry -> do
        let p = dir </> entry
        isFile <- doesFileExist p
        return (isFile && takeExtension p == ".md")
        ) entries
      return (map (dir </>) files)

main :: IO ()
main = do
  putStrLn "Starting webkit-haskell Markdown Viewer app..."

  -- Create a 900x700 window
  app <- newWebKitApp "Markdown Viewer — webkit-haskell" 900 700

  -- Register file listing handler
  registerHandler app "list-files" $ \_payload -> do
    let dir = "."
    putStrLn $ "[Haskell] Listing files in directory: " ++ dir
    currentFiles <- listMdFiles dir
    files <- if null currentFiles
               then do
                 putStrLn "[Haskell] No .md files in '.', checking 'webkit-haskell' subdirectory..."
                 listMdFiles "webkit-haskell"
               else return currentFiles

    return $ Aeson.object ["files" Aeson..= files]

  -- Register file reading handler
  registerHandler app "read-file" $ \payload -> do
    case Aeson.fromJSON payload of
      Aeson.Error err ->
        return $ Aeson.object ["error" Aeson..= ("Failed to parse request: " ++ err)]
      Aeson.Success (req :: ReadFileRequest) -> do
        let filePath = path req
        putStrLn $ "[Haskell] Reading file: " ++ filePath
        exists <- doesFileExist filePath
        if not exists
          then return $ Aeson.object ["error" Aeson..= ("File not found: " ++ filePath)]
          else do
            catch (do
              content <- readFile filePath
              return $ Aeson.object
                [ "content" Aeson..= content
                , "path" Aeson..= filePath
                ])
              (\(e :: SomeException) ->
                return $ Aeson.object ["error" Aeson..= show e])

  -- Beautiful UI with file selector sidebar and viewer pane
  let html = "<!DOCTYPE html>\
\<html>\
\<head>\
\<meta charset='utf-8'>\
\<style>\
\  * { margin: 0; padding: 0; box-sizing: border-box; }\
\  body {\
\    font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;\
\    background: #111;\
\    color: #e5e5e5;\
\    display: flex;\
\    height: 100vh;\
\  }\
\  .sidebar {\
\    width: 260px;\
\    min-width: 260px;\
\    background: #1a1a1a;\
\    border-right: 1px solid rgba(255,255,255,0.06);\
\    display: flex;\
\    flex-direction: column;\
\    overflow-y: auto;\
\  }\
\  .sidebar-header {\
\    padding: 20px 16px 12px;\
\    font-size: 0.75rem;\
\    font-weight: 600;\
\    letter-spacing: 2px;\
\    text-transform: uppercase;\
\    color: rgba(255,255,255,0.3);\
\  }\
\  .file-item {\
\    padding: 10px 16px;\
\    font-size: 0.9rem;\
\    cursor: pointer;\
\    color: rgba(255,255,255,0.6);\
\    transition: all 0.15s;\
\    border-left: 3px solid transparent;\
\  }\
\  .file-item:hover {\
\    background: rgba(255,255,255,0.04);\
\    color: white;\
\  }\
\  .file-item.active {\
\    background: rgba(124,58,237,0.1);\
\    color: #a78bfa;\
\    border-left-color: #7c3aed;\
\  }\
\  .file-item .name {\
\    font-weight: 500;\
\  }\
\  .file-item .path {\
\    font-size: 0.75rem;\
\    color: rgba(255,255,255,0.25);\
\    margin-top: 2px;\
\    white-space: nowrap;\
\    overflow: hidden;\
\    text-overflow: ellipsis;\
\  }\
\  .content {\
\    flex: 1;\
\    padding: 32px 48px;\
\    overflow-y: auto;\
\    font-size: 0.95rem;\
\    line-height: 1.7;\
\  }\
\  .content pre {\
\    background: rgba(255,255,255,0.04);\
\    border: 1px solid rgba(255,255,255,0.08);\
\    border-radius: 8px;\
\    padding: 16px 20px;\
\    overflow-x: auto;\
\    font-family: 'SF Mono', 'Fira Code', monospace;\
\    font-size: 0.85rem;\
\    white-space: pre-wrap;\
\    word-wrap: break-word;\
\    color: #c4b5fd;\
\  }\
\  .empty-state {\
\    display: flex;\
\    flex-direction: column;\
\    align-items: center;\
\    justify-content: center;\
\    height: 100%;\
\    color: rgba(255,255,255,0.2);\
\    font-size: 1.1rem;\
\    gap: 8px;\
\  }\
\  .empty-state .icon {\
\    font-size: 3rem;\
\    margin-bottom: 8px;\
\  }\
\</style>\
\</head>\
\<body>\
\  <div class='sidebar'>\
\    <div class='sidebar-header'>Markdown Files</div>\
\    <div id='file-list'>\
\      <div class='empty-state' style='height:200px;font-size:0.85rem;'>\
\        Loading workspace...\
\      </div>\
\    </div>\
\  </div>\
\  <div class='content' id='content'>\
\    <div class='empty-state'>\
\      <div class='icon'>📄</div>\
\      <div>Select a file to view</div>\
\      <div style='font-size:0.85rem;color:rgba(255,255,255,0.15)'>\
\        Markdown files fetched from the Haskell workspace filesystem\
\      </div>\
\    </div>\
\  </div>\
\  <script>\
\    const fileList = document.getElementById('file-list');\
\    const content = document.getElementById('content');\
\    function escapeHtml(str) {\
\      return str.replace(/&/g, '&amp;')\
\                .replace(/</g, '&lt;')\
\                .replace(/>/g, '&gt;');\
\    }\
\    function basename(path) {\
\      return path.split('/').pop().split('\\\\').pop();\
\    }\
\    async function loadFileList() {\
\      try {\
\        const result = await window.webkit_haskell.invoke('list-files', {});\
\        if (result.files && result.files.length > 0) {\
\          fileList.innerHTML = result.files.map(f => {\
\            const escapedPath = f.replace(/\\\\/g, '\\\\\\\\').replace(/'/g, \"\\\\'\");\
\            return '<div class=\"file-item\" onclick=\"loadFile(\\'' + escapedPath + '\\')\">' +\
\                   '<div class=\"name\">' + escapeHtml(basename(f)) + '</div>' +\
\                   '<div class=\"path\">' + escapeHtml(f) + '</div>' +\
\                   '</div>';\
\          }).join('');\
\        } else {\
\          fileList.innerHTML =\
\            '<div class=\"empty-state\" style=\"height:200px;font-size:0.85rem;\">' +\
\            'No .md files found</div>';\
\        }\
\      } catch(e) {\
\        fileList.innerHTML =\
\          '<div class=\"empty-state\" style=\"height:200px;font-size:0.85rem;\">' +\
\          'Error loading files: ' + e + '</div>';\
\      }\
\    }\
\    async function loadFile(path) {\
\      document.querySelectorAll('.file-item').forEach(el => {\
\        el.classList.remove('active');\
\        if (el.querySelector('.path').textContent === path) {\
\          el.classList.add('active');\
\        }\
\      });\
\      try {\
\        const result = await window.webkit_haskell.invoke('read-file', { path: path });\
\        if (result.error) {\
\          content.innerHTML = '<div class=\"empty-state\">' + escapeHtml(result.error) + '</div>';\
\        } else {\
\          content.innerHTML = '<pre>' + escapeHtml(result.content) + '</pre>';\
\        }\
\      } catch(e) {\
\        content.innerHTML = '<div class=\"empty-state\">Error loading file content</div>';\
\      }\
\    }\
\    setTimeout(loadFileList, 300);\
\  </script>\
\</body>\
\</html>"

  loadHTML app html
  runWebKitApp app
  destroyWebKitApp app
  putStrLn "App loop terminated successfully."
```

### Explaining the Generics Decoupling

In `"read-file"`, the incoming argument is an `Aeson.Value`. We decode this value using:
```haskell
case Aeson.fromJSON payload of
```
Rather than manually matching the underlying map representation of `Aeson.Object` (which differs between versions of the `aeson` library), we declare a simple `ReadFileRequest` type:
```haskell
newtype ReadFileRequest = ReadFileRequest { path :: String } deriving (Show, Generic)
instance Aeson.FromJSON ReadFileRequest
```
This decouples the code from the version-specific details of the JSON library, making it extremely durable against future library upgrades.

### Running the Example

Run the Markdown Viewer App via Cabal:

```bash
cabal run webkit-markdown-viewer
```

A window opens displaying the current workspace's Markdown files in a side list. Selecting any file will read it from the local disk using Haskell's `readFile` and update the view pane content asynchronously.


## Optional Practice Problems

1. Add a dark mode CSS toggle mechanism to the WebKit application using JS injection from Haskell.
2. Register a message callback handler to capture window/document JavaScript errors and output them to GHC's console stdout.
