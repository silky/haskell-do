#!/usr/bin/env stack
-- stack --resolver lts-8.6 --install-ghc runghc --package turtle-1.3.2 --package foldl
{-# LANGUAGE OverloadedStrings #-}

import Prelude hiding (FilePath)
import Turtle
import Control.Monad (when)
import Data.Text as T
import Data.Text (Text)
import System.Info (os)
import qualified Control.Foldl as Foldl
import Filesystem.Path.CurrentOS 


main = do
  projectDirectory <- pwdAsText
  BuildCommand all gui core deps run <- options "Haskell.do build file" buildSwitches
  if all
    then buildAll projectDirectory
    else do
      when gui          $ buildGUI          projectDirectory
      when core         $ buildCore         projectDirectory
      when deps         $ buildDeps         projectDirectory
      when run          $ runHaskellDo      projectDirectory


buildSwitches :: Parser BuildCommand
buildSwitches = BuildCommand
     <$> switch "all"          'a' "Build all subprojects, without running Haskell.do"
     <*> switch "gui"          'g' "Build GUI"
     <*> switch "core"         'c' "Build processing/compilation core"
     <*> switch "deps"         'd' "Download dependencies"
     <*> switch "run"          'r' "Run Haskell.do"

buildAll projectDirectory = do
  buildCore projectDirectory
  buildGUI projectDirectory

buildCore :: Text -> IO ()
buildCore pdir = do
  echo "Building core"
  let coreExtension = if isWindows os
      then ".exe" :: Text
      else ""     :: Text
  let coreFile = makeTextPath "/bin/haskelldo-core" <> coreExtension
  let guiBinariesDir = makeTextPath "/gui/dist/bin/haskelldo-core" <> coreExtension
  shell ("cd "<>pdir<>" &&\
    \cd core&&\
    \stack build") ""
  Just binaryDirectory <- Turtle.fold (inshell ("cd "<>pdir<>"&&cd core&&stack path --local-install-root") "") Foldl.head
  shell ("cp " <> lineToText binaryDirectory <> coreFile <> " " <> pdir <> guiBinariesDir <> "&&cd ..") ""
  return ()


buildGUI pdir = do
  echo "Building GUI"
  shell ("cd "<>pdir<>" &&\
    \cd gui&&\
    \npm run build&&\
    \cd ..") ""
  return ()


buildDeps pdir = do
  echo "Downloading dependencies"
  shell ("cd "<>pdir<>" &&\
    \cd gui&&\
    \npm install && bower install && cd "<>pdir<>"&&\
    \cd core && stack setup &&\
    \cd ..") ""
  return ()


runHaskellDo pdir = do
  echo "Running Haskell.do"
  shell ("cd "<>pdir<>" &&\
    \cd gui&&\
    \npm run start") ""
  return ()




-- Helpers
isWindows operatingSystem = "mingw" `T.isPrefixOf` T.pack operatingSystem
isOSX operatingSystem = "darwin" `T.isPrefixOf` T.pack operatingSystem

makeTextPath = T.pack . encodeString . fromText

pwdAsText :: IO Text
pwdAsText = T.pack <$> encodeString <$> pwd

data BuildCommand = BuildCommand
  { buildCommandAll          :: Bool
  , buildCommandGui          :: Bool
  , buildCommandCore         :: Bool
  , buildCommandOrchestrator :: Bool
  , buildCommandRun          :: Bool
  }

