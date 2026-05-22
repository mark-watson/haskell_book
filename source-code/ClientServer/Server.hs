{-# LANGUAGE OverloadedStrings #-}

module Main where

-- | TCP server using the network-simple library.
-- network-simple provides a higher-level API over network/network-bsd,
-- wrapping socket creation, binding, listening, and accepting into
-- simple combinators like 'T.listen', 'T.accept', and 'T.connect'.

import Control.Monad
import Control.Exception (IOException, try)
import qualified Data.ByteString.Char8 as B
import qualified Network.Simple.TCP as T

-- | Read from the socket in a loop, reversing each received bytestring
-- and sending it back.  Returns when the client disconnects (recv yields Nothing).
reverseStringLoop :: T.Socket -> IO ()
reverseStringLoop sock = do
  -- get a byte string wrapped as a MonadIO:
  mbs <- T.recv sock 4096
  case mbs of
    Just bs -> T.send sock (B.reverse bs) >> reverseStringLoop sock
    Nothing -> return ()

main :: IO ()
main = do
  -- Bind to localhost only (127.0.0.1) instead of "*" (all interfaces)
  -- to avoid exposing the service on the network.
  result <- try $ T.withSocketsDo $
    T.listen "127.0.0.1" "3000" $ \(lsock, laddr) -> do
      putStrLn $ "Listening at " ++ show laddr
      forever . T.acceptFork lsock $ \(sock, addr) -> do
        putStrLn $ "Connection from " ++ show addr
        reverseStringLoop sock
  case result of
    Left err -> putStrLn $ "Server error: " ++ show (err :: IOException)
    Right _  -> return ()
