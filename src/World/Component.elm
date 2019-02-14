module World.Component exposing
    ( dimensions
    , direction
    , objects
    , positions
    )

import Array exposing (Array)
import Defaults exposing (default)
import Logic.Component
import Logic.Entity as Entity exposing (EntityID)
import Math.Vector2 exposing (Vec2, vec2)
import Math.Vector4 exposing (Vec4, vec4)
import Task
import World.Component.Common exposing (EcsSpec, defaultRead)
import World.Component.Direction
import World.Component.Object


type alias Direction =
    World.Component.Direction.Direction


direction =
    World.Component.Direction.direction


objects =
    World.Component.Object.objects


positions : EcsSpec { a | positions : Logic.Component.Set Vec2 } Vec2 (Logic.Component.Set Vec2)
positions =
    --TODO create other for isometric view
    let
        spec =
            { get = .positions
            , set = \comps world -> { world | positions = comps }
            }
    in
    { spec = spec
    , empty = Array.empty
    , read =
        { defaultRead
            | objectTile =
                \_ { x, y } { width, height } gid ->
                    Task.succeed << Entity.with ( spec, vec2 x y )
        }
    }


dimensions : EcsSpec { a | dimensions : Logic.Component.Set Vec2 } Vec2 (Logic.Component.Set Vec2)
dimensions =
    let
        spec =
            { get = .dimensions
            , set = \comps world -> { world | dimensions = comps }
            }
    in
    { spec = spec
    , empty = Array.empty
    , read =
        { defaultRead
            | objectTile =
                \_ _ { height, width } _ ->
                    Task.succeed << Entity.with ( spec, vec2 width height )
        }
    }
