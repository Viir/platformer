module Tiled.Read.Camera exposing (read, readId)

import Defaults exposing (default)
import Dict
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Parser exposing ((|.), (|=), Parser)
import Set
import Tiled.Read exposing (Read(..), defaultRead)
import Tiled.Util exposing (levelProps)
import World.Component.Camera as Component


readId spec_ =
    let
        baseRead =
            read_ Component.emptyWithId spec_
    in
    { baseRead
        | objectTile =
            Sync
                (\{ x, y, properties } ( entityID, world ) ->
                    properties
                        |> Dict.filter (\a _ -> String.startsWith "camera" a)
                        |> Dict.keys
                        |> List.foldl
                            (\item (( eID, w ) as acc) ->
                                case Parser.run getFollowId item of
                                    Ok ( "follow", "x" ) ->
                                        let
                                            cam =
                                                spec_.get w
                                        in
                                        ( eID
                                        , spec_.set { cam | id = eID } w
                                        )

                                    _ ->
                                        acc
                            )
                            ( entityID, world )
                )
    }


read =
    read_ Component.empty


read_ empty_ spec_ =
    { defaultRead
        | level =
            Sync
                (\level ( entityID, world ) ->
                    let
                        cameraComp =
                            levelProps level
                                |> (\prop ->
                                        let
                                            x =
                                                default.viewportOffset
                                                    |> Vec2.getX
                                                    |> prop.float "offset.x"

                                            y =
                                                default.viewportOffset
                                                    |> Vec2.getX
                                                    |> prop.float "offset.y"
                                        in
                                        { empty_
                                            | pixelsPerUnit = prop.float "pixelsPerUnit" default.pixelsPerUnit
                                            , viewportOffset = vec2 x y
                                        }
                                   )
                    in
                    ( entityID, spec_.set cameraComp world )
                )
    }


getFollowId =
    let
        var =
            Parser.variable
                { start = Char.isAlphaNum
                , inner = \c -> Char.isAlphaNum c || c == '_'
                , reserved = Set.empty
                }
    in
    Parser.succeed (\a b -> ( a, b ))
        |. Parser.keyword "camera"
        |. Parser.symbol "."
        |= var
        |. Parser.symbol "."
        |= var
        |. Parser.end