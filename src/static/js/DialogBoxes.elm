module DialogBoxes (..) where

import Array exposing (Array, toList, fromList)
import Html exposing (Html)
import Maybe.Extra exposing (isJust, join)
import String


-- Local modules

import Character
import DialogBox
import Helpers exposing (..)


-- Helpers for multiple boxes


type alias Model =
    { boxes : Array DialogBox.Model
    , character : Maybe Character.Name
    , focusIndex : Int
    }


init : Model
init =
    { boxes =
        fromList
            [ DialogBox.init (Just "") 1
            , DialogBox.init Nothing 2
            , DialogBox.init Nothing 3
            ]
    , character = Nothing
    , focusIndex = 0
    }


count : Model -> Int
count model =
    Array.length <| Array.filter (isJust << .text) model.boxes


concat : Model -> String
concat model =
    String.join "" <| Array.toList <| Array.map (Maybe.withDefault "" << .text) model.boxes


getText : Int -> Model -> String
getText i model =
    Maybe.withDefault "" <| (Array.get i model.boxes `Maybe.andThen` .text)


getTexts : Model -> Array (Maybe String)
getTexts model =
    Array.map .text model.boxes


getImgSrcs : Model -> List String
getImgSrcs model =
    takeJusts <| Array.map .imgSrc model.boxes


viewable : Model -> Bool
viewable model =
    List.any isJust (toList <| Array.map DialogBox.certifyModel model.boxes)



-- View


view : Signal.Address Action -> Model -> List Html
view address model =
    case model.character of
        Nothing ->
            []

        Just chara ->
            Array.toList
                <| Array.indexedMap
                    (\i -> DialogBox.view (Signal.forwardTo address (UpdateText i)) chara)
                    model.boxes



-- Update


dialogStringTexts : Bool -> String -> Array String
dialogStringTexts skipBlanks s =
    let
        filterFunc =
            if skipBlanks then
                takeNonEmpty
            else
                takeJusts

        newTexts =
            fromList <| filterFunc <| fromList <| splitLinesEvery 3 2 s
    in
        case toList newTexts of
            [] ->
                fromList [ "" ]

            something ->
                newTexts


textsToString : Array (Maybe String) -> String
textsToString texts =
    String.join "\n" <| takeJusts texts


textWithUpdate : Int -> String -> Array (Maybe String) -> String
textWithUpdate entryBoxIndex newBoxText oldTexts =
    textsToString
        <| Array.set entryBoxIndex (Just newBoxText) oldTexts


pad : Int -> a -> List a -> List a
pad len item xs =
    xs ++ List.repeat (len - List.length xs) item


updateText : Int -> String -> Array (Maybe String) -> ( Int, List (Maybe String) )
updateText boxIndex newBoxText oldTexts =
    let
        prevBoxText =
            Maybe.withDefault "" <| join <| Array.get boxIndex oldTexts

        -- if we're removing text, wipe out empty dialog boxes
        skipBlanks =
            (String.length newBoxText) < (String.length prevBoxText)

        newTexts =
            dialogStringTexts skipBlanks <| textWithUpdate boxIndex newBoxText oldTexts
    in
        ( if Array.length newTexts /= List.length (takeJusts oldTexts) then
            Array.length newTexts
          else
            (boxIndex + 1)
        , pad 3 Nothing <| List.map (Just << takeLines 3) (toList newTexts)
        )


updateMany : DialogBox.Action -> Model -> Model
updateMany action model =
    { model
        | boxes = Array.map (DialogBox.update action) model.boxes
    }


type Action
    = SetCharacter Character.Name
    | SetImages String
    | UpdateText Int String


update : Action -> Model -> ( Model, Bool )
update action model =
    case action of
        SetCharacter chara ->
            ( { model
                | character = Just chara
              }
            , False
            )

        SetImages src ->
            ( updateMany (DialogBox.SetImage src) model
            , False
            )

        UpdateText index txt ->
            let
                ( focusBoxNum, newTexts ) =
                    updateText
                        index
                        txt
                        (getTexts model)
            in
                ( { model
                    | boxes =
                        fromList
                            <| List.map
                                (\( s, box ) -> DialogBox.update (DialogBox.SetText s) box)
                            <| List.map2 (,) newTexts (toList model.boxes)
                    , focusIndex = focusBoxNum
                  }
                , True
                )