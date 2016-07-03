module HaskellTools.PackageList exposing (Model, Msg(..), view, update, init)

import Html exposing (Html, ul, li, text, a, div, h4, p)
import Html.Attributes exposing (href, target)
import Task
import String

import Json.Encode as Encode
import Json.Decode exposing (Decoder, succeed, string, list, int, at, (:=))
import Json.Decode.Extra exposing (..)

import HttpBuilder exposing(..)

import HaskellTools.Api exposing (..)

type Msg
  = FetchPackages (Result String Model)
  | SearchPackages String

type alias Model = List Package

type alias Package =
  { package_name  : String
  , version       : String
  , license       : String
  , description   : String
  , category      : String
  , homepage      : String
  , package_url   : String
  , repo_type     : String
  , repo_location : String
  , stars         : Int
  , forks         : Int
  , collaborators : Int
  , extensions    : List String
  , dependencies  : List String
  , dependents  : List String
  , created_at    : String
  , updated_at    : String
}

view : Model -> Html msg
view model =
  ul
    []
    (List.map packageView model)


update : Msg -> Model -> ( Model, Cmd Msg )
update action model =
  case action of
    SearchPackages query ->
        if String.length query > 0
        then ( model, searchPackages query )
        else ( [], Cmd.none )
    FetchPackages result ->
      case result of
        Ok pkgs ->
          ( pkgs, Cmd.none )
        Err error ->
          ( model, Cmd.none )

init : (Model, Cmd Msg)
init = ([], Cmd.none)

-- private functions
packagesUrl : String
packagesUrl = apiUrl "/packages"

searchUrl : String
searchUrl = apiUrl "/rpc/package_search"

getPackages : Cmd Msg
getPackages =
  get packagesUrl
    |> (send (jsonReader decodeModel) stringReader)
    |> Task.perform toError toOk

searchPackages : String -> Cmd Msg
searchPackages query =
    let
        body = Encode.object
               [ ("query", Encode.string query) ]
    in
        post searchUrl
            |> withHeaders [("Content-Type", "application/json"), ("Accept", "application/json")]
            |> withJsonBody body
            |> (send (jsonReader decodeModel) stringReader)
            |> Task.perform toError toOk

toError : a -> Msg
toError _ = FetchPackages (Err "Err")

toOk : Response Model -> Msg
toOk r = FetchPackages (Ok r.data)

decodeModel : Decoder Model
decodeModel =
  list (
    succeed Package
      |: ("package_name" := string)
      |: ("version" := string)
      |: ("license" := string)
      |: ("description" := string)
      |: ("category" := string)
      |: ("homepage" := string)
      |: ("package_url" := string)
      |: ("repo_type" := string)
      |: ("repo_location" := string)
      |: ("stars" := int)
      |: ("forks" := int)
      |: ("collaborators" := int)
      |: ("extensions" := (list string))
      |: ("dependencies" := (list string))
      |: ("dependents" := (list string))
      |: ("created_at" := string)
      |: ("updated_at" := string)
  )

separator : Html msg
separator = text " - "

packageView : Package -> Html msg
packageView model =
  li
    []
    [ p
      []
      [ h4 [] [ text model.package_name ]
      , ul
        []
        [ li [] [text model.description]
        , li [] [text ("Category: " ++ model.category)]
        , li []
          [ a
            [ href ("http://hackage.haskell.org/package/" ++ model.package_name), target "blank" ]
            [ text "Hackage" ]
          , separator
          , a
            [ href model.repo_location, target "blank" ]
            [ text "Source code" ]
          ]
        , li []
          [ text ((toString (List.length model.dependencies)) ++ " Dependencies")
          , separator
          , text ((toString (List.length model.dependents)) ++ " Dependents")
          , separator
          , text ((toString model.stars) ++ " Stars")
          , separator
          , text ((toString model.forks) ++ " Forks")
          , separator
          , text ((toString model.collaborators) ++ " Collaborators")
          ]
        ]
      ]
    ]
