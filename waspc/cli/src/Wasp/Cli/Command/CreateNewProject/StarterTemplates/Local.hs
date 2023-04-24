module Wasp.Cli.Command.CreateNewProject.StarterTemplates.Local
  ( createProjectOnDiskFromLocalTemplate,
  )
where

import Data.Maybe (fromJust)
import Path.IO (copyDirRecur)
import StrongPath (Abs, Dir, Path', reldir, (</>))
import qualified StrongPath as SP
import StrongPath.Path (toPathAbsDir)
import Wasp.Cli.Command.CreateNewProject.StarterTemplates.Common (replaceTemplatePlaceholdersInWaspFile)
import qualified Wasp.Data as Data
import Wasp.Project (WaspProjectDir)

createProjectOnDiskFromLocalTemplate :: Path' Abs (Dir WaspProjectDir) -> String -> String -> String -> IO ()
createProjectOnDiskFromLocalTemplate absWaspProjectDir projectName appName templateName = do
  copyLocalTemplateToNewProjectDir templateName
  replaceTemplatePlaceholdersInWaspFile appName projectName absWaspProjectDir
  where
    copyLocalTemplateToNewProjectDir :: String -> IO ()
    copyLocalTemplateToNewProjectDir templateDir = do
      dataDir <- Data.getAbsDataDirPath
      let absLocalTemplateDir =
            dataDir
              </> [reldir|Cli/templates|]
              </> (fromJust . SP.parseRelDir $ templateDir)
      copyDirRecur (toPathAbsDir absLocalTemplateDir) (toPathAbsDir absWaspProjectDir)
