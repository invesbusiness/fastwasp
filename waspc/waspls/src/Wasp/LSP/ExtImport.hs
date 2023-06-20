{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}

{-# HLINT ignore "Redundant <$>" #-}

module Wasp.LSP.ExtImport
  ( -- * TS Export lists
    refreshAllExports,
    refreshExportsForFiles,

    -- * Diagnostics and Syntax
    ExtImportNode (..),
    findExternalImportAroundLocation,
    updateMissingImportDiagnostics,
    getMissingImportDiagnostics,
  )
where

import Control.Applicative ((<|>))
import Control.Arrow (Arrow (first), (&&&))
import Control.Lens ((%~), (^.))
import Control.Monad (void)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Log.Class (logM)
import Control.Monad.Reader.Class (asks)
import Control.Monad.Trans.Maybe (MaybeT (runMaybeT))
import qualified Data.HashMap.Strict as M
import Data.List (stripPrefix)
import Data.Maybe (catMaybes, fromJust, fromMaybe, mapMaybe)
import qualified Language.LSP.Server as LSP
import qualified Path as P
import qualified StrongPath as SP
import qualified StrongPath.Path as SP
import Text.Read (readMaybe)
import Wasp.Analyzer.Parser (ExtImportName (ExtImportField, ExtImportModule))
import qualified Wasp.Analyzer.Parser.CST as S
import Wasp.Analyzer.Parser.CST.Traverse (Traversal)
import qualified Wasp.Analyzer.Parser.CST.Traverse as T
import Wasp.LSP.Diagnostic (MissingImportReason (NoDefaultExport, NoFile, NoNamedExport), WaspDiagnostic (MissingImportDiagnostic), clearMissingImportDiagnostics)
import Wasp.LSP.ServerM (HandlerM, ServerM, handler, modify)
import qualified Wasp.LSP.ServerState as State
import Wasp.LSP.Syntax (findChild, lexemeAt)
import Wasp.LSP.Util (hoistMaybe)
import Wasp.Project (WaspProjectDir)
import qualified Wasp.TypeScript as TS
import Wasp.Util.IO (doesFileExist)

-- TODO(before merge): update in cache when file is deleted (maybe by just
-- clearing cache for a file even when finding export list fails)

-- | Finds all external imports and refreshes the export cache for the relevant
-- files.
refreshAllExports :: ServerM ()
refreshAllExports = do
  (src, maybeCst) <- handler $ asks ((^. State.currentWaspSource) &&& (^. State.cst))
  maybeWaspRoot <- (>>= SP.parseAbsDir) <$> LSP.getRootPath
  case (,) <$> maybeCst <*> maybeWaspRoot of
    Nothing -> pure ()
    Just (syntax, waspRoot) -> do
      let allExtImports = findAllExtImports src syntax
      allTsFiles <- catMaybes <$> mapM (absPathForExtImport waspRoot) allExtImports
      refreshExportsForFiles allTsFiles

-- | Refresh the export cache for the given JS/TS files. This can take a while:
-- generally half a second to a second. It is recommended that this is run in
-- the reactor thread so it does not block other LSP requests from being
-- responded to.
refreshExportsForFiles :: [SP.Path' SP.Abs SP.File'] -> ServerM ()
refreshExportsForFiles files = do
  logM $ "[refreshExportsForFile] refreshing export lists for " ++ show files
  LSP.getRootPath >>= \case
    Nothing -> pure ()
    Just projectDirFilepath -> do
      -- NOTE: getRootPath always returns a valid absolute path or 'Nothing'.
      let projectDir = fromJust $ SP.parseAbsDir projectDirFilepath
      let exportRequests = mapMaybe (getExportRequestForFile projectDir) files
      liftIO (TS.getExportsOfTsFiles exportRequests) >>= \case
        Left err -> do
          logM $ "[refreshExportsForFile] ERROR getting exports: " ++ show err
        Right res -> updateExportsCache res
  where
    getExportRequestForFile projectDir file =
      ([SP.fromAbsFile file] `TS.TsExportRequest`) . Just . SP.fromAbsFile <$> tryGetTsconfigForFile projectDir file

-- | Look for the tsconfig file for the specified JS/TS file.
--
-- To do this, it checks if the file is inside src/client or src/server and
-- returns the respective tsconfig path if so (src/client/tsconfig.json or
-- src/server/tsconfig.json).
tryGetTsconfigForFile :: SP.Path' SP.Abs (SP.Dir WaspProjectDir) -> SP.Path' SP.Abs SP.File' -> Maybe (SP.Path' SP.Abs SP.File')
tryGetTsconfigForFile waspRoot file = tsconfigPath [SP.reldir|src/client|] <|> tsconfigPath [SP.reldir|src/server|]
  where
    tsconfigPath :: SP.Path' (SP.Rel WaspProjectDir) SP.Dir' -> Maybe (SP.Path' SP.Abs SP.File')
    tsconfigPath folder =
      let absFolder = waspRoot SP.</> folder
       in if SP.toPathAbsDir absFolder `P.isProperPrefixOf` SP.toPathAbsFile file
            then Just $ absFolder SP.</> [SP.relfile|tsconfig.json|]
            else Nothing

updateExportsCache :: TS.TsExportResponse -> ServerM ()
updateExportsCache (TS.TsExportResponse res) = do
  let newExports = M.fromList $ map (first exportResKeyToPath) $ M.toList res
  void $ modify $ State.tsExports %~ (newExports `M.union`)
  where
    -- 'TS.getExportsOfTsFiles' should only ever put valid paths in the keys of
    -- its response, so we enforce that here.
    exportResKeyToPath key = case SP.parseAbsFile key of
      Just path -> path
      Nothing -> error "updateExportsCache: expected valid path from TS.getExportsOfTsFiles."

-- ------------------------- Diagnostics & Syntax ------------------------------

data ExtImportNode = ExtImportNode
  { -- | Location of the 'S.ExtImport' node.
    einLocation :: !Traversal,
    einName :: !(Maybe ExtImportName),
    -- | Imported filepath, verbatim from the wasp source file.
    einFile :: !(Maybe FilePath)
  }

-- | Create a 'ExtImportNode' at a location, assuming that the given node is
-- a 'S.ExtImport'.
externalImportAtLocation :: String -> Traversal -> ExtImportNode
externalImportAtLocation src location =
  let maybeName =
        (ExtImportModule . lexemeAt src <$> findChild S.ExtImportModule location)
          <|> (ExtImportField . lexemeAt src <$> findChild S.ExtImportField location)
      maybeFile = lexemeAt src <$> findChild S.ExtImportPath location
   in ExtImportNode location maybeName maybeFile

-- | Search for an 'S.ExtImport' node at the current node or as one of its
-- ancestors.
findExternalImportAroundLocation ::
  -- | Wasp source code.
  String ->
  -- | Location to look for external import at.
  Traversal ->
  Maybe ExtImportNode
findExternalImportAroundLocation src location = do
  extImport <- findExtImportParent location
  return $ externalImportAtLocation src extImport
  where
    findExtImportParent t
      | T.kindAt t == S.ExtImport = Just t
      | otherwise = T.up t >>= findExtImportParent

-- | Gets diagnostics for external imports and appends them to the current
-- list of diagnostics.
updateMissingImportDiagnostics :: ServerM ()
updateMissingImportDiagnostics = do
  newDiagnostics <- handler getMissingImportDiagnostics
  modify (State.latestDiagnostics %~ ((++ newDiagnostics) . clearMissingImportDiagnostics))

-- | Get diagnostics for external imports with missing definitions. Uses the
-- cached export lists.
getMissingImportDiagnostics :: HandlerM [WaspDiagnostic]
getMissingImportDiagnostics =
  asks (^. State.cst) >>= \case
    Nothing -> return []
    Just syntax -> do
      src <- asks (^. State.currentWaspSource)
      let allExtImports = findAllExtImports src syntax
      catMaybes <$> mapM findDiagnosticForExtImport allExtImports

-- Finds all external imports in a concrete syntax tree.
findAllExtImports :: String -> [S.SyntaxNode] -> [ExtImportNode]
findAllExtImports src syntax = go $ T.fromSyntaxForest syntax
  where
    -- Recurse through syntax tree and find all 'S.ExtImport' nodes.
    go :: Traversal -> [ExtImportNode]
    go t = case T.kindAt t of
      S.ExtImport -> [externalImportAtLocation src t]
      _ -> concatMap go $ T.children t

-- | Check a single external import and see if it points to a real exported
-- function in a source file.
--
-- If the file is not in the cache, no diagnostic is reported because that would
-- risk showing incorrect diagnostics.
findDiagnosticForExtImport :: ExtImportNode -> HandlerM (Maybe WaspDiagnostic)
findDiagnosticForExtImport extImport = do
  (>>= SP.parseAbsDir) <$> LSP.getRootPath >>= \case
    Nothing -> return Nothing -- can't find project root
    Just waspRoot ->
      absPathForExtImport waspRoot extImport >>= \case
        Nothing -> do
          logM $ "[getMissingImportDiagnostics] ignoring extimport with invalid path " ++ show extImportSpan
          -- Invalid external import path, but this function doesn't report those
          -- diagnostics.
          return Nothing
        Just tsFile ->
          asks ((M.!? tsFile) . (^. State.tsExports)) >>= \case
            Nothing -> getDiagnosticForCacheMiss tsFile
            Just exports -> getDiagnosticForCacheHit tsFile exports
  where
    getDiagnosticForCacheMiss tsFile = do
      tsFileExists <- liftIO $ doesFileExist tsFile
      if tsFileExists
        then return Nothing -- File not in cache.
        else return $ Just $ MissingImportDiagnostic extImportSpan NoFile tsFile

    getDiagnosticForCacheHit tsFile exports = case maybeIsImportedExport of
      Nothing -> return Nothing -- Missing import name in the external import node. This diagnostic is reported elsewhere.
      Just isImportedExport -> do
        if any isImportedExport exports
          then return Nothing -- It's a valid export.
          else return $ Just $ diagnosticForExtImport tsFile

    diagnosticForExtImport tsFile = case einName extImport of
      Nothing -> error "diagnosticForExtImport called for nameless ext import. This should never happen."
      Just (ExtImportModule _) -> MissingImportDiagnostic extImportSpan NoDefaultExport tsFile
      Just (ExtImportField name) -> MissingImportDiagnostic extImportSpan (NoNamedExport name) tsFile

    extImportSpan = T.spanAt $ einLocation extImport

    -- Function to search an export list for the imported export.
    maybeIsImportedExport = case einName extImport of
      Nothing -> Nothing
      Just (ExtImportModule _) -> Just $ \case
        TS.DefaultExport _ -> True
        _ -> False
      Just (ExtImportField name) -> Just $ \case
        TS.NamedExport n _ | name == n -> True
        _ -> False

-- | Convert the path inside an external import in a .wasp file to an absolute
-- path.
--
-- To support ESNext module resolution, this may also change the file extension
-- from @.js@ to @.ts@. This occurs when the @.ts@ file exists on disk.
absPathForExtImport ::
  (MonadIO m) =>
  SP.Path' SP.Abs SP.Dir' ->
  ExtImportNode ->
  m (Maybe (SP.Path' SP.Abs SP.File'))
absPathForExtImport waspRoot extImport = runMaybeT $ do
  -- Read the string from the syntax tree
  extImportPath :: FilePath <- hoistMaybe $ einFile extImport >>= readMaybe
  -- Drop the @ and try to parse to a relative path
  relPath <- hoistMaybe $ SP.parseRelFile =<< stripPrefix "@" extImportPath
  -- Prepend the src directory in the project to the relative path
  let absPath = waspRoot SP.</> [SP.reldir|src|] SP.</> relPath
  -- Fix the extension, if needed
  SP.fromPathAbsFile <$> fixExtension (SP.toPathAbsFile absPath)
  where
    fixExtension file
      | fromMaybe "" (P.fileExtension file) == ".js" = useTsExtensionIfFileExists file
      | otherwise = return file

    -- Replaces extension with @.ts@ if the file with the extension replaced
    -- exists.
    useTsExtensionIfFileExists file = do
      -- @.ts@ is a valid extension so this never throws.
      let tsFile = fromJust $ P.replaceExtension ".ts" file
      tsFileExists <- liftIO $ doesFileExist $ SP.fromPathAbsFile tsFile
      return $ if tsFileExists then tsFile else file
