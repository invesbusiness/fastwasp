module Wasp.Generator.Common
  ( ProjectRootDir,
    nodeVersionRange,
    npmVersionRange,
    prismaVersion,
    npmCmd,
    buildNpmCmdWithArgs,
  )
where

import System.Info (os)
import qualified Wasp.SemanticVersion as SV

-- | Directory where the whole web app project (client, server, ...) is generated.
data ProjectRootDir

-- | Range of node versions that node packages generated by this generator work correctly with.
nodeVersionRange :: SV.Range
nodeVersionRange =
  SV.rangeFromVersionsIntersection
    [ (SV.BackwardsCompatibleWith, latestLTSVersion),
      (SV.LessThanOrEqual, latestLTSExactVersionThatWeKnowWorks)
    ]
  where
    latestLTSVersion = SV.Version 16 0 0
    -- There is a bug in node 16.15.1 (more correctly, in npm 8.11.0 that comes with it)
    -- that messes up how Wasp uses Prisma. That is why we limited ourselves to <=16.15.0 for now.
    -- Bug issue on NPM CLI repo: https://github.com/npm/cli/issues/5018 .
    latestLTSExactVersionThatWeKnowWorks = SV.Version 16 15 0

-- | Range of npm versions that Wasp and generated projects work correctly with.
npmVersionRange :: SV.Range
npmVersionRange =
  SV.rangeFromVersionsIntersection
    [ (SV.BackwardsCompatibleWith, latestLTSVersion),
      (SV.LessThanOrEqual, latestLTSExactVersionThatWeKnowWorks)
    ]
  where
    latestLTSVersion = SV.Version 8 0 0 -- Goes with node 16
    latestLTSExactVersionThatWeKnowWorks = SV.Version 8 5 5 -- Goes with node 16.15.0

prismaVersion :: SV.Version
prismaVersion = SV.Version 3 15 2

npmCmd :: String
npmCmd = case os of
  -- Windows adds ".exe" to command, when calling it programmatically, if it doesn't
  -- have an extension already, meaning that calling `npm` actually calls `npm.exe`.
  -- However, there is no `npm.exe` on Windows, instead there is `npm` or `npm.cmd`, so we make sure here to call `npm.cmd`.
  -- Extra info: https://stackoverflow.com/questions/43139364/createprocess-weird-behavior-with-files-without-extension .
  "mingw32" -> "npm.cmd"
  _ -> "npm"

buildNpmCmdWithArgs :: [String] -> (String, [String])
buildNpmCmdWithArgs args = case os of
  -- On Windows, due to how npm.cmd script is written, it happens that script
  -- resolves some paths (work directory) incorrectly when called programmatically, sometimes.
  -- Therefore, we call it via `cmd.exe`, which ensures this issue doesn't happen.
  -- Extra info: https://stackoverflow.com/a/44820337 .
  "mingw32" -> ("cmd.exe", [unwords $ "/c" : npmCmd : args])
  _ -> (npmCmd, args)
