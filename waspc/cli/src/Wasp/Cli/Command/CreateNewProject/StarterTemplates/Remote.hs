module Wasp.Cli.Command.CreateNewProject.StarterTemplates.Remote
  ( createProjectOnDiskFromRemoteTemplate,
  )
where

import Control.Monad.IO.Class (liftIO)
import StrongPath (Abs, Dir, Path')
import qualified StrongPath as SP
import System.Process (callCommand)
import UnliftIO.Exception (SomeException, try)
import Wasp.Cli.Command (Command)
import Wasp.Cli.Command.CreateNewProject.Common
  ( throwInvalidTemplateNameUsedError,
    throwProjectCreationError,
  )
import Wasp.Cli.Command.CreateNewProject.StarterTemplates.Common (replaceTemplatePlaceholdersInWaspFile)
import Wasp.Project (WaspProjectDir)
import Wasp.Util (whenM)
import qualified Wasp.Util.IO as IOUtil

createProjectOnDiskFromRemoteTemplate :: Path' Abs (Dir WaspProjectDir) -> String -> String -> String -> Command ()
createProjectOnDiskFromRemoteTemplate absWaspProjectDir projectName appName templateName = do
  templatePath <- getPathToRemoteTemplate templateName
  fetchTemplateAndWriteToDisk absWaspProjectDir templatePath
  liftIO $ replaceTemplatePlaceholdersInWaspFile appName projectName absWaspProjectDir
  where
    getPathToRemoteTemplate :: String -> Command String
    getPathToRemoteTemplate tmplName = return $ waspTemplatesRepo ++ "/" ++ templateFolderName
      where
        templateFolderName = tmplName
        -- gh: prefix means Github repo
        waspTemplatesRepo = "gh:wasp-lang/starters"

    fetchTemplateAndWriteToDisk :: Path' Abs (Dir WaspProjectDir) -> String -> Command ()
    fetchTemplateAndWriteToDisk projectDir templatePath = do
      liftIO (try executeCmd) >>= \case
        Left (e :: SomeException) -> throwProjectCreationError $ "Failed to create project from template: " ++ show e
        Right _ -> ensureTemplateWasFetched
      where
        -- TODO: Throw nice message if node is not installed.
        executeCmd = callCommand $ unwords command
        command = ["npx", "--yes", "giget@latest", templatePath, SP.fromAbsDir projectDir]

        -- giget doesn't fail if the template dir doesn't exist in the repo, so we need to check if the directory exists.
        ensureTemplateWasFetched :: Command ()
        ensureTemplateWasFetched =
          whenM
            (liftIO $ IOUtil.isDirectoryEmpty projectDir)
            throwInvalidTemplateNameUsedError
