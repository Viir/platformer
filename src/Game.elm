port module Game exposing (World, document)

import Browser exposing (Document, UrlRequest(..))
import Browser.Events as Browser
import Defaults exposing (default)
import Dict
import Environment exposing (Environment)
import Error exposing (Error(..))
import Http
import Layer exposing (Layer)
import Logic.GameFlow as Flow
import ResourceManager exposing (RemoteData(..))
import ResourceTask exposing (ResourceTask)
import Task
import WebGL
import World
import World.Camera exposing (Camera)
import World.Create
import World.Create2
import World.Render


type alias World world obj =
    World.World world obj


type alias Model world obj delme =
    { env : Environment
    , loader : RemoteData Http.Error (World world obj)
    , resource : delme
    }


type Message world obj defineMe
    = Environment Environment.Message
    | Loader (ResourceManager.RemoteData Http.Error (World world obj))
    | Frame Float
    | Subscription ( Flow.Model { camera : Camera, layers : List (Layer obj) }, world )
    | Resource (Result Error ( defineMe, Dict.Dict String ResourceTask.Response ))


port start : () -> Cmd msg



-- document : Program Json.Value Model Message


document { init, system, read, view, subscriptions } =
    Browser.document
        { init = init_ init read
        , view = view_ view
        , update = update system
        , subscriptions =
            \model_ ->
                case model_.loader of
                    Success (World.World world1 world2) ->
                        [ Environment.subscriptions model_.env |> Sub.map Environment
                        , Browser.onAnimationFrameDelta Frame
                        , subscriptions ( world1, world2 ) |> Sub.map Subscription
                        ]
                            |> Sub.batch

                    _ ->
                        Environment.subscriptions model_.env |> Sub.map Environment
        }


init_ empty read flags =
    let
        ( env, envMsg ) =
            Environment.init flags

        ( loader, loaderMsg ) =
            ResourceManager.init
                (World.Create.init read
                    (\camera layers ->
                        World.World
                            { camera = camera
                            , layers = layers
                            , frame = 0
                            , runtime_ = 0
                            , flow = Flow.Running
                            }
                            empty
                    )
                )
                Task.fail
                flags

        resourceTask =
            ResourceTask.init
                |> ResourceTask.getLevel "/assets/demo.json"
                |> ResourceTask.andThenWithCache World.Create2.init
    in
    ( { env = env
      , loader = loader
      , resource = []
      }
    , Cmd.batch
        [ envMsg |> Cmd.map Environment
        , loaderMsg |> Cmd.map Loader
        , ResourceTask.attemptDebug Resource resourceTask
        ]
    )


update system msg model =
    let
        wrap m data =
            { m | loader = Success (data |> (\( a, b ) -> World.World a b)) }
    in
    case ( msg, model.loader ) of
        ( Frame delta, Success (World.World world ecs) ) ->
            ( Flow.updateWith system delta ( world, ecs ) |> wrap model
            , Cmd.none
            )

        ( Subscription custom, Success (World.World world ecs) ) ->
            ( custom |> wrap model, Cmd.none )

        ( Environment info, _ ) ->
            ( { model | env = Environment.update info model.env }, Cmd.none )

        ( Loader (Success info), _ ) ->
            ( { model | loader = Success info }, start () )

        ( Loader info, _ ) ->
            ( { model | loader = info }, Cmd.none )

        ( Resource (Ok resource), _ ) ->
            let
                good =
                    resource
                        |> Tuple.first

                --                        |> List.length
                --                        |> Debug.log "got:Resource in Main update"
            in
            ( { model | resource = good }, Cmd.none )

        ( Resource (Err e), _ ) ->
            let
                bad =
                    e
                        |> Debug.log "got:Resource in Main update AS ERROR"
            in
            ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )



-- view_ : Model world obj -> Document (Message world obj)


view_ objRender model =
    case ( model.loader, model.resource ) of
        ( Loading, _ ) ->
            { title = "Loading"
            , body =
                [ WebGL.toHtmlWith default.webGLOption (Environment.style model.env) []
                ]
            }

        ( Failure e, _ ) ->
            { title = "Failure"
            , body =
                [ WebGL.toHtmlWith default.webGLOption (Environment.style model.env) []
                ]
            }

        ( Success (World.World world ecs), xs ) ->
            let
                testWorld =
                    { world | layers = xs }

                --                    world
            in
            { title = "Success"
            , body =
                [ World.Render.view objRender model.env testWorld ecs
                    |> WebGL.toHtmlWith default.webGLOption
                        (Environment.style model.env)
                ]
            }
