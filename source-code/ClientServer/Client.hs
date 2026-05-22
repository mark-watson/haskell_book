{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad
import Control.Exception (IOException, try)
import qualified Data.ByteString.Char8 as B
import qualified Network.Simple.TCP as T

main :: IO ()
main = do
  result <- try $ T.connect "127.0.0.1" "3000" $ \(connectionSocket, remoteAddr) -> do
    putStrLn $ "Connection established to " ++ show remoteAddr
    T.send connectionSocket "test123"
    response <- T.recv connectionSocket 100
    case response of
      Just s  -> B.putStrLn $ B.append "Response: " s
      Nothing -> putStrLn "No response from server"
  case result of
    Left err -> putStrLn $ "Connection error: " ++ show (err :: IOException)
    Right _  -> return ()
