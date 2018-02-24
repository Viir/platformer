module Game.View exposing (view)

import Array
import Game.Logic.World as Logic
import Game.Model as Game
import Game.TextureLoader as TextureLoader
import Game.View.Object as ObjectView
import Game.View.Object.Animated as AnimatedObject
import Game.View.TileLayer as TileLayer
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import QuadTree
import Slime
import Util.Level as Level
import WebGL exposing (Mesh, Shader, Texture)


hexColor2Vec3 : String -> Result String Vec3
hexColor2Vec3 str =
    let
        withoutHash =
            if String.startsWith "#" str then
                String.dropLeft 1 str
            else
                str
    in
    case String.toList withoutHash of
        [ r1, r2, g1, g2, b1, b2 ] ->
            let
                makeFloat a b =
                    String.fromList [ '0', 'x', a, b ]
                        |> String.toInt
                        |> Result.map (\i -> toFloat i / 255)
            in
            Result.map3 vec3 (makeFloat r1 r2) (makeFloat g1 g2) (makeFloat b1 b2)

        _ ->
            "Can not parse hex color:" ++ str |> Result.Err


getAt : Int -> List a -> Maybe a
getAt idx xs =
    if idx < 0 then
        Nothing
    else
        List.head <| List.drop idx xs



-- Add linght raycasting
-- https://stackoverflow.com/questions/34708021/how-to-implement-2d-raycasting-light-effect-in-glsl
--https://github.com/mattdesl/lwjgl-basics/wiki/2D-Pixel-Perfect-Shadows


view : Game.Model -> List WebGL.Entity
view model =
    if model.level.layers == [] then
        []
    else
        let
            result =
                List.foldr
                    (\layer acc ->
                        case layer of
                            Level.ImageLayer _ ->
                                acc

                            Level.ObjectLayer _ ->
                                let
                                    -- Animated
                                    animations =
                                        (Slime.entities2 Logic.sprites Logic.boundingBoxes).getter model.world
                                            |> List.foldr foldingAnimations []

                                    -- TODO MOVE THAT LOGIC TO Game.LevelLoaded
                                    foldingAnimations { a, b } acc =
                                        let
                                            { boundingBox } =
                                                b
                                        in
                                        case
                                            ( TextureLoader.get ("Tiles::" ++ a.name) model.textures
                                            , List.filter
                                                (\item_ ->
                                                    case item_ of
                                                        Level.TilesetEmbedded item ->
                                                            item.name == a.name

                                                        _ ->
                                                            False
                                                )
                                                model.level.tilesets
                                            )
                                        of
                                            ( Just image, [ Level.TilesetEmbedded tileset ] ) ->
                                                acc
                                                    ++ [ AnimatedObject.render
                                                            { widthRatio = model.widthRatio
                                                            , x = boundingBox.horizontal.low
                                                            , y = boundingBox.vertical.low
                                                            , width = QuadTree.width boundingBox
                                                            , height = QuadTree.height boundingBox
                                                            , sprite = image
                                                            , runtime = model.world.runtime
                                                            , transparentcolor = hexColor2Vec3 tileset.transparentcolor |> Result.withDefault (vec3 0.0 0.0 0.0)

                                                            --tilesPerUnit * tileSize
                                                            , pixelsPerUnit = 160.0
                                                            }
                                                       ]

                                            _ ->
                                                acc

                                    foldingObjects { a } acc =
                                        let
                                            { boundingBox } =
                                                a
                                        in
                                        acc
                                            ++ [ ObjectView.render
                                                    { widthRatio = model.widthRatio
                                                    , x = boundingBox.horizontal.low
                                                    , y = boundingBox.vertical.low
                                                    , width = QuadTree.width boundingBox
                                                    , height = QuadTree.height boundingBox

                                                    --tilesPerUnit * tileSize
                                                    , pixelsPerUnit = 160.0
                                                    }
                                               ]

                                    boundingBoxes =
                                        (Slime.entities Logic.boundingBoxes).getter model.world
                                            |> List.foldr foldingObjects []
                                in
                                animations
                                    -- ++ boundingBoxes
                                    ++ acc

                            Level.TileLayer data ->
                                case
                                    ( TextureLoader.get "Tiles::area01_level_tiles" model.textures
                                    , TextureLoader.get ("Layer.Data::" ++ data.name) model.textures
                                    , getAt 0 model.level.tilesets
                                    )
                                of
                                    ( Just image, Just dataImage, Just (Level.TilesetEmbedded tileset) ) ->
                                        TileLayer.render
                                            { widthRatio = model.widthRatio

                                            -- , viewportOffset = vec2 (sin (model.runtime / 1000)) (cos (model.runtime / 500))
                                            , viewportOffset = vec2 0.0 0.0
                                            , pixelsPerUnit = 160.0 --tilesPerUnit = 10.0
                                            , lut = dataImage
                                            , lutSize = vec2 (toFloat data.width) (toFloat data.height)
                                            , tileSet = image
                                            , tileSetSize = vec2 (toFloat tileset.imagewidth / toFloat tileset.tilewidth) (toFloat tileset.imageheight / toFloat tileset.tileheight)
                                            , tileSize = vec2 (toFloat tileset.tilewidth) (toFloat tileset.tileheight)
                                            , transparentcolor = hexColor2Vec3 tileset.transparentcolor |> Result.withDefault (vec3 0.0 0.0 0.0)
                                            }
                                            :: acc

                                    _ ->
                                        acc
                    )
                    []
                    model.level.layers
        in
        result
