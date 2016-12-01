module Main where

import HaskellTools

import Pipes
import Hasql.Connection
import Data.String.Conversions (cs)
import Data.Monoid ((<>))

main :: IO ()
main = do
  conf <- readOptions
  let dbConfig = cs $ configDatabase conf
  conOrError <- acquire dbConfig
  case conOrError of
    Left errorMessage -> error $ "Error connecting: " <> (show errorMessage)
    Right c -> if onlyGh conf
      then runEffect $ loopRepos conf c
      else do
        runEffect $ loopPackages c
        runEffect $ loopDeps c
        runEffect $ loopRepos conf c

loopPackages :: Connection -> Effect IO ()
loopPackages con = for (producePackages 0) (lift . insertPkgs con)

loopDeps :: Connection -> Effect IO ()
loopDeps con = for (producePackagesWithDeps 0) (lift . insertDeps con)

loopRepos :: AppConfig -> Connection -> Effect IO ()
loopRepos conf con = do
  reposOrError <- lift $ fetchPackageRepos con
  case reposOrError of
    Left _ -> error "Error fetching repos"
    Right r -> for (produceRepos conf r 0) (lift . insertRepos con)
