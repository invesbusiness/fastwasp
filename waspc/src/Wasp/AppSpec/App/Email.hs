{-# LANGUAGE DeriveDataTypeable #-}

module Wasp.AppSpec.App.Email
  ( Email (..),
    EmailProvider (..),
    Sender (..),
  )
where

import Data.Data (Data)

data Email = Email
  { provider :: EmailProvider,
    sender :: Sender
  }
  deriving (Show, Eq, Data)

data EmailProvider = SMTP | SendGrid
  deriving (Eq, Data)

instance Show EmailProvider where
  show SMTP = "smtp"
  show SendGrid = "sendgrid"

data Sender = Sender
  { title :: Maybe String,
    email :: String
  }
  deriving (Show, Eq, Data)
