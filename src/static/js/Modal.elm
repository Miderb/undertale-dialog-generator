module Modal where

import Color exposing (Color)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Maybe exposing (Maybe)
import String


type alias Model =
  { backgroundColor : Color
  , childElement : Maybe SizedHtml
  }


type alias SizedHtml =
  { html : Html
  , width : String
  , height : String
  }


init : Color -> Model
init color =
  { backgroundColor = color
  , childElement = Nothing
  }


type Action = Show (Maybe SizedHtml) | NoOp


update action model =
  case action of
    Show something ->
      { model
      | childElement = something
      }
    NoOp -> model


partlyTransparent : Color -> String
partlyTransparent color =
  let rgb = (Color.toRgb color) in
    "rgba("
    ++ (String.join ", " <| List.map toString
        [ rgb.red
        , rgb.green
        , rgb.blue
        ]
       )
    ++ ", 0.7)"


backgroundAttrs address color =
  [ onClick address <| (Show Nothing)
  , style
    [ ("backgroundColor", partlyTransparent color)
    , ("height", "100%")
    , ("width", "100%")
    , ("position", "fixed")
    , ("top", "0")
    , ("left", "0")
    , ("z-index", "99999")
    , ("-webkit-transition", "opacity 400ms ease-in")
    , ("-moz-transition", "opacity 400ms ease-in")
    , ("transition", "opacity 400ms ease-in")
    ]
  ]


wrapperDiv : SizedHtml -> List Html
wrapperDiv inner =
  [ div
    [ style
      [ ("width", inner.width)
      , ("height", inner.height)
      , ("overflow", "auto")
      , ("margin", "auto")
      , ("position", "absolute")
      , ("top", "0")
      , ("left", "0")
      , ("bottom", "0")
      , ("right", "0")
      ]
    ]
    [ inner.html ]
  ]


view : Signal.Address Action -> Model -> Html
view address model =
  case model.childElement of
    Nothing -> div [ ] [ ]
    Just dialog ->
      div
      ( backgroundAttrs address model.backgroundColor )
      ( wrapperDiv dialog )
