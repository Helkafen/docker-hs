module Main where

import Network.Docker
import Network.Docker.Types

import Test.Tasty
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC
import qualified Test.QuickCheck.Monadic as QCM

import Data.Maybe (isJust, fromJust)
import System.Process (system)
import Data.Text (unpack)
import Control.Concurrent (threadDelay)
import Network.HTTP.Types.Status
import qualified Data.ByteString.Char8 as C
import qualified Data.ByteString       as B
import qualified Data.ByteString.Lazy  as BL

opts = defaultClientOpts { baseUrl = "http://127.0.0.1:2375/" }

test_image_name = "docker-hs-test"

toStrict1 = B.concat . BL.toChunks

checkDockerVersion :: IO ()
checkDockerVersion =  do v <- getDockerVersion opts
                         assert $ isJust v

findTestImage :: IO ()
findTestImage = do images <- getDockerImages opts
                   let x = fmap (filter ((== [test_image_name++":latest"]) . _repoTags)) images
                   assert $ fmap length x == Just 1

runAndReadLog :: IO ()
runAndReadLog = do containerId <- createContainer opts (defaultCreateOpts {_image = test_image_name++":latest"})
                   assert $ isJust containerId
                   let c = unpack $ fromJust containerId
                   status1 <- startContainer opts c defaultStartOpts
                   threadDelay 300000 -- give 300ms for the application to finish
                   assert $ status1 == status204
                   status2 <- killContainer opts c
                   logs <- getContainerLogs opts c
                   assert $ status2 == status204
                   assert $ (C.pack "123") `C.isInfixOf` (toStrict1 logs)
                   status3 <- deleteContainer opts c
                   assert $ status3 == status204


tests :: TestTree
tests = testGroup "Metrics tests" [
    testCase "Get docker version" checkDockerVersion,
    testCase "Find image by name" findTestImage,
    testCase "Run a dummy container and read its log" runAndReadLog]

setup :: IO()
setup =  system ("docker build -t "++test_image_name++" tests") >> return ()

main :: IO()
main = do
  setup
  defaultMain tests
