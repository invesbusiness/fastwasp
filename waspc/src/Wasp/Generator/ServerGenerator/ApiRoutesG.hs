module Wasp.Generator.ServerGenerator.ApiRoutesG
  ( genApiRoutes,
  )
where

import Data.Aeson (object, (.=))
import qualified Data.Aeson as Aeson
import Data.Char (toLower)
import StrongPath (Dir, File', Path, Path', Posix, Rel, reldirP, relfile)
import qualified StrongPath as SP
import Wasp.AppSpec (AppSpec)
import qualified Wasp.AppSpec as AS
import Wasp.AppSpec.Api (Api)
import qualified Wasp.AppSpec.Api as Api
import Wasp.Generator.Common (ServerRootDir)
import Wasp.Generator.FileDraft (FileDraft)
import Wasp.Generator.Monad (Generator)
import qualified Wasp.Generator.ServerGenerator.Common as C
import Wasp.Generator.ServerGenerator.JsImport (getJsImportStmtAndIdentifier)

genApiRoutes :: AppSpec -> Generator FileDraft
genApiRoutes spec =
  return $ C.mkTmplFdWithDstAndData tmplFile dstFile (Just tmplData)
  where
    apis = map snd $ AS.getApis spec
    tmplData = object ["apiRoutes" .= map getRouteData apis]
    tmplFile = C.asTmplFile [relfile|src/routes/apis/index.js|]
    dstFile = SP.castRel tmplFile :: Path' (Rel ServerRootDir) File'

    getRouteData :: Api -> Aeson.Value
    getRouteData api =
      let (jsImportStmt, jsImportIdentifier) = getJsImportStmtAndIdentifier relPathFromApisDirToServerSrcDir (Api.fn api)
       in object
            [ "routeVerb" .= map toLower (show $ Api.verb api),
              "routePath" .= Api.route api,
              "importStatement" .= jsImportStmt,
              "importIdentifier" .= jsImportIdentifier
            ]

    relPathFromApisDirToServerSrcDir :: Path Posix (Rel importLocation) (Dir C.ServerSrcDir)
    relPathFromApisDirToServerSrcDir = [reldirP|../..|]
