{-|
    Module      :  Numeric.AERN.Interval.Double
    Description :  Interval Double type and operations  
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Intervals with Double coeffients.
-}
module Numeric.AERN.Interval.Double 
(
    -- * types
    DI,
    -- * comparison operators
    -- * field operators
    (<+>),
    (>+<),
    -- * mixed field operators (e.g. Integer times DI)
    -- * temporary exports (to be deleted soon!)
    module Numeric.AERN.Basics.Interval,
    module Numeric.AERN.Basics.NumericOrder.OpsDefaultEffort,
    module Numeric.AERN.Basics.RefinementOrder.OpsDefaultEffort,
    module Numeric.AERN.RealArithmetic.RefinementOrderRounding,
    module Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsDefaultEffort
)
where

import Numeric.AERN.Basics.Interval

import Numeric.AERN.Basics.NumericOrder.OpsDefaultEffort
import Numeric.AERN.Basics.RefinementOrder.OpsDefaultEffort

import Numeric.AERN.RealArithmetic.Interval
import Numeric.AERN.RealArithmetic.RefinementOrderRounding
import Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsDefaultEffort
import Numeric.AERN.RealArithmetic.Interval.ElementaryDirect

--import Numeric.AERN.RealArithmetic.Basis.Double.ShowInternals
import Numeric.AERN.RealArithmetic.Basis.Double

import qualified Numeric.AERN.Basics.NumericOrder as NumOrd

import Test.QuickCheck

type DI = Interval Double

sampleDI :: DI
sampleDI = Interval 0 0

newtype PositiveDI = PositiveDI { unPositiveDI :: DI }

instance Show PositiveDI where
    show (PositiveDI i) = show i

instance Arbitrary PositiveDI
    where
    arbitrary =
        do
        NumOrd.UniformlyOrderedPair (l,h) <- arbitrary
        return $ PositiveDI (Interval (pos l) (pos h))
        where
        pos e 
            | e > 0 =  e
            | e == 0 =  1
            | otherwise = (-e) 