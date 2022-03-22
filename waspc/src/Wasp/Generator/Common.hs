module Wasp.Generator.Common
  ( ProjectRootDir,
    nodeVersion,
    nodeVersionBounds,
    npmVersionBounds,
    prismaVersionBounds,
  )
where

import qualified Wasp.SemanticVersion as SV

-- | Directory where the whole web app project (client, server, ...) is generated.
data ProjectRootDir

-- | Node version that node packages generated by this generator expect.
nodeVersion :: SV.Version
nodeVersion = SV.Version 16 0 0 -- Latest LTS version.

nodeVersionBounds :: SV.VersionBounds
nodeVersionBounds = SV.BackwardsCompatibleWith nodeVersion

npmVersion :: SV.Version
npmVersion = SV.Version 8 0 0 -- Latest LTS version.

npmVersionBounds :: SV.VersionBounds
npmVersionBounds = SV.BackwardsCompatibleWith npmVersion

prismaVersion :: SV.Version
prismaVersion = SV.Version 3 9 1

prismaVersionBounds :: SV.VersionBounds
prismaVersionBounds = SV.Exact prismaVersion
