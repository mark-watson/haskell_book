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

  -- Create state using IORef
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
