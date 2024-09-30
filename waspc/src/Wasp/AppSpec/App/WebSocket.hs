{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}

module Wasp.AppSpec.App.WebSocket
  ( WebSocket (..),
  )
where

import Data.Aeson (FromJSON)
import Data.Data (Data)
import GHC.Generics (Generic)
import Wasp.AppSpec.ExtImport (ExtImport)

data WebSocket = WebSocket
  { fn :: ExtImport,
    autoConnect :: Maybe Bool
  }
  deriving (Show, Eq, Data, Generic, FromJSON)
