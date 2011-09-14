{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImplicitParams #-}
{-|
    Module      :  Numeric.AERN.RealArithmetic.Interval.Mutable.ElementaryFromFieldOps
    Description :  elementary in-place operations using generic direct implementation
    Copyright   :  (c) Michal Konecny, Jan Duracz
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable

    Elementary in-place operations using generic implementation directly from
    field operations.
-}

module Numeric.AERN.RealArithmetic.Interval.Mutable.ElementaryFromFieldOps
    (expOutInPlaceIters, expInInPlaceIters, sqrtOutInPlaceIters, sqrtInInPlaceIters) 
where

import Numeric.AERN.RealArithmetic.Interval.ElementaryFromFieldOps

import Numeric.AERN.RealArithmetic.RefinementOrderRounding.ElementaryFromFieldOps.Exponentiation

import Numeric.AERN.RealArithmetic.Interval.ElementaryFromFieldOps.Sqrt

import qualified Numeric.AERN.RealArithmetic.NumericOrderRounding as ArithUpDn
import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut
import Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsImplicitEffort
import qualified Numeric.AERN.Basics.NumericOrder as NumOrd
import qualified Numeric.AERN.Basics.RefinementOrder as RefOrd
import Numeric.AERN.Basics.RefinementOrder.OpsImplicitEffort

import Numeric.AERN.RealArithmetic.ExactOps
import Numeric.AERN.RealArithmetic.Interval

import Numeric.AERN.Basics.Interval
import Numeric.AERN.Basics.Consistency
import Numeric.AERN.Basics.Effort

import Numeric.AERN.Basics.Mutable

instance
    (CanBeMutable e, ArithUpDn.RoundedReal e, ArithInOut.RoundedRealInPlace (Interval e)) 
    => 
    (ArithInOut.RoundedExponentiationInPlace (Interval e))
    where
    expOutInPlaceEff 
        (eff, Int1To10 effortTaylor)
--        ((effortField, effortMixedField),
--         (Int1To10 effortTaylor),
--         ((effortMeet, effortComp), effortConv)) 
        (MInterval resL resR)
        (MInterval lM rM) =
            do
            (MInterval forgetMeL forgetMeR) <- makeMutable zero 
            expOutThinArgInPlace eff
--                effortField effortMixedField 
--                effortMeet effortComp effortComp effortConv 
                (MInterval resL forgetMeR)
                effortTaylor 
                (MInterval lM lM)
            expOutThinArgInPlace eff
--                effortField effortMixedField
--                effortMeet effortComp effortComp effortConv 
                (MInterval forgetMeL resR)
                effortTaylor 
                (MInterval rM rM)
    expInInPlaceEff 
        (eff, Int1To10 effortTaylor)
--        ((effortField, effortMixedField),
--         (Int1To10 effortTaylor),
--         ((effortMeet, effortComp), effortConv)) 
        (MInterval resL resR)
        (MInterval lM rM) =
            do
            (MInterval forgetMeL forgetMeR) <- makeMutable zero 
            expOutThinArgInPlace eff 
--                effortField effortMixedField 
--                effortMeet effortComp effortComp effortConv 
                (MInterval forgetMeL resL)
                effortTaylor 
                (MInterval lM lM)
            expOutThinArgInPlace eff
--                effortField effortMixedField
--                effortMeet effortComp effortComp effortConv 
                (MInterval resR forgetMeR)
                effortTaylor 
                (MInterval rM rM)

expOutInPlaceIters, expInInPlaceIters ::
    (CanBeMutable e, ArithUpDn.RoundedReal e, ArithInOut.RoundedRealInPlace (Interval e)) 
    => 
    Int -> OpMutable1 (Interval e) s 
expOutInPlaceIters n resM iM =
    do
    i <- unsafeReadMutable iM
    ArithInOut.expOutInPlaceEff (expDefaultEffortWithIters i n) resM iM
expInInPlaceIters n resM iM =
    do
    i <- unsafeReadMutable iM
    ArithInOut.expInInPlaceEff (expDefaultEffortWithIters i n) resM iM

instance
    (CanBeMutable e, Show e,
     ArithUpDn.RoundedFieldInPlace e,
     ArithUpDn.RoundedMixedFieldInPlace e Int,
     ArithUpDn.RoundedMixedField e Int,
     ArithUpDn.RoundedField e, 
     ArithUpDn.Convertible e Double,
     HasZero e, HasOne e, 
     HasInfinities e,
     NumOrd.PartialComparison e,
     NumOrd.RoundedLattice e,
     NumOrd.RoundedLatticeInPlace e) 
    => 
    (ArithInOut.RoundedSquareRootInPlace (Interval e))
    where
    sqrtOutInPlaceEff
        = pureToMutable1Eff ArithInOut.sqrtOutEff

-- the following is a proper in-place version - but it currently fails the test        
        
--        ((effortField, effortMixedField),
--         (Int1To10 effortNewton),
--         ((effortMeet, effortComp), effortConv)) 
--        (MInterval resL resR)
--        (MInterval lM rM) =
--            do
--            (MInterval forgetMeL forgetMeR) <- makeMutable zero 
--            sqrtOutThinArgInPlace 
--                effortField effortMixedField 
--                effortMeet effortComp effortConv 
--                (MInterval resL forgetMeR)
--                effortNewton 
--                lM
--            sqrtOutThinArgInPlace
--                effortField effortMixedField
--                effortMeet effortComp effortConv 
--                (MInterval forgetMeL resR)
--                effortNewton 
--                rM
    sqrtInInPlaceEff 
        = pureToMutable1Eff ArithInOut.sqrtInEff
--        ((effortField, effortMixedField),
--         (Int1To10 effortNewton),
--         ((effortMeet, effortComp), effortConv)) 
--        (MInterval resL resR)
--        (MInterval lM rM) =
--            do
--            (MInterval forgetMeL forgetMeR) <- makeMutable zero 
--            sqrtOutThinArgInPlace 
--                effortField effortMixedField 
--                effortMeet effortComp effortConv 
--                (MInterval forgetMeL resL)
--                effortNewton 
--                lM
--            sqrtOutThinArgInPlace
--                effortField effortMixedField
--                effortMeet effortComp effortConv 
--                (MInterval resR forgetMeR)
--                effortNewton 
--                rM
            
sqrtOutInPlaceIters, sqrtInInPlaceIters ::
    (CanBeMutable e, Show e,
     ArithUpDn.RoundedFieldInPlace e,
     ArithUpDn.RoundedMixedFieldInPlace e Int,
     ArithUpDn.RoundedMixedField e Int,
     ArithUpDn.RoundedField e, 
     ArithUpDn.Convertible e Double,
     HasZero e, HasOne e, 
     HasInfinities e,
     NumOrd.PartialComparison e,
     NumOrd.RoundedLattice e,
     NumOrd.RoundedLatticeInPlace e) 
    =>
    Int -> OpMutable1 (Interval e) s 
sqrtOutInPlaceIters n resM iM =
    do
    i <- unsafeReadMutable iM
    ArithInOut.sqrtOutInPlaceEff (sqrtDefaultEffortWithIters i n) resM iM
sqrtInInPlaceIters n resM iM =
    do
    i <- unsafeReadMutable iM
    ArithInOut.sqrtInInPlaceEff (sqrtDefaultEffortWithIters i n) resM iM
            