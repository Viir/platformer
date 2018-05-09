module Game.Logic.Collision.Map
    exposing
        ( Map
        , cellSize
        , empty
        , getCell
        , insert
        , intersection
        , stepSize
        , table
        , Collider
        , updatePosition
        , position
        )

import Array.Hamt as Array exposing (Array)
import Game.Logic.Collision.Shape as Shape
import Math.Vector2 as Vec2 exposing (Vec2)


-- http://www.metanetsoftware.com/2016/n-tutorial-b-broad-phase-collision


type alias Collider a =
    { a | boundingBox : Shape.AabbData }


type Map a
    = Map
        { table : Table a
        , cellSize : ( Int, Int )
        }


type alias Table a =
    Array (Array (Tile a))


type alias Tile a =
    Maybe (Collider a)


updatePosition : Vec2 -> Collider a -> Collider a
updatePosition p_ ({ boundingBox } as collider) =
    let
        (Shape.AabbData ({ p } as data)) =
            boundingBox
    in
        { collider | boundingBox = Shape.AabbData { data | p = Vec2.add p p_ } }


position : Collider a -> Vec2
position ({ boundingBox } as collider) =
    let
        (Shape.AabbData { p }) =
            boundingBox
    in
        p



-- { shaped | shape = createAABB { data | p = Vec2.add data.p p } }


table : Map a -> Table a
table (Map { table }) =
    table


cellSize : Map a -> ( Int, Int )
cellSize (Map { cellSize }) =
    cellSize


stepSize : Map a -> Float
stepSize (Map { cellSize }) =
    let
        ( w, h ) =
            cellSize
    in
        min (toFloat w / 2) (toFloat h / 2)


get : ( Int, Int ) -> Map a -> Tile a
get ( x, y ) (Map { table }) =
    Array.get y table
        |> Maybe.andThen
            (\row ->
                Array.get x row
            )
        |> Maybe.withDefault Nothing


empty : ( Int, Int ) -> Map a
empty size =
    Map
        { table = Array.empty
        , cellSize = size
        }


insert : Collider a -> Map a -> Map a
insert ({ boundingBox } as shape) (Map ({ cellSize, table } as data)) =
    let
        (Shape.AabbData { p }) =
            boundingBox

        ( xCell, yCell ) =
            getCell p cellSize

        newTable =
            if Array.length table < (yCell + 1) then
                Array.repeat ((yCell + 1) - Array.length table) Array.empty
                    |> Array.append table
            else
                table

        newTable2 =
            Array.get yCell newTable
                |> Maybe.map
                    (\row ->
                        if Array.length row < (xCell + 1) then
                            Array.repeat ((xCell + 1) - Array.length row) Nothing
                                |> Array.append row
                        else
                            row
                    )
                |> Maybe.map
                    (\row ->
                        Array.set xCell (Just shape) row
                    )
                |> Maybe.map (flip (Array.set yCell) newTable)
                |> Maybe.withDefault newTable
    in
        case shape of
            _ ->
                Map { data | table = newTable2 }


intersection : Collider a -> Map b -> List (Collider b)
intersection ({ boundingBox } as shape) ((Map { cellSize }) as collisionMap) =
    let
        (Shape.AabbData { p, xw, yw }) =
            boundingBox

        sum =
            Vec2.add xw yw

        ( x1, y1 ) =
            Vec2.sub p sum
                |> flip getCell cellSize

        ( x2, y2 ) =
            Vec2.add p sum
                |> flip getCell cellSize

        topBottomRow =
            List.range x1 x2
                |> List.map (\x -> [ ( x, y1 ), ( x, y2 ) ])
                -- putin corners at the end
                |> reorderCorners
                |> List.concat

        sides =
            List.range y1 y2
                --remove top and bottom corner tiles, they are already added by `topBottomRow`
                |> (List.drop 1 >> List.reverse >> List.drop 1 >> List.reverse)
                |> List.concatMap (\y -> [ ( x1, y ), ( x2, y ) ])
    in
        (sides ++ topBottomRow)
            |> List.foldr
                (\p acc ->
                    maybeAdd (get p collisionMap) acc
                )
                []


getCell : Vec2 -> ( Int, Int ) -> ( Int, Int )
getCell p cellSize =
    let
        ( x, y ) =
            Vec2.toTuple p

        ( cellWidth, cellHeight ) =
            cellSize

        xCell =
            (x / toFloat cellWidth)
                |> floor

        yCell =
            (y / toFloat cellHeight)
                |> floor
    in
        ( xCell, yCell )


reorderCorners : List a -> List a
reorderCorners list =
    case list of
        [] ->
            []

        a :: b ->
            b ++ [ a ]


maybeAdd : Maybe a -> List a -> List a
maybeAdd item list =
    case item of
        Just data ->
            data :: list

        Nothing ->
            list
