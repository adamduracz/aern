{-# LANGUAGE TypeFamilies #-}
{-|
    Module      :  Numeric.AERN.Basics.Enclosure
    Description :  set notation (⊂,∪,∩) and intervals
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
-}
module Numeric.AERN.Basics.Enclosure where

import Numeric.AERN.Basics.Order

import Numeric.AERN.Basics.Laws
import Numeric.AERN.Basics.MaybeBool
import Numeric.AERN.Basics.Order
import Numeric.AERN.Basics.Mutable

import Prelude hiding (LT, GT, EQ)
import Control.Monad.ST (ST)
import Test.QuickCheck

{-|
    A partially ordered set using set inclusion notation.
    
    (More-or-less copied from Data.Poset 
     in package altfloat-0.3 by Nick Bowler.) 
-} 
class (Eq t) => Enclosure t where
    compareEncl :: t -> t -> PartialOrdering
    -- | Is comparable to.
    (@<==>)  :: t -> t -> Bool
    -- | Is not comparable to.
    (@</=>)  :: t -> t -> Bool
    (@<)     :: t -> t -> Bool
    (@<=)    :: t -> t -> Bool
    (@>=)    :: t -> t -> Bool
    (@>)     :: t -> t -> Bool

    -- defaults for all but compare:
    a @<    b = a `compareEncl` b == LT
    a @>    b = a `compareEncl` b == GT
    a @<==> b = a `compareEncl` b /= NC
    a @</=> b = a `compareEncl` b == NC
    a @<=   b = a @< b || a `compareEncl` b == EQ
    a @>=   b = a @> b || a `compareEncl` b == EQ

-- convenience Unicode math operator notation:
(⊂) :: (Enclosure t) => t -> t -> Bool
(⊂) = (@<)
(⊆) :: (Enclosure t) => t -> t -> Bool
(⊆) = (@<=)
(⊇) :: (Enclosure t) => t -> t -> Bool
(⊇) = (@>=)
(⊃) :: (Enclosure t) => t -> t -> Bool
(⊃) = (@>)


propExtremaForEnclosures :: (Enclosure t, HasExtrema t) => t -> Bool
propExtremaForEnclosures e =
    (bottom ⊆ e) && (e ⊆ top)

-- TODO: adapt all poset properties for enclosures

{-|
    A set-based lattice.  Union and intersection should be compatible with inclusion.
    Both operations should be idempotent, commutative and associative.
-}
class (Eq t) => EnclosureLattice t where
    union :: t -> t -> t
    intersection :: t -> t -> t

(@\/) :: (EnclosureLattice t) => t -> t -> t
(@\/) = union

(∪) :: (EnclosureLattice t) => t -> t -> t
(∪) = union

(@/\) :: (EnclosureLattice t) => t -> t -> t
(@/\) = intersection

(∩) :: (EnclosureLattice t) => t -> t -> t
(∩) = intersection

-- TODO: adapt all lattice properties for enclosure lattices


{-|
    A lattice that supports in-place operations.
-}
class (Lattice t, CanBeMutable t) => EnclosureLatticeMutable t where
    {-| unionMutable a b c means a := b ∪ c; a can be the same as b and/or c -}
    unionMutable :: Mutable t s -> Mutable t s -> Mutable t s -> ST s ()
    {-| intersectionMutable a b c means a := b ∩ c; a can be the same as b and/or c -}
    intersectionMutable :: Mutable t s -> Mutable t s -> Mutable t s -> ST s ()

    -- TODO: add default implementations using read/write
    
{-|
    A type whose values have endpoints of another type.  
-}
class Interval e where
    type IntervalEndpoint e :: *
    getEndpoints :: e -> (IntervalEndpoint e, IntervalEndpoint e)
    fromEndpoints :: (IntervalEndpoint e, IntervalEndpoint e) -> e
