module HaskellTools.Database
    ( insertRepos
    , insertPkgs
    , insertDeps
    ) where

import Pasta ( insert
             , doUpdate
             , doNothing
             , onConflict
             , (=.=)
             , (//)
             , showt
             , fromList
             )
import qualified Hasql.Connection as H
import qualified Hasql.Session as H
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import Data.Monoid ((<>))
import HaskellTools.Github
import HaskellTools.Hackage
import Data.Scientific (toBoundedInteger)
import Data.Maybe (fromMaybe)
import Control.Lens
import Distribution.PackageDescription
import Distribution.Package
import Distribution.Text
import Language.Haskell.Extension

insertRepos :: H.Connection -> [Repo] -> IO ()
insertRepos = runInserts insertRepo

insertPkgs :: H.Connection -> [PackageDescription] -> IO ()
insertPkgs = runInserts insertPkg

insertDeps :: H.Connection -> [PackageWithDeps] -> IO ()
insertDeps = runInserts insertPackageWithDeps

insertRepo :: Repo -> T.Text
insertRepo r =
  showt $
  insert "public.repos" columns values
  & onConflict .~ doUpdate "repos_pkey" ["watchers" =.= ("EXCLUDED"//"watchers"), "forks" =.= ("EXCLUDED"//"forks")]
  where
    columns = fromList ["repo_name", "owner", "url", "watchers", "forks"]
    values = fromList [name r, owner r, url r, s2t $ watchers r, s2t $ forks r]
    s2t = T.pack . show . fromMaybe (0 :: Int) . toBoundedInteger

runInserts :: (a -> T.Text) -> H.Connection -> [a] -> IO ()
runInserts insertFn con pkgs =
  mapM_ (runSQL . T.encodeUtf8) cmds
  where
    cmds = insertFn <$> pkgs
    runSQL cmd = do
      resOrError <- H.run (H.sql cmd) con
      case resOrError of
        Left _ -> print ("Error inserting..." :: String)
        Right _ -> print ("Inserted..." :: String)

p2name :: PackageDescription -> T.Text
p2name = T.pack . display . pkgName . package

insertPkg :: PackageDescription -> T.Text
insertPkg p =
  showt $
  insert "public.packages" columns values
  & onConflict .~ doUpdate "packages_pkey" ["version" =.= ("EXCLUDED"//"version")]
  where
    columns = fromList ["package_name", "version", "license", "description", "category", "homepage", "package_url", "repo_type", "repo_location"]
    values = fromList [p2name p, p2version p, p2license p, p2desc p, p2cat p, p2homepage p, p2pkgUrl p, p2repoType, p2repoLocation]
    p2version = T.pack . display . pkgVersion . package
    p2license = T.pack . display . license
    p2desc = T.pack . description
    p2cat = T.pack . category
    p2homepage = T.pack . homepage
    p2pkgUrl = T.pack . pkgUrl
    repos = sourceRepos p
    reposTypes = map (T.pack . display . fromMaybe (OtherRepoType "Unkonwn") . repoType) repos
    reposLocations = map (T.pack . fromMaybe "NULL" . repoLocation) repos
    p2repoType = if null reposTypes
                    then "NULL"
                    else head reposTypes
    p2repoLocation = if null reposLocations
                        then "NULL"
                        else head reposLocations

insertPackageWithDeps :: PackageWithDeps -> T.Text
insertPackageWithDeps (pd, e, d) =
  T.concat (insertDep pd <$> d)
  <> T.concat (insertExt pd <$> e)

insertDep :: PackageDescription -> Dependency -> T.Text
insertDep p d =
  showt $
  insert "public.dependencies" columns values
  & onConflict .~ doUpdate "dependencies_pkey" ["version_range" =.= ("EXCLUDED"//"version_range")]
  where
    columns = fromList ["dependent", "dependency", "version_range"]
    values = fromList [p2name p, d2depdency d, d2version d]
    d2depdency (Dependency n _) = T.pack $ display n
    d2version  (Dependency _ v) = T.pack $ display v

insertExt :: PackageDescription -> Extension -> T.Text
insertExt p e =
  showt $
  insert "public.extensions" columns values
  & onConflict .~ doNothing
  where
    columns = fromList ["package_name", "extension"]
    values = fromList [p2name p, e2extension e]
    e2extension = T.pack . display
