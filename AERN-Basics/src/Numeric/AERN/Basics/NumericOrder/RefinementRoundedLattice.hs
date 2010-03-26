{-|
    Module      :  Numeric.AERN.Basics.NumericOrder.RefinementRoundedLattice
    Description :  lattices over numerical order but with refinement order rounding  
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Lattices over numerical order but with refinement order rounding.
    
    This module is hidden and reexported via its parent NumericOrder. 
-}
module Numeric.AERN.Basics.NumericOrder.RefinementRoundedLattice 
where

import Prelude hiding ((<=))

import Numeric.AERN.Basics.Exception

import Numeric.AERN.Basics.Mutable
import Control.Monad.ST (ST)

import Numeric.AERN.Basics.Effort
import Numeric.AERN.Basics.PartialOrdering
import Numeric.AERN.Basics.NumericOrder.Arbitrary 
import Numeric.AERN.Basics.NumericOrder.SemidecidableComparison 
import Numeric.AERN.Basics.NumericOrder.Extrema

import qualified Numeric.AERN.Basics.RefinementOrder as RefOrd
import Numeric.AERN.Basics.RefinementOrder ((|<=?))

import Numeric.AERN.Basics.Laws.SemidecidableRelation
import Numeric.AERN.Basics.Laws.RoundedOperation
import Numeric.AERN.Basics.Laws.OperationRelation

import Numeric.AERN.Misc.Maybe

{-|
    A type with refinement-outer-rounding numerical-order-lattice operations.
-}
class OuterRoundedLattice t where
    maxOuterEff :: [EffortIndicator] -> t -> t -> t
    minOuterEff :: [EffortIndicator] -> t -> t -> t
    minmaxOuterDefaultEffort :: t -> [EffortIndicator]

    maxOuter :: t -> t -> t
    minOuter :: t -> t -> t
    
    maxOuter a b = maxOuterEff (minmaxOuterDefaultEffort a) a b 
    minOuter a b = minOuterEff (minmaxOuterDefaultEffort a) a b 

{-|
    A type with refinement-inner-rounding numerical-order-lattice operations.
-}
class InnerRoundedLattice t where
    maxInnerEff :: [EffortIndicator] -> t -> t -> t
    minInnerEff :: [EffortIndicator] -> t -> t -> t
    minmaxInnerDefaultEffort :: t -> [EffortIndicator]

    maxInner :: t -> t -> t
    minInner :: t -> t -> t
    
    maxInner a b = maxInnerEff (minmaxInnerDefaultEffort a) a b 
    minInner a b = minInnerEff (minmaxInnerDefaultEffort a) a b 


class (OuterRoundedLattice t, InnerRoundedLattice t) => RefinementRoundedLattice t

propRefinementRoundedLatticeIllegalArgException :: (RefinementRoundedLattice t) => t -> t -> Bool
propRefinementRoundedLatticeIllegalArgException illegalArg d =
    and $ map raisesAERNException $ 
                concat [[op d illegalArg, op illegalArg d] | op <- [maxInner, maxOuter, minInner, minOuter]] 

propRefinementRoundedLatticeJoinIdempotent :: 
    (RefOrd.SemidecidableComparison t, RefinementRoundedLattice t) => 
    t -> Bool
propRefinementRoundedLatticeJoinIdempotent = roundedIdempotent (|<=?) maxInner maxOuter

propRefinementRoundedLatticeJoinCommutative :: 
    (RefOrd.SemidecidableComparison t, RefinementRoundedLattice t) => 
    UniformlyOrderedPair t -> Bool
propRefinementRoundedLatticeJoinCommutative (UniformlyOrderedPair (e1,e2)) = 
    roundedCommutative (|<=?) maxInner maxOuter e1 e2

propRefinementRoundedLatticeJoinAssocative :: 
    (RefOrd.SemidecidableComparison t, RefinementRoundedLattice t) => 
    UniformlyOrderedTriple t -> Bool
propRefinementRoundedLatticeJoinAssocative (UniformlyOrderedTriple (e1,e2,e3)) = 
    roundedAssociative (|<=?) maxInner maxOuter e1 e2 e3

propRefinementRoundedLatticeMeetIdempotent :: 
    (RefOrd.SemidecidableComparison t, RefinementRoundedLattice t) => 
    t -> Bool
propRefinementRoundedLatticeMeetIdempotent = 
    roundedIdempotent (|<=?) minInner minOuter

propRefinementRoundedLatticeMeetCommutative :: 
    (RefOrd.SemidecidableComparison t, RefinementRoundedLattice t) => 
    UniformlyOrderedPair t -> Bool
propRefinementRoundedLatticeMeetCommutative (UniformlyOrderedPair (e1,e2)) = 
    roundedCommutative (|<=?) minInner minOuter e1 e2

propRefinementRoundedLatticeMeetAssocative :: 
    (RefOrd.SemidecidableComparison t, RefinementRoundedLattice t) => 
    UniformlyOrderedTriple t -> Bool
propRefinementRoundedLatticeMeetAssocative (UniformlyOrderedTriple (e1,e2,e3)) = 
    roundedAssociative (|<=?) minInner minOuter e1 e2 e3

{- optional properties: -}
propRefinementRoundedLatticeModular :: 
    (RefOrd.SemidecidableComparison t, RefinementRoundedLattice t) => 
    UniformlyOrderedTriple t -> Bool
propRefinementRoundedLatticeModular (UniformlyOrderedTriple (e1,e2,e3)) = 
    roundedModular (|<=?) maxInner minInner maxOuter minOuter e1 e2 e3

propRefinementRoundedLatticeDistributive :: 
    (RefOrd.SemidecidableComparison t, RefinementRoundedLattice t) => 
    UniformlyOrderedTriple t -> Bool
propRefinementRoundedLatticeDistributive (UniformlyOrderedTriple (e1,e2,e3)) = 
    (roundedLeftDistributive  (|<=?) maxInner minInner maxOuter minOuter e1 e2 e3)
    && 
    (roundedLeftDistributive  (|<=?) maxInner minInner maxOuter minOuter e1 e2 e3)
    