module Wasp.Cli.Command.WaspLS
  ( runWaspLS,
    parseWaspLS,
  )
where

import Control.Monad.IO.Class (liftIO)
import qualified Options.Applicative as O
import Wasp.Cli.Command (Command)
import Wasp.Cli.Command.Call (Call (WaspLS), WaspLSArgs (..))
import qualified Wasp.LSP.Server as LS

parseWaspLS :: O.Parser Call
parseWaspLS = WaspLS <$> parseWaspLSArgs

runWaspLS :: WaspLSArgs -> Command ()
runWaspLS WaspLSArgs {wslLogFile = lf, waslUseStdio = _} = liftIO $ LS.serve lf

parseWaspLSArgs :: O.Parser WaspLSArgs
parseWaspLSArgs = WaspLSArgs <$> O.optional parseLogFile <*> parseStdio
  where
    parseLogFile =
      O.strOption
        ( O.long "log"
            <> O.help "Write log output to this file, if present. If not present, no logs are written. If set to `[OUTPUT]`, log output is sent to the LSP client."
            <> O.action "file"
            <> O.metavar "LOG_FILE"
        )

    -- vscode passes this option to the language server. waspls always uses stdio,
    -- so this switch is ignored.
    parseStdio =
      O.switch
        ( O.long "stdio"
            <> O.help "Use stdio for communicating with LSP client. This is the only communication method we support for now, so this is the default anyway and this flag has no effect."
        )
