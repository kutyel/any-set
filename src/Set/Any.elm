module Set.Any exposing
    ( AnySet(..), equal
    , empty, singleton, insert, remove, removeAll, toggle
    , isEmpty, member, get, size, any, all
    , union, intersect, diff
    , toList, fromList
    , map, foldl, foldr, filter, partition, filterMap
    , toSet
    , decode, encode
    )

{-| A set of unique values. Similar to elm/core Set but allows arbitrary data
given a function for converting to `comparable` can be provided.

Insert, remove, and query operations all take O(log n) time.


# Converting Types to Comparable

When writing a function for conversion from the type you want to use within a set to comparable
**it's very important to make sure every distinct member of the type produces different value in the set of comparables**.
Functions satisfying this property are called [injective](https://en.wikipedia.org/wiki/Injective_function).

Take for instance those two examples:

We can use store Bool in Set (No matter how unpractical it might seem)

    boolToInt : Bool -> Int
    boolToInt bool =
        case bool of
            False -> 0
            True -> 1

    empty boolToInt
    |> insert True
    |> member True
    --> True

or Maybe String.

    comparableKey : Maybe String -> (Int, String)
    comparableKey maybe =
        case maybe of
            Nothing -> (0, "")
            Just str -> (1, str)

    empty comparableKey
        |> insert (Just "foo")
        |> member (Just "foo")
    --> True

Note that we give Int code to either constructor and in case of Nothing we default to `""` (empty string).
There is still a difference between `Nothing` and `Just ""` (`Int` value in the pair is different).
In fact, you can "hardcode" any value as the second member of the pair
in case of Nothing but empty string seems like a reasonable option for this case.
Generally, this is how I would implement `toComparable` function for most of your custom data types.
Have a look at the longest constructor,
Define tuple where the first key is int (number of the constructor)
and other are types within the constructor and you're good to go.


# AnySet

@docs AnySet, equal


# Build

@docs empty, singleton, insert, remove, removeAll, toggle


# Query

@docs isEmpty, member, get, size, any, all


# Combine

@docs union, intersect, diff


# Lists

@docs toList, fromList


# Transform

@docs map, foldl, foldr, filter, partition, filterMap


# Set

@docs toSet


# Json

@docs decode, encode

-}

import Dict
import Dict.Any exposing (AnyDict)
import Json.Decode as Decode
import Json.Encode as Encode
import Set exposing (Set)


{-| Represents a set of unique values.

Be aware that AnySet stores a function internally.
This means it's not possible to use `(==)` for comparing two AnySets.
Use [equal](#equal) function instead.

-}
type AnySet comparable t
    = AnySet (AnyDict comparable t ())


{-| Check equality of two `AnySet`s
-}
equal : AnySet comparable t -> AnySet comparable t -> Bool
equal (AnySet a) (AnySet b) =
    Dict.Any.equal a b


{-| Create an empty set.

\*\* Note that it's important to make sure every key is turned to different comparable.\*\*
Otherwise keys would conflict and overwrite each other.

-}
empty : (a -> comparable) -> AnySet comparable a
empty =
    AnySet << Dict.Any.empty


{-| Create a set with one value.

\*\* Note that it's important to make sure every key is turned to different comparable.\*\*
Otherwise keys would conflict and overwrite each other.

-}
singleton : a -> (a -> comparable) -> AnySet comparable a
singleton a =
    AnySet << Dict.Any.singleton a ()


{-| Insert a value into a set.
-}
insert : a -> AnySet comparable a -> AnySet comparable a
insert a (AnySet dict) =
    AnySet <| Dict.Any.insert a () dict


{-| Remove a value from a set. If the value is not found, no changes are made.
-}
remove : a -> AnySet comparable a -> AnySet comparable a
remove a (AnySet dict) =
    AnySet <| Dict.Any.remove a dict


{-| Remove all entries from AnySet.

Useful when you need to create new empty AnySet using
same comparable function for key type.

-}
removeAll : AnySet comparable a -> AnySet comparable a
removeAll (AnySet dict) =
    AnySet <| Dict.Any.removeAll dict


{-| Toggle a value in a set. If it's not found, it's inserted, else it's removed.
-}
toggle : a -> AnySet comparable a -> AnySet comparable a
toggle a set =
    if member a set then
        remove a set

    else
        insert a set


{-| Determine if a set is empty.
-}
isEmpty : AnySet comparable a -> Bool
isEmpty (AnySet dict) =
    Dict.Any.isEmpty dict


{-| Determine if a value is in a set.
-}
member : a -> AnySet comparable a -> Bool
member a (AnySet dict) =
    Dict.Any.member a dict


{-| Get a value from set.

This is useful in case of `AnySet` because
some parts of a value might not be used
for generating comparable.
This function allows quering `AnySet` with old
value to obtain updated one in such cases.

-}
get : a -> AnySet comparable a -> Maybe a
get a (AnySet dict) =
    Dict.Any.getKey a dict


{-| Determine the number of elements in a set.
-}
size : AnySet comparable a -> Int
size (AnySet dict) =
    Dict.Any.size dict


{-| Find out if there is any instance of something in a set.

    type Animal = Cat | Mouse | Dog

    animalToInt : Animal -> Int
    animalToInt animal =
        case animal of
            Cat -> 0
            Mouse -> 1
            Dog -> 2

    animals : AnySet Int Animal
    animals =
        [ Cat, Mouse ]
            |> fromList animalToInt

    isACat : Animal -> Bool
    isACat animal =
        case animal of
            Cat -> True
            _ -> False

    any isACat animals
    --> True

-}
any : (v -> Bool) -> AnySet comparable v -> Bool
any predicate (AnySet dict) =
    Dict.Any.any (\k _ -> predicate k) dict


{-| Find out if all values in set match a predicate.

    type Animal = Cat | Mouse | Dog

    animalToInt : Animal -> Int
    animalToInt animal =
        case animal of
            Cat -> 0
            Mouse -> 1
            Dog -> 2

    animals : AnySet Int Animal
    animals =
        [ Cat, Mouse ]
            |> fromList animalToInt

    aristocats : AnySet Int Animal
    aristocats =
        [ Cat ]
            |> fromList animalToInt

    isACat : Animal -> Bool
    isACat animal =
        case animal of
            Cat -> True
            _ -> False

    all isACat animals
    --> False

    all isACat aristocats
    --> True

-}
all : (v -> Bool) -> AnySet comparable v -> Bool
all predicate (AnySet dict) =
    Dict.Any.all (\k _ -> predicate k) dict


{-| Get the union of two sets. Keep all values.
-}
union : AnySet comparable a -> AnySet comparable a -> AnySet comparable a
union (AnySet d1) (AnySet d2) =
    AnySet <| Dict.Any.union d1 d2


{-| Get the intersection of two sets. Keeps values that appear in both sets.
-}
intersect : AnySet comparable a -> AnySet comparable a -> AnySet comparable a
intersect (AnySet d1) (AnySet d2) =
    AnySet <| Dict.Any.intersect d1 d2


{-| Get the difference between the first set and the second. Keeps values
that do not appear in the second set.
-}
diff : AnySet comparable a -> AnySet comparable a -> AnySet comparable a
diff (AnySet d1) (AnySet d2) =
    AnySet <| Dict.Any.diff d1 d2


{-| Convert a set into a list, sorted from lowest to highest.
-}
toList : AnySet comparable a -> List a
toList (AnySet dict) =
    Dict.Any.keys dict


{-| Convert a list into a set, removing any duplicates.
-}
fromList : (a -> comparable) -> List a -> AnySet comparable a
fromList toComparable =
    AnySet << Dict.Any.fromList toComparable << List.map (\a -> ( a, () ))


{-| Map a function onto a set, creating a new set with no duplicates.
-}
map : (b -> comparable2) -> (a -> b) -> AnySet comparable a -> AnySet comparable2 b
map toComparable f =
    fromList toComparable << foldl (\x xs -> f x :: xs) []


{-| Apply a function that may or may not succeed to all entries in a set, but only keep the successes.

    type Animal = Cat | Mouse | Dog

    animalToInt : Animal -> Int
    animalToInt animal =
        case animal of
            Cat -> 0
            Mouse -> 1
            Dog -> 2

    animals : AnySet Int Animal
    animals =
        [ Cat, Mouse ]
            |> fromList animalToInt

    onlyTom : AnySet String String
    onlyTom =
        [ "Tom" ]
            |> fromList identity

    getCatName : Animal -> Maybe String
    getCatName animal =
        case animal of
            Cat -> Just "Tom"
            _ -> Nothing

    filterMap identity getCatName animals == onlyTom
    --> True

-}
filterMap : (b -> comparable) -> (a -> Maybe b) -> AnySet comparable2 a -> AnySet comparable b
filterMap toComparable f set =
    foldl
        (\v acc ->
            case f v of
                Just newVal ->
                    insert newVal acc

                Nothing ->
                    acc
        )
        (empty toComparable)
        set


{-| Fold over the values in a set, in order from highest to lowest.
-}
foldl : (a -> b -> b) -> b -> AnySet comparable a -> b
foldl f init (AnySet dict) =
    Dict.Any.foldl (\x _ acc -> f x acc) init dict


{-| Fold over the values in a set, in order from lowest to highest.
-}
foldr : (a -> b -> b) -> b -> AnySet comparable a -> b
foldr f init (AnySet dict) =
    Dict.Any.foldr (\x _ acc -> f x acc) init dict


{-| Only keep elements that pass the given test.
-}
filter : (a -> Bool) -> AnySet comparable a -> AnySet comparable a
filter f (AnySet dict) =
    AnySet <| Dict.Any.filter (always << f) dict


{-| Create two new sets. The first contains all the elements that passed the
given test, and the second contains all the elements that did not.
-}
partition : (a -> Bool) -> AnySet comparable a -> ( AnySet comparable a, AnySet comparable a )
partition f (AnySet dict) =
    Dict.Any.partition (always << f) dict
        |> Tuple.mapFirst AnySet
        |> Tuple.mapSecond AnySet


{-| Convert AnySet to elm/core Set of comparable
-}
toSet : AnySet comparable a -> Set comparable
toSet (AnySet dict) =
    Dict.Any.toDict dict
        |> Dict.keys
        |> Set.fromList


{-| Decode `AnySet` from JSON array.
-}
decode : (a -> comparable) -> Decode.Decoder a -> Decode.Decoder (AnySet comparable a)
decode conversion decoder =
    Decode.map
        (fromList conversion)
        (Decode.list decoder)


{-| Turn `AnySet` into JSON array.
-}
encode : (a -> Encode.Value) -> AnySet comparable a -> Encode.Value
encode encoder =
    Encode.list encoder << toList
