import GoldenTest (GoldenTest)
import System.Info (os)
import Test.Tasty (defaultMain, testGroup)
import Tests.WaspBuildTest (waspBuild)
import Tests.WaspCompileTest (waspCompile)
import Tests.WaspMigrateTest (waspMigrate)
import Tests.WaspNewTest (waspNew)

main :: IO ()
main = do
  if os == "mingw32"
    then putStrLn "Skipping end-to-end tests on Windows due to tests using *nix-only commands"
    else tests >>= defaultMain

-- TODO: Add more tests to simulate full Todo app tutorial.
--       Some of this requires waspStart and stdout parsing.
-- TODO: Investigate automatically discovering the tests.
tests :: GoldenTest
tests =
  testGroup "All Golden Dir Tests"
    <$> sequence
      [ waspNew,
        waspCompile,
        waspMigrate,
        waspBuild
      ]
