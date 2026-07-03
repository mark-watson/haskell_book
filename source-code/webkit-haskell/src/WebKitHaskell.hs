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

-- The C callback type:
-- const char* callback(const char* command, const char* payload, void* userdata)
type BridgeCallback = CString -> CString -> Ptr () -> IO CString

foreign import ccall "wrapper"
  makeBridgeCallback :: BridgeCallback -> IO (FunPtr BridgeCallback)

-- ---------------------------------------------------------------------------
-- Haskell WebKitApp Type
-- ---------------------------------------------------------------------------

type Handlers = Map.Map String (Aeson.Value -> IO Aeson.Value)

-- | A handle to a native Cocoa window with WebKit and a JS bridge.
data WebKitApp = WebKitApp
  { appHandle          :: Ptr ()
  , appHandlers        :: IORef Handlers
  , appStablePtr       :: StablePtr (IORef Handlers)
  , appCallbackFunPtr  :: FunPtr BridgeCallback
  }

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- | Creates a new Cocoa window with WebKit view, initial title, and dimensions.
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

-- | Starts the application's Cocoa event runloop.
-- Blocks the main thread until the window is closed or quit is requested.
runWebKitApp :: WebKitApp -> IO ()
runWebKitApp app = c_wkhsk_run (appHandle app)

-- | Requests the event runloop to quit, closing the window.
quitWebKitApp :: WebKitApp -> IO ()
quitWebKitApp app = c_wkhsk_quit (appHandle app)

-- | Destroys the WebKit application window, freeing FFI callbacks and stable pointers.
destroyWebKitApp :: WebKitApp -> IO ()
destroyWebKitApp app = do
  c_wkhsk_destroy (appHandle app)
  freeHaskellFunPtr (appCallbackFunPtr app)
  freeStablePtr (appStablePtr app)

-- | Load raw HTML content directly into the web view.
loadHTML :: WebKitApp -> String -> IO ()
loadHTML app html = do
  cHtml <- newCString html
  c_wkhsk_load_html (appHandle app) cHtml
  free cHtml

-- | Navigate the web view to a URL (e.g. "https://example.com" or "file:///...").
loadURL :: WebKitApp -> String -> IO ()
loadURL app url = do
  cUrl <- newCString url
  c_wkhsk_load_url (appHandle app) cUrl
  free cUrl

-- | Load a local HTML file path relative to the current directory or absolute.
loadFile :: WebKitApp -> String -> IO ()
loadFile app path = do
  cPath <- newCString path
  c_wkhsk_load_file (appHandle app) cPath
  free cPath

-- | Evaluate JavaScript code within the web view context (fire-and-forget).
evalJS :: WebKitApp -> String -> IO ()
evalJS app js = do
  cJs <- newCString js
  c_wkhsk_eval_js (appHandle app) cJs
  free cJs

-- | Change the window title dynamically.
setTitle :: WebKitApp -> String -> IO ()
setTitle app title = do
  cTitle <- newCString title
  c_wkhsk_set_title (appHandle app) cTitle
  free cTitle

-- | Resize the window dimensions dynamically.
setSize :: WebKitApp -> Int -> Int -> IO ()
setSize app width height =
  c_wkhsk_set_size (appHandle app) (fromIntegral width) (fromIntegral height)

-- | Toggle window resizability.
setResizable :: WebKitApp -> Bool -> IO ()
setResizable app resizable =
  c_wkhsk_set_resizable (appHandle app) (if resizable then 1 else 0)

-- | Registers a bridge message command handler.
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
