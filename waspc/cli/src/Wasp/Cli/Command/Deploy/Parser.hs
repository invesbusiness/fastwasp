module Wasp.Cli.Command.Deploy.Parser (deploy) where

import Options.Applicative
  ( CommandFields,
    Mod,
    Parser,
  )
import qualified Options.Applicative as O
import Wasp.Cli.Command.Call (Call (Deploy))
import Wasp.Cli.Parser.Util (mkCommand)

-- The rest of arguments will be supplied externally by chosen deploy tool.
deploy :: Mod CommandFields Call
deploy =
  mkCommand
    "deploy"
    [O.progDesc "Deploys your Wasp app to cloud hosting providers.", O.forwardOptions]
    parseDeploy

parseDeploy :: Parser Call
parseDeploy = Deploy <$> O.many deployRestArgs
  where
    deployRestArgs =
      O.strArgument $
        O.metavar "DEPLOY_ARGUMENTS"
          <> O.help "Currently only supports fly.io. See https://wasp-lang.dev/docs/deploying."