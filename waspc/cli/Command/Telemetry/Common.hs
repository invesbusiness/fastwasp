module Command.Telemetry.Common
    ( TelemetryCacheDir
    , ensureTelemetryCacheDirExists
    ) where

import           Path                      (reldir)
import qualified System.Directory          as SD

import           StrongPath                (Abs, Dir, Path)
import qualified StrongPath                as SP


data UserCacheDir

getUserCacheDirPath :: IO (Path Abs (Dir UserCacheDir))
getUserCacheDirPath = SD.getXdgDirectory SD.XdgCache "" >>= SP.parseAbsDir

data TelemetryCacheDir

ensureTelemetryCacheDirExists :: IO (Path Abs (Dir TelemetryCacheDir))
ensureTelemetryCacheDirExists = do
    userCacheDirPath <- getUserCacheDirPath
    SD.createDirectoryIfMissing False $ SP.toFilePath userCacheDirPath
    let telemetryCacheDirPath = getTelemetryCacheDirPath userCacheDirPath
    SD.createDirectoryIfMissing True $ SP.toFilePath telemetryCacheDirPath
    return telemetryCacheDirPath

getTelemetryCacheDirPath :: Path Abs (Dir UserCacheDir) -> Path Abs (Dir TelemetryCacheDir)
getTelemetryCacheDirPath userCacheDirPath = userCacheDirPath SP.</> SP.fromPathRelDir [reldir|wasp/telemetry|]
