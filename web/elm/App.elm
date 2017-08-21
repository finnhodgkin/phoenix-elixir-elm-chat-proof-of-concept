module App exposing (..)

import Html exposing (..)
import Html.Attributes exposing (placeholder, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Json.Decode as JD exposing (field)
import Json.Encode as JE
import Phoenix.Channel
import Phoenix.Push
import Phoenix.Socket
import Platform.Cmd


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


socketServer : String
socketServer =
    "ws://localhost:4000/socket/websocket"


type alias Model =
    { newMessage : String
    , newMessagePlaceholder : String
    , messages : List String
    , name : String
    , nameError : String
    , phxSocket : Phoenix.Socket.Socket Msg
    }


type Msg
    = SendMessage
    | SetNewMessage String
    | NoMessage
    | PhoenixMsg (Phoenix.Socket.Msg Msg)
    | ReceiveChatMessage JE.Value
    | ShowJoinedMessage String
    | ShowLeftMessage String
    | SetNewName String
    | MessageNoName
    | NoOp


init : ( Model, Cmd Msg )
init =
    let
        channel =
            Phoenix.Channel.init "room:lobby"

        ( initSocket, phxCmd ) =
            Phoenix.Socket.init "ws://localhost:4000/socket/websocket"
                |> Phoenix.Socket.withDebug
                |> Phoenix.Socket.on "new:msg" "room:lobby" ReceiveChatMessage
                |> Phoenix.Socket.join channel
    in
    ( Model "" "" [] "" "" initSocket, Cmd.map PhoenixMsg phxCmd )


subscriptions : Model -> Sub Msg
subscriptions model =
    Phoenix.Socket.listen model.phxSocket PhoenixMsg


type alias ChatMessage =
    { body : String
    , user : String
    }


chatMessageDecoder : JD.Decoder ChatMessage
chatMessageDecoder =
    JD.map2 ChatMessage (field "body" JD.string) (field "user" JD.string)


userParams : JE.Value
userParams =
    JE.object [ ( "user_id", JE.string "123" ) ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PhoenixMsg msg ->
            let
                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.update msg model.phxSocket
            in
            ( { model | phxSocket = phxSocket }
            , Cmd.map PhoenixMsg phxCmd
            )

        SendMessage ->
            let
                payload =
                    JE.object [ ( "user", JE.string model.name ), ( "body", JE.string model.newMessage ) ]

                push_ =
                    Phoenix.Push.init "new:msg" "room:lobby"
                        |> Phoenix.Push.withPayload payload

                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.push push_ model.phxSocket
            in
            ( { model | newMessage = "", phxSocket = phxSocket }
            , Cmd.map PhoenixMsg phxCmd
            )

        SetNewMessage str ->
            ( { model | newMessage = str, newMessagePlaceholder = "" }
            , Cmd.none
            )

        NoMessage ->
            ( { model | newMessagePlaceholder = "Enter a message to send" }, Cmd.none )

        ReceiveChatMessage raw ->
            case JD.decodeValue chatMessageDecoder raw of
                Ok chatMessage ->
                    ( { model | messages = (chatMessage.user ++ ": " ++ chatMessage.body) :: model.messages }
                    , Cmd.none
                    )

                Err error ->
                    ( model, Cmd.none )

        ShowJoinedMessage channelName ->
            ( { model | messages = ("Joined channel " ++ channelName) :: model.messages }
            , Cmd.none
            )

        ShowLeftMessage channelName ->
            ( { model | messages = ("Left channel " ++ channelName) :: model.messages }
            , Cmd.none
            )

        SetNewName name ->
            { model | name = name, nameError = "" } ! []

        MessageNoName ->
            { model | nameError = "Please enter a valid username to join the chat." } ! []

        NoOp ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div []
        [ userName model
        , h3 [] [ text "Messages:" ]
        , form [ onSubmit (sendMessage model) ]
            [ input [ type_ "text", value model.newMessage, onInput SetNewMessage, placeholder model.newMessagePlaceholder ] []
            ]
        , ul [] ((List.reverse << List.map renderMessage) model.messages)
        ]


userName : Model -> Html Msg
userName model =
    let
        html =
            case model.nameError of
                "" ->
                    div [] [ input [ type_ "text", value model.name, onInput SetNewName, placeholder "Username" ] [] ]

                _ ->
                    div []
                        [ input [ type_ "text", value model.name, onInput SetNewName, placeholder "Username" ] []
                        , div [] [ text model.nameError ]
                        ]
    in
    html


sendMessage : Model -> Msg
sendMessage model =
    case model.newMessage of
        "" ->
            NoMessage

        _ ->
            case model.name of
                "" ->
                    MessageNoName

                _ ->
                    SendMessage


renderMessage : String -> Html Msg
renderMessage str =
    li [] [ text str ]
