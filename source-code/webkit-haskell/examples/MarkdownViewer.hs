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
