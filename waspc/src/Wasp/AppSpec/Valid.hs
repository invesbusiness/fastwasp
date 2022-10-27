{-# LANGUAGE TypeApplications #-}

module Wasp.AppSpec.Valid
  ( validateAppSpec,
    ValidationError (..),
    getApp,
    isAuthEnabled,
  )
where

import Data.List (find)
import Data.Maybe (isJust)
import Wasp.AppSpec (AppSpec)
import qualified Wasp.AppSpec as AS
import Wasp.AppSpec.App (App)
import qualified Wasp.AppSpec.App as AS.App
import qualified Wasp.AppSpec.App as App
import qualified Wasp.AppSpec.App.Auth as Auth
import qualified Wasp.AppSpec.App.Db as AS.Db
import qualified Wasp.AppSpec.App.Wasp as Wasp
import Wasp.AppSpec.Core.Decl (takeDecls)
import qualified Wasp.AppSpec.Entity as Entity
import qualified Wasp.AppSpec.Entity.Field as Entity.Field
import qualified Wasp.AppSpec.Page as Page
import Wasp.AppSpec.Util (isPgBossJobExecutorUsed)
import Text.Regex.TDFA ((=~))
import qualified Wasp.SemanticVersion as SV
import GHC.Natural (wordToNatural)
import qualified Paths_waspc
import qualified Data.Version as DV

data ValidationError = GenericValidationError String
  deriving (Show, Eq)

validateAppSpec :: AppSpec -> [ValidationError]
validateAppSpec spec =
  case validateExactlyOneAppExists spec of
    Just err -> [err]
    Nothing ->
      -- NOTE: We check these only if App exists because they all rely on it existing.
      concat
        [ validateWasp spec,
          validateAppAuthIsSetIfAnyPageRequiresAuth spec,
          validateAuthUserEntityHasCorrectFieldsIfUsernameAndPasswordAuthIsUsed spec,
          validateExternalAuthEntityHasCorrectFieldsIfExternalAuthIsUsed spec,
          validateDbIsPostgresIfPgBossUsed spec
        ]

validateExactlyOneAppExists :: AppSpec -> Maybe ValidationError
validateExactlyOneAppExists spec =
  case AS.takeDecls @App (AS.decls spec) of
    [] -> Just $ GenericValidationError "You are missing an 'app' declaration in your Wasp app."
    [_] -> Nothing
    apps ->
      Just $
        GenericValidationError $
          "You have more than one 'app' declaration in your Wasp app. You have " ++ show (length apps) ++ "."

validateWasp :: AppSpec -> [ValidationError]
validateWasp spec = validateWaspVersion specWaspVersionStr
  where
    specWaspVersionStr = Wasp.version $ App.wasp (snd $ getApp spec)

validateWaspVersion :: String -> [ValidationError]
validateWaspVersion specWaspVersion = case versionMatches of
  [] -> [GenericValidationError "Wasp version should be in the format ^0.major.minor.patch"]
  versionDigitsStr -> validateVersionDigits versionDigitsStr
  where
    (_ :: String, _ :: String, _ :: String, versionMatches :: [String]) = specWaspVersion =~ versionRegex
    versionRegex = "\\^0\\.([0-9]+).([0-9]+).([0-9]+)$" :: String

    validateVersionDigits :: [String] -> [ValidationError]
    validateVersionDigits versionDigits = validateCompatibility expectedSemVer currentWaspSemVer
      where
        expectedSemVer = wordsToSemVer $ map read versionDigits

        wordsToSemVer :: [Word] -> SV.Version
        wordsToSemVer (major : minor : patch : _) = SV.Version (wordToNatural major) (wordToNatural minor) (wordToNatural patch)
        wordsToSemVer _ =
          error $
            "Expected version digits to match [major, minor, patch]. "
            ++ "This should never happen as the version was already validated with regex."

        validateCompatibility :: SV.Version -> SV.Version -> [ValidationError]
        validateCompatibility compatibleVersion actualVersion =
          if isCurrentWaspVersionCompatibleWithSpecVersion
            then []
            else
              [ GenericValidationError $
                  incompatibleVersionMessage actualVersion compatibleVersion
              ]
          where
            isCurrentWaspVersionCompatibleWithSpecVersion =
              SV.isVersionInRange actualVersion (SV.Range [SV.backwardsCompatibleWith compatibleVersion])

        incompatibleVersionMessage :: SV.Version -> SV.Version -> String
        incompatibleVersionMessage actualVersion expectedVersion =
          unwords
            [ "Your Wasp version does not match the app's requirements.",
              "You are running Wasp 0." ++ show actualVersion ++ ".",
              "This app requires Wasp ^0." ++ show expectedVersion ++ "."
            ]

        currentWaspSemVer = SV.Version (toEnum currentMajor) (toEnum currentMinor) (toEnum currentPatch)
          where
            DV.Version (_ : currentMajor : currentMinor : currentPatch : _) _ = Paths_waspc.version

validateAppAuthIsSetIfAnyPageRequiresAuth :: AppSpec -> [ValidationError]
validateAppAuthIsSetIfAnyPageRequiresAuth spec =
  [ GenericValidationError
      "Expected app.auth to be defined since there are Pages with authRequired set to true."
    | anyPageRequiresAuth && not (isAuthEnabled spec)
  ]
  where
    anyPageRequiresAuth = any ((== Just True) . Page.authRequired) (snd <$> AS.getPages spec)

validateDbIsPostgresIfPgBossUsed :: AppSpec -> [ValidationError]
validateDbIsPostgresIfPgBossUsed spec =
  [ GenericValidationError
      "Expected app.db.system to be PostgreSQL since there are jobs with executor set to PgBoss."
    | isPgBossJobExecutorUsed spec && not (isPostgresUsed spec)
  ]

validateAuthUserEntityHasCorrectFieldsIfUsernameAndPasswordAuthIsUsed :: AppSpec -> [ValidationError]
validateAuthUserEntityHasCorrectFieldsIfUsernameAndPasswordAuthIsUsed spec = case App.auth (snd $ getApp spec) of
  Nothing -> []
  Just auth ->
    if not $ Auth.isUsernameAndPasswordAuthEnabled auth
      then []
      else
        let userEntity = snd $ AS.resolveRef spec (Auth.userEntity auth)
            userEntityFields = Entity.getFields userEntity
         in concatMap
              (validateEntityHasField "app.auth.userEntity" userEntityFields)
              [ ("username", Entity.Field.FieldTypeScalar Entity.Field.String, "String"),
                ("password", Entity.Field.FieldTypeScalar Entity.Field.String, "String")
              ]

validateExternalAuthEntityHasCorrectFieldsIfExternalAuthIsUsed :: AppSpec -> [ValidationError]
validateExternalAuthEntityHasCorrectFieldsIfExternalAuthIsUsed spec = case App.auth (snd $ getApp spec) of
  Nothing -> []
  Just auth ->
    if not $ Auth.isExternalAuthEnabled auth
      then []
      else case Auth.externalAuthEntity auth of
        Nothing -> [GenericValidationError "app.auth.externalAuthEntity must be specified when using a social login method."]
        Just externalAuthEntityRef ->
          let (userEntityName, userEntity) = AS.resolveRef spec (Auth.userEntity auth)
              userEntityFields = Entity.getFields userEntity
              (externalAuthEntityName, externalAuthEntity) = AS.resolveRef spec externalAuthEntityRef
              externalAuthEntityFields = Entity.getFields externalAuthEntity
              externalAuthEntityValidationErrors =
                concatMap
                  (validateEntityHasField "app.auth.externalAuthEntity" externalAuthEntityFields)
                  [ ("provider", Entity.Field.FieldTypeScalar Entity.Field.String, "String"),
                    ("providerId", Entity.Field.FieldTypeScalar Entity.Field.String, "String"),
                    ("user", Entity.Field.FieldTypeScalar (Entity.Field.UserType userEntityName), userEntityName),
                    ("userId", Entity.Field.FieldTypeScalar Entity.Field.Int, "Int")
                  ]
              userEntityValidationErrors =
                concatMap
                  (validateEntityHasField "app.auth.userEntity" userEntityFields)
                  [ ("externalAuthAssociations", Entity.Field.FieldTypeComposite $ Entity.Field.List $ Entity.Field.UserType externalAuthEntityName, externalAuthEntityName ++ "[]")
                  ]
           in externalAuthEntityValidationErrors ++ userEntityValidationErrors

validateEntityHasField :: String -> [Entity.Field.Field] -> (String, Entity.Field.FieldType, String) -> [ValidationError]
validateEntityHasField entityName entityFields (fieldName, fieldType, fieldTypeName) =
  let maybeField = find ((== fieldName) . Entity.Field.fieldName) entityFields
   in case maybeField of
        Just providerField
          | Entity.Field.fieldType providerField == fieldType -> []
        _ ->
          [ GenericValidationError $
              "Expected an Entity referenced by " ++ entityName ++ " to have field '" ++ fieldName ++ "' of type '" ++ fieldTypeName ++ "'."
          ]

-- | This function assumes that @AppSpec@ it operates on was validated beforehand (with @validateAppSpec@ function).
-- TODO: It would be great if we could ensure this at type level, but we decided that was too much work for now.
--   Check https://github.com/wasp-lang/wasp/pull/455 for considerations on this and analysis of different approaches.
getApp :: AppSpec -> (String, App)
getApp spec = case takeDecls @App (AS.decls spec) of
  [app] -> app
  apps ->
    error $
      ("Expected exactly 1 'app' declaration in your wasp code, but you have " ++ show (length apps) ++ ".")
        ++ " This should never happen as it should have been caught during validation of AppSpec."

-- | This function assumes that @AppSpec@ it operates on was validated beforehand (with @validateAppSpec@ function).
isAuthEnabled :: AppSpec -> Bool
isAuthEnabled spec = isJust (App.auth $ snd $ getApp spec)

-- | This function assumes that @AppSpec@ it operates on was validated beforehand (with @validateAppSpec@ function).
isPostgresUsed :: AppSpec -> Bool
isPostgresUsed spec = Just AS.Db.PostgreSQL == (AS.Db.system =<< AS.App.db (snd $ getApp spec))
