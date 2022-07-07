module Wasp.Generator.WebAppGenerator.Start
  ( startWebApp,
  )
where

import StrongPath (Abs, Dir, Path', (</>))
import Wasp.Generator.Common (ProjectRootDir, buildNpmCmdWithArgs)
import qualified Wasp.Generator.Job as J
import Wasp.Generator.Job.Process (runNodeDependentCommandAsJob)
import qualified Wasp.Generator.WebAppGenerator.Common as Common

startWebApp :: Path' Abs (Dir ProjectRootDir) -> J.Job
startWebApp projectDir = do
  let webAppDir = projectDir </> Common.webAppRootDirInProjectRootDir
  runNodeDependentCommandAsJob J.WebApp webAppDir $ buildNpmCmdWithArgs ["start"]
