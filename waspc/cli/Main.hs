module Main where

import Command (runCommand)
import Command.Build (build)
import qualified Command.Call
import Command.Clean (clean)
import Command.Compile (compile)
import Command.CreateNewProject (createNewProject)
import Command.Db (runDbCommand, studio)
import qualified Command.Db.Migrate
import Command.Start (start)
import qualified Command.Telemetry as Telemetry
import Command.Deps (deps)
import Control.Concurrent (threadDelay)
import qualified Control.Concurrent.Async as Async
import Control.Monad (void)
import Data.Char (isSpace)
import Data.Version (showVersion)
import Paths_waspc (version)
import System.Environment
import qualified Util.Terminal as Term

main :: IO ()
main = do
  args <- getArgs
  let commandCall = case args of
        ["new", projectName] -> Command.Call.New projectName
        ["start"] -> Command.Call.Start
        ["clean"] -> Command.Call.Clean
        ["compile"] -> Command.Call.Compile
        ("db" : dbArgs) -> Command.Call.Db dbArgs
        ["version"] -> Command.Call.Version
        ["build"] -> Command.Call.Build
        ["telemetry"] -> Command.Call.Telemetry
        ["deps"] -> Command.Call.Deps
        _ -> Command.Call.Unknown args

  telemetryThread <- Async.async $ runCommand $ Telemetry.considerSendingData commandCall

  case commandCall of
    Command.Call.New projectName -> runCommand $ createNewProject projectName
    Command.Call.Start -> runCommand start
    Command.Call.Clean -> runCommand clean
    Command.Call.Compile -> runCommand compile
    Command.Call.Db dbArgs -> dbCli dbArgs
    Command.Call.Version -> printVersion
    Command.Call.Build -> runCommand build
    Command.Call.Telemetry -> runCommand Telemetry.telemetry
    Command.Call.Deps -> runCommand deps
    Command.Call.Unknown _ -> printUsage

  -- If sending of telemetry data is still not done 1 second since commmand finished, abort it.
  -- We also make sure here to catch all errors that might get thrown and silence them.
  void $ Async.race (threadDelaySeconds 1) (Async.waitCatch telemetryThread)
  where
    threadDelaySeconds =
      let microsecondsInASecond = 1000000
       in threadDelay . (* microsecondsInASecond)

printUsage :: IO ()
printUsage =
  putStrLn $
    unlines
      [ title "USAGE",
        "  wasp <command> [command-args]",
        "",
        title "COMMANDS",
        title "  GENERAL",
        cmd "    new <project-name>    Creates new Wasp project.",
        cmd "    version               Prints current version of CLI.",
        title "  IN PROJECT",
        cmd "    start                 Runs Wasp app in development mode, watching for file changes.",
        cmd "    db <db-cmd> [args]    Executes a database command. Run 'wasp db' for more info.",
        cmd "    clean                 Deletes all generated code and other cached artifacts. Wasp equivalent of 'have you tried closing and opening it again?'.",
        cmd "    build                 Generates full web app code, ready for deployment. Use when deploying or ejecting.",
        cmd "    telemetry             Prints telemetry status.",
        "",
        title "EXAMPLES",
        "  wasp new MyApp",
        "  wasp start",
        "  wasp db migrate-dev",
        "",
        Term.applyStyles [Term.Green] "Docs:" ++ " https://wasp-lang.dev/docs",
        Term.applyStyles [Term.Magenta] "Discord (chat):" ++ " https://discord.gg/rzdnErX"
      ]

printVersion :: IO ()
printVersion = putStrLn $ showVersion version

-- TODO(matija): maybe extract to a separate module, e.g. DbCli.hs?
dbCli :: [String] -> IO ()
dbCli args = case args of
  ["migrate-dev"] -> runDbCommand Command.Db.Migrate.migrateDev
  ["studio"] -> runDbCommand studio
  _ -> printDbUsage

printDbUsage :: IO ()
printDbUsage =
  putStrLn $
    unlines
      [ title "USAGE",
        "  wasp db <command> [command-args]",
        "",
        title "COMMANDS",
        cmd
          ( "  migrate-dev   Ensures dev database corresponds to the current state of schema(entities):\n"
              <> "                  - Generates a new migration if there are changes in the schema.\n"
              <> "                  - Applies any pending migrations to the database."
          ),
        cmd "  studio        GUI for inspecting your database.",
        "",
        title "EXAMPLES",
        "  wasp db migrate-dev",
        "  wasp db studio"
      ]

title :: String -> String
title = Term.applyStyles [Term.Bold]

cmd :: String -> String
cmd = mapFirstWord (Term.applyStyles [Term.Yellow, Term.Bold])

mapFirstWord :: (String -> String) -> String -> String
mapFirstWord f s = beforeFirstWord ++ f firstWord ++ afterFirstWord
  where
    (beforeFirstWord, firstWordAndAfter) = span isSpace s
    (firstWord, afterFirstWord) = break isSpace firstWordAndAfter
