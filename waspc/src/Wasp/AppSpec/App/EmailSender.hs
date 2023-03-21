{-# LANGUAGE DeriveDataTypeable #-}

module Wasp.AppSpec.App.EmailSender
  ( EmailSender (..),
    EmailProvider (..),
    EmailFrom (..),
  )
where

import Data.Data (Data)

data EmailSender = EmailSender
  { provider :: EmailProvider,
    defaultFrom :: EmailFrom
  }
  deriving (Show, Eq, Data)

data EmailProvider = SMTP | SendGrid | Mailgun
  deriving (Eq, Data, Show)

data EmailFrom = EmailFrom
  { name :: Maybe String,
    email :: String
  }
  deriving (Show, Eq, Data)
