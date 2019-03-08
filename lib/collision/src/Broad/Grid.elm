module Broad.Grid exposing (draw, empty, insert, optimize, query)

import Broad exposing (Boundary)
import Dict exposing (Dict)
import Set exposing (Set)


type alias Config =
    { cellWidth : Float, cellHeight : Float }


empty : Boundary -> Config -> Table a
empty { xmin, xmax, ymin, ymax } config =
    ( Dict.empty
    , { cell = ( config.cellWidth, config.cellHeight )
      , xmin = xmin
      , ymin = ymin
      , cols = abs (xmax - xmin) / config.cellWidth |> ceiling
      , rows = abs (ymax - ymin) / config.cellHeight |> ceiling
      }
    )


type alias Table a =
    ( Dict ( Int, Int ) (Result a)
    , { cols : Int
      , rows : Int
      , xmin : Float
      , ymin : Float
      , cell : ( Float, Float )
      }
    )


type alias Result a =
    Dict ( ( Float, Float ), ( Float, Float ) ) a


draw f1 f2 ( table, config ) =
    let
        rowList =
            List.range 0 (config.rows - 1)

        colList =
            List.range 0 (config.cols - 1)

        ( cellW, cellH ) =
            config.cell

        rects =
            getAll_ table
                |> Dict.toList
                |> List.map
                    (\( ( ( xmin, ymin ), ( xmax, ymax ) ), _ ) ->
                        f2
                            { x = xmin + (xmax - xmin) / 2
                            , y = ymin + (ymax - ymin) / 2
                            , w = (xmax - xmin) / 2
                            , h = (ymax - ymin) / 2
                            }
                    )
    in
    rects
        |> (++)
            (List.concatMap
                (\x ->
                    List.map
                        (\y ->
                            f1
                                { x = config.xmin + toFloat x * cellW + cellW * 0.5
                                , y = config.ymin + toFloat y * cellH + cellH * 0.5
                                , w = cellW / 2
                                , h = cellH / 2
                                , active = Dict.member ( x, y ) table
                                }
                        )
                        rowList
                )
                colList
            )


insert : Boundary -> a -> Table a -> Table a
insert boundary value (( table, config ) as grid) =
    let
        ( ( x11, y11 ), ( x22, y22 ) ) =
            intersectsCellsBoundary boundary grid

        key =
            ( ( boundary.xmin, boundary.ymin ), ( boundary.xmax, boundary.ymax ) )

        newTable =
            List.foldr
                (\cellX acc1 ->
                    List.foldr
                        (\cellY acc2 -> Dict.update ( cellX, cellY ) (setUpdater key value) acc2)
                        acc1
                        (List.range y11 y22)
                )
                table
                (List.range x11 x22)
    in
    ( newTable, config )


setUpdater : ( ( Float, Float ), ( Float, Float ) ) -> a -> (Maybe (Result a) -> Maybe (Result a))
setUpdater k v =
    Maybe.map (Dict.insert k v) >> Maybe.withDefault (Dict.singleton k v) >> Just


optimize : Table a -> Table a
optimize (( table, _ ) as grid) =
    let
        validate ( k1, v1 ) ( k2, v2 ) =
            combine k1 v1 k2 v2
                |> Maybe.map (\k_ -> ( k_, v1 ))

        apply ( k1, v1 ) ( k2, v2 ) ( gotCombined, _ ) acc =
            remove k1 v1 acc
                |> remove k2 v2
                |> insert (keyToBoundary gotCombined) v1
    in
    foldOverAll_ validate apply ( Dict.toList (getAll_ table), [] ) grid


foldOverAll_ validate apply ( l1, l2 ) acc =
    case l1 of
        a :: rest ->
            innerFoldOverAll_ validate apply a ( rest, [] ) l2 acc
                |> (\( newRest, newAcc, skipped ) ->
                        foldOverAll_ validate apply ( newRest, skipped ) newAcc
                   )

        [] ->
            acc


innerFoldOverAll_ validate apply a ( l1, l2 ) skipped acc =
    case l1 of
        b :: rest ->
            case validate a b of
                Just gotCombined ->
                    innerFoldOverAll_ validate apply gotCombined ( l2 ++ rest, [] ) skipped (apply a b gotCombined acc)

                Nothing ->
                    innerFoldOverAll_ validate apply a ( rest, b :: l2 ) skipped acc

        [] ->
            if List.length skipped > 0 then
                innerFoldOverAll_ validate apply a ( skipped, [] ) [] acc
                    |> (\( newRest, newAcc, newSkipped ) ->
                            ( l2, newAcc, newRest ++ newSkipped )
                       )

            else
                ( l2, acc, a :: skipped )


keyToBoundary ( ( xmin, ymin ), ( xmax, ymax ) ) =
    { xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax }


remove k v (( table, config ) as grid) =
    let
        ( ( x11, y11 ), ( x22, y22 ) ) =
            intersectsCellsBoundary (keyToBoundary k) grid

        newTable =
            List.foldr
                (\cellX acc1 ->
                    List.foldr
                        (\cellY ->
                            Dict.update ( cellX, cellY )
                                (Maybe.map
                                    (Dict.update k
                                        (\inner ->
                                            if inner == Just v then
                                                Nothing

                                            else
                                                inner
                                        )
                                    )
                                )
                        )
                        acc1
                        (List.range y11 y22)
                )
                table
                (List.range x11 x22)
    in
    ( newTable, config )


combine k1 v1 k2 v2 =
    let
        ( ( xmin1, ymin1 ), ( xmax1, ymax1 ) ) =
            k1

        ( ( xmin2, ymin2 ), ( xmax2, ymax2 ) ) =
            k2

        vertically =
            xmin1 == xmin2 && xmax1 == xmax2 && (ymin1 == ymax2 || ymin2 == ymax1)

        horizontally =
            ymin1 == ymin2 && ymax1 == ymax2 && (xmin1 == xmax2 || xmin2 == xmax1)
    in
    if v1 == v2 && (vertically || horizontally) then
        Just ( ( min xmin1 xmin2, min ymin1 ymin2 ), ( max xmax1 xmax2, max ymax1 ymax2 ) )

    else
        Nothing


query : Boundary -> Table a -> Result a
query boundary (( table, _ ) as grid) =
    let
        ( ( x11, y11 ), ( x22, y22 ) ) =
            intersectsCellsBoundary boundary grid
    in
    List.foldr
        (\cellX acc1 ->
            List.foldr
                (\cellY acc2 ->
                    Dict.get ( cellX, cellY ) table
                        |> Maybe.map (Dict.union acc2)
                        |> Maybe.withDefault acc2
                )
                acc1
                (List.range y11 y22)
        )
        Dict.empty
        (List.range x11 x22)


intersectsCellsBoundary : Boundary -> Table a -> ( ( Int, Int ), ( Int, Int ) )
intersectsCellsBoundary { xmin, xmax, ymin, ymax } ( _, config ) =
    let
        edgeFix =
            --TODO find better solution
            0.0000001

        x1 =
            xmin - config.xmin

        x2 =
            xmax - config.xmin

        y1 =
            ymin - config.xmin

        y2 =
            ymax - config.xmin

        ( x11, y11 ) =
            getCell ( x1, y1 ) config.cell

        ( x22, y22 ) =
            getCell ( x2 - edgeFix, y2 - edgeFix ) config.cell
    in
    ( ( x11, y11 ), ( x22, y22 ) )


getCell : ( Float, Float ) -> ( Float, Float ) -> ( Int, Int )
getCell ( x, y ) cellSize =
    let
        ( cellWidth, cellHeight ) =
            cellSize

        xCell =
            floor (x / cellWidth)

        yCell =
            floor (y / cellHeight)
    in
    ( xCell, yCell )


getAll_ =
    Dict.foldl (\_ -> Dict.union) Dict.empty



--coarse grid
--https://stackoverflow.com/questions/41946007/effiscient-and-wsell-explained-implementation-of-a-quadtree-for-2d-collision-det
--https://0fps.net/2015/01/07/collision-detection-part-1/
