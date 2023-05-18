module Wasp.Cli.Command.Test.Parser (test) where

import Options.Applicative
  ( Alternative (many),
    CommandFields,
    Mod,
    Parser,
    help,
    metavar,
    strArgument,
    subparser,
  )
import Wasp.Cli.Command.Call (Call (Test), TestArgs (TestClient, TestServer))
import Wasp.Cli.Parser.Util (CommandType (CTForwardOptions), mkCommand, mkWrapperCommand)

test :: Mod CommandFields Call
test = mkCommand "test" parseTest "Executes tests in your project."

parseTest :: Parser Call
parseTest = Test <$> parseTestArgs
  where
    parseTestArgs =
      subparser $
        mconcat
          [ mkWrapperCommand "client" CTForwardOptions (TestClient <$> many testRestArgs) "Run your app client tests.",
            mkWrapperCommand "server" CTForwardOptions (TestServer <$> many testRestArgs) "Run your app server tests."
          ]

testRestArgs :: Parser String
testRestArgs =
  strArgument $
    metavar "VITEST_ARGUMENTS"
      <> help "Extra arguments that will be passed to Vitest. See https://vitest.dev/guide/cli.html"
