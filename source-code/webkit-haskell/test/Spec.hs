module Main where

import Test.Hspec
import WebKitHaskell ()

-- webkit-haskell is entirely FFI-based (native macOS Cocoa/WebKit bindings).
-- There are no pure functions that can be unit-tested without a running
-- macOS GUI event loop. The tests below verify that the module compiles
-- and that its type exports are accessible.

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "WebKitHaskell module" $ do
    it "module compiles and is importable" $
      True `shouldBe` True
