module UndertaleDialog (..) where

import Debug exposing (log)

import StartApp exposing (start)
import Array exposing (Array, toList, fromList)
import Character
import Color exposing (grayscale)
import Effects exposing (Effects, Never, none)
import Either exposing (Either)
import Html exposing (..)
import Html.Events exposing (on, targetValue, onClick, onKeyPress)
import Html.Attributes exposing (class, src, style)
import Http
import Json.Decode exposing (object2, string, (:=))
import Maybe exposing (Maybe, andThen)
import Maybe.Extra exposing (combine, isJust, join, maybeToList)
import Task
import Focus
import Helpers exposing (..)
import Imgur
import Modal


-- Local modules
-- Could split the image map stuff into a different module

import CreditsModal exposing (creditsDialog, mapArea)
import DialogBoxes


-- Model


type alias Model =
    { characters : List Character.Name
    , selection : Maybe Character.Name
    , dialogs : DialogBoxes.Model
    , staticRoot : String
    , scriptRoot : String
    , imageData : Maybe String
    , modal : Modal.Model
    , focusAddress : Signal.Address Focus.Action
    , imgur : Imgur.Model
    }


init : List Character.Name -> Signal.Address Focus.Action -> Model
init characters focusAddress =
    { characters = characters
    , selection = Nothing
    , dialogs = DialogBoxes.init
    , staticRoot = "/static/"
    , scriptRoot = ""
    , imageData = Nothing
    , modal = Modal.init <| grayscale 1
    , focusAddress = focusAddress
    , imgur = Imgur.init
    }



-- View
-- General styles


flatButton : List ( String, String )
flatButton =
    [ ( "backgroundColor", "transparent" )
    , ( "border", "none" )
    ]


header : Html
header =
    div
        []
        [ hr [ style [ ( "margin-bottom", "30px" ) ] ] [] ]


maybeDivider : Maybe a -> Html
maybeDivider choice =
    case choice of
        Nothing ->
            blank

        Just a ->
            header


blank : Html
blank =
    div [] []


titleImgMap : Signal.Address Action -> Html
titleImgMap address =
    Html.node
        "map"
        [ Html.Attributes.id "titleMap"
        , Html.Attributes.name "titleMap"
        ]
        [ mapArea [ 606, 43, 626, 61 ] "hOI!"
            <| Either.Right
            <| ( address, ChooseCharacter Character.Temmie )
        ]


title root address =
    div
        [ style
            [ ( "padding-top", "100px" )
            , ( "padding-bottom", "30px" )
            , ( "display", "block" )
            ]
        ]
        [ img
            [ style
                [ ( "margin", "0 auto" )
                , ( "display", "block" )
                ]
            , src <| root ++ "images/title.png"
            , Html.Attributes.usemap "#titleMap"
            ]
            []
        , titleImgMap address
        ]



-- Character section


spriteFolder : String -> Character.Name -> String
spriteFolder root c =
    root ++ "images/sprites/" ++ toString c


spriteNumber : String -> Character.Name -> Int -> String
spriteNumber root c n =
    (spriteFolder root c) ++ "/" ++ (toString n) ++ ".png"


defaultSprite : String -> Character.Name -> String
defaultSprite root c =
    spriteNumber root c 0


characterButton : Signal.Address Action -> String -> Character.Name -> Html
characterButton address staticRoot c =
    case c of
        Character.Temmie ->
            blank

        _ ->
            button
                [ onClick address <| ChooseCharacter c
                , style flatButton
                ]
                [ img [ src <| defaultSprite staticRoot c ] [] ]


characterButtons : Signal.Address Action -> String -> List Character.Name -> Html
characterButtons address root characters =
    div
        []
        [ ul
            [ class "characters" ]
            <| List.map (characterButton address root) characters
        ]



-- Mood section


moodButton : Signal.Address Action -> String -> Character.Name -> Int -> Html
moodButton address root c n =
    let
        spriteStr = spriteNumber root c n
    in
        button
            [ onClick address <| ChooseMood spriteStr
            , style flatButton
            ]
            [ img [ src <| spriteStr ] [] ]


moodButtons : Signal.Address Action -> String -> Character.Name -> Html
moodButtons address root c =
    div
        []
        [ ul
            [ class "moods" ]
            <| List.map (moodButton address root c) [1..(Character.moodCount c)]
        ]


moodSection : Signal.Address Action -> String -> Maybe Character.Name -> Html
moodSection address root maybeChar =
    case maybeChar of
        Nothing ->
            blank

        Just c ->
            moodButtons address root c



-- Dialog boxes


crunchyButton : Signal.Address Action -> List Html
crunchyButton address =
    [ div
        [ style [ ( "width", "100%" ) ] ]
        [ Html.button
            [ onClick address <| GetDownload
            , Html.Attributes.id "crunchybutton"
            ]
            [ text "MAKE IT CRUNCHY" ]
        ]
    ]


dialogBoxTexts : Array (Maybe String) -> List String
dialogBoxTexts arr =
    case join (Array.get 0 arr) of
        Nothing ->
            [ "" ]

        Just first ->
            [ first ] ++ takeJusts (Array.slice 1 3 arr)


numBoxes : Array (Maybe String) -> Int
numBoxes texts =
    List.length <| dialogBoxTexts texts


dialogBoxImg : DialogBoxes.Model -> Signal.Address Action -> String -> List Html
dialogBoxImg boxes address pngData =
    let
        boxCount =
            log "boxCount" <| DialogBoxes.count boxes
    in
        [ Html.a
            []
            [ Html.img
                [ onClick address
                    <| UpdateDialogs (DialogBoxes.UpdateText boxCount (DialogBoxes.getText boxCount boxes))
                , style
                    [ ( "margin", "0 auto" )
                    , ( "display", "block" )
                    ]
                , src pngData
                ]
                []
            ]
        ]


returnedDialogBox : DialogBoxes.Model -> Signal.Address Action -> Maybe String -> Maybe (List Html)
returnedDialogBox boxes address imgData =
    Maybe.map2
        (++)
        (Just "data:image/png;base64,")
        imgData
        `andThen` (Just << dialogBoxImg boxes address)



-- Button for credits modal


infoButton : Signal.Address Action -> String -> Html
infoButton address root =
    button
        [ onClick address
            <| UpdateModal
            <| Modal.Show (Just <| creditsDialog root)
        , style
            <| [ ( "position", "fixed" )
               , ( "bottom", "10px" )
               , ( "right", "20px" )
               ]
            ++ flatButton
        ]
        [ img [ src <| root ++ "images/creditsbutton.png" ] [] ]



-- Main view


textBoxId : Int -> String
textBoxId n =
    "textBox" ++ (toString n)


dialogBoxSection : Signal.Address Action -> Model -> Html
dialogBoxSection address model =
    div
        []
        <| Maybe.withDefault [ blank ]
        <| Maybe.oneOf
            [ Maybe.map2
                (++)
                (returnedDialogBox model.dialogs address model.imageData)
                (Just
                    <| [ Imgur.view (Signal.forwardTo address UpdateImgur) model.imgur
                            <| model.staticRoot
                       ]
                )
            , Just
                <| (DialogBoxes.view (Signal.forwardTo address UpdateDialogs) model.dialogs)
                ++ if DialogBoxes.viewable model.dialogs then (crunchyButton address) else []
            ]


view : Signal.Address Action -> Model -> Html
view address model =
    div
        [ Html.Attributes.id "content" ]
        [ title model.staticRoot address
        , characterButtons address model.staticRoot model.characters
        , maybeDivider model.selection
        , moodSection address model.staticRoot model.selection
        , dialogBoxSection address model
        , infoButton address model.staticRoot
        , Modal.view (Signal.forwardTo address UpdateModal) model.modal
        ]


-- Update


type Action
    = NoOp ()
    | ChooseCharacter Character.Name
    | ChooseMood String
    | UpdateDialogs DialogBoxes.Action
    | SetScriptRoot String
    | SetStaticRoot String
    | GetDownload
    | GotDownload (Maybe String)
    | UpdateModal Modal.Action
    | UpdateImgur Imgur.Action


update : Action -> Model -> ( Model, Effects Action )
update action model =
    case action of
        NoOp () ->
            ( model
            , none
            )

        ChooseCharacter c ->
            let
                ( newBoxes, moveCursor ) = DialogBoxes.update (DialogBoxes.SetCharacter c) model.dialogs
            in
              ( { model
                  | selection = Just c
                  , dialogs = newBoxes
                  , imageData = Nothing
                }
              , none
              )

        ChooseMood s ->
            let
                ( newBoxes, moveCursor ) = DialogBoxes.update (DialogBoxes.SetImages s) model.dialogs
            in
              ( { model
                  | dialogs = newBoxes
                  , imageData = Nothing
                }
              , toFocusEffect
                  model.focusAddress
                  { elementId = textBoxId 1
                  , moveCursorToEnd = moveCursor
                  }
              )

        UpdateDialogs action ->
            let
                ( newBoxes, moveCursor ) = DialogBoxes.update action model.dialogs
            in
                ( { model
                    | dialogs = newBoxes
                    , imageData = Nothing
                  }
                , toFocusEffect
                    model.focusAddress
                    { elementId = textBoxId newBoxes.focusIndex
                    , moveCursorToEnd = moveCursor
                    }
                )

        SetScriptRoot s ->
            ( { model
                | scriptRoot = s
              }
            , getImgurParams s
            )

        SetStaticRoot s ->
            ( { model
                | staticRoot = s
              }
            , none
            )

        GetDownload ->
            ( model
            , getDialogBoxImg model
            )

        GotDownload data ->
            let
                ( newImgur, fx ) = Imgur.update (Imgur.SetImageData data) model.imgur
            in
                ( { model
                    | imageData = data
                    , imgur = newImgur
                  }
                , none
                )

        UpdateModal action ->
            ( { model
                | modal = Modal.update action model.modal
              }
            , none
            )

        UpdateImgur action ->
            let
                ( newImgur, fx ) = Imgur.update action model.imgur
            in
                ( { model
                    | imgur = newImgur
                  }
                , Effects.map UpdateImgur fx
                )



-- Tasks


getSubmitUrl : String -> String
getSubmitUrl root =
    root ++ "/submit"


getDialogBoxImg : Model -> Effects Action
getDialogBoxImg model =
    case model.selection of
        Nothing ->
            none

        Just c ->
            Http.url
                (getSubmitUrl model.scriptRoot)
                ([ ( "character", toString c )
                 , ( "text", DialogBoxes.concat model.dialogs )
                 ]
                    ++ (List.map ((,) "moodImg") <| DialogBoxes.getImgSrcs model.dialogs)
                )
                |> Http.getString
                |> Task.toMaybe
                |> Task.map GotDownload
                |> Effects.task


getImgurParamsUrl : String -> String
getImgurParamsUrl root =
    root ++ "/imgur_id"


imgurParamsDecoder : Json.Decode.Decoder ( String, String )
imgurParamsDecoder =
    object2 (,) ("clientId" := string) ("albumId" := string)


getImgurParams : String -> Effects Action
getImgurParams scriptRoot =
    getImgurParamsUrl scriptRoot
        |> Http.get imgurParamsDecoder
        |> Task.toMaybe
        |> Task.map (\ms -> UpdateImgur <| Imgur.SetParams ms)
        |> Effects.task


toFocusEffect : Signal.Address Focus.Action -> Focus.Params -> Effects Action
toFocusEffect address params =
    Signal.send address (Focus.Focus params) |> Task.map NoOp |> Effects.task



-- Main


app : StartApp.App Model
app =
    start
        { init =
            ( init
                [ Character.Toriel
                , Character.Sans
                , Character.Papyrus
                , Character.Undyne
                , Character.Alphys
                , Character.Asgore
                , Character.Napstablook
                , Character.Mettaton
                , Character.Flowey
                , Character.Temmie
                ]
                toFocusMailbox.address
            , none
            )
        , update = update
        , view = view
        , inputs =
            [ Signal.map SetScriptRoot scriptRoot
            , Signal.map SetStaticRoot staticRoot
            ]
        }


main : Signal Html
main =
    app.html



-- Interop


port scriptRoot : Signal String
port staticRoot : Signal String
port focus : Signal Focus.Params
port focus =
    Signal.filterMap Focus.focusFilter Focus.emptyParams toFocusMailbox.signal


toFocusMailbox =
    Signal.mailbox Focus.NoOp


port tasks : Signal (Task.Task Never ())
port tasks =
    app.tasks
