{-# LANGUAGE TupleSections #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}

module Wasp.Generator.Crud
  ( getCrudOperationJson,
    getCrudEntityPrimaryField,
    getCrudFilePath,
    makeCrudOperationKeyAndJsonPair,
    crudDeclarationToOperationsList,
  )
where

import Data.Aeson (object, (.=))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Types as Aeson.Types
import Data.Maybe (catMaybes, fromJust, fromMaybe)
import qualified Data.Text as T
import StrongPath (File', Path', Rel)
import qualified StrongPath as SP
import qualified Wasp.AppSpec as AS
import qualified Wasp.AppSpec.Crud as AS.Crud
import qualified Wasp.AppSpec.Entity as Entity
import Wasp.Generator.Common (makeJsArrayFromHaskellList)
import qualified Wasp.Generator.Crud.Routes as Routes
import qualified Wasp.Psl.Ast.Model as PslModel
import qualified Wasp.Util as Util

getCrudOperationJson :: String -> AS.Crud.Crud -> PslModel.Field -> Aeson.Value
getCrudOperationJson crudOperationName crud primaryField =
  object
    [ "name" .= crudOperationName,
      "operations" .= object (map getDataForOperation crudOperations),
      "entityUpper" .= crudEntityName,
      "entityLower" .= Util.toLowerFirst crudEntityName,
      "entitiesArray" .= makeJsArrayFromHaskellList [crudEntityName],
      "primaryFieldName" .= PslModel._name primaryField
    ]
  where
    crudEntityName = AS.refName $ AS.Crud.entity crud

    crudOperations = crudDeclarationToOperationsList crud

    getDataForOperation :: (AS.Crud.CrudOperation, AS.Crud.CrudOperationOptions) -> Aeson.Types.Pair
    getDataForOperation (operation, options) =
      makeCrudOperationKeyAndJsonPair
        operation
        ( object
            [ "route" .= Routes.getRoute operation,
              "fullPath" .= Routes.makeFullPath crudOperationName operation,
              "isPublic" .= fromMaybe False (AS.Crud.isPublic options)
            ]
        )

getCrudEntityPrimaryField :: AS.AppSpec -> AS.Crud.Crud -> Maybe PslModel.Field
getCrudEntityPrimaryField spec crud = Entity.getPrimaryField crudEntity
  where
    crudEntity = snd $ AS.resolveRef spec (AS.Crud.entity crud)

getCrudFilePath :: String -> String -> Path' (Rel r) File'
getCrudFilePath crudName ext = fromJust (SP.parseRelFile (crudName ++ "." ++ ext))

crudDeclarationToOperationsList :: AS.Crud.Crud -> [(AS.Crud.CrudOperation, AS.Crud.CrudOperationOptions)]
crudDeclarationToOperationsList crud =
  catMaybes
    [ fmap (AS.Crud.Get,) (AS.Crud.get $ AS.Crud.operations crud),
      fmap (AS.Crud.GetAll,) (AS.Crud.getAll $ AS.Crud.operations crud),
      fmap (AS.Crud.Create,) (AS.Crud.create $ AS.Crud.operations crud),
      fmap (AS.Crud.Update,) (AS.Crud.update $ AS.Crud.operations crud),
      fmap (AS.Crud.Delete,) (AS.Crud.delete $ AS.Crud.operations crud)
    ]

-- Produces a pair of the operation name and arbitrary json value.
-- For example, for operation CrudOperation.Get and json value { "route": "get" },
-- this function will produce a pair ("Get", { "route": "get" }).
makeCrudOperationKeyAndJsonPair :: AS.Crud.CrudOperation -> Aeson.Value -> Aeson.Types.Pair
makeCrudOperationKeyAndJsonPair operation json = key .= json
  where
    key = T.pack . show $ operation