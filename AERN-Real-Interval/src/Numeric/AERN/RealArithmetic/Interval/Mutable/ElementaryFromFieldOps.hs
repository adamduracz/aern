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

module Numeric.AERN.RealArithmetic.Interval.Mutable.ElementaryFromFieldOps() where

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
    (CanBeMutable e,
     ArithInOut.RoundedFieldInPlace (Interval e),
     ArithInOut.RoundedMixedFieldInPlace (Interval e) Int,
     ArithInOut.RoundedPowerToNonnegIntInPlace (Interval e), 
     ArithInOut.RoundedMixedField (Interval e) Int,
     ArithInOut.RoundedField (Interval e), 
     ArithUpDn.Convertible (Interval e) Int,
     ArithInOut.Convertible Double (Interval e),
     HasZero e, HasOne e, 
     HasInfinities e,
     NumOrd.PartialComparison e,
     RefOrd.OuterRoundedLattice (Interval e)) => 
    (ArithInOut.RoundedExponentiationInPlace (Interval e))
    where
    expOutInPlaceEff 
        ((effortField, effortMixedField),
         (Int1To10 effortTaylor),
         ((effortMeet, effortComp), effortConv)) 
        (MInterval resL resH)
        (MInterval lM hM) =
            do
            (MInterval forgetMeL forgetMeH) <- makeMutable zero 
            expOutThinArgInPlace 
                effortField effortMixedField 
                effortMeet effortComp effortComp effortConv 
                (MInterval resL forgetMeH)
                effortTaylor 
                (MInterval lM lM)
            expOutThinArgInPlace
                effortField effortMixedField
                effortMeet effortComp effortComp effortConv 
                (MInterval forgetMeL resH)
                effortTaylor 
                (MInterval hM hM)
    expInInPlaceEff 
        ((effortField, effortMixedField),
         (Int1To10 effortTaylor),
         ((effortMeet, effortComp), effortConv)) 
        (MInterval resL resH)
        (MInterval lM hM) =
            do
            (MInterval forgetMeL forgetMeH) <- makeMutable zero 
            expOutThinArgInPlace 
                effortField effortMixedField 
                effortMeet effortComp effortComp effortConv 
                (MInterval forgetMeL resL)
                effortTaylor 
                (MInterval lM lM)
            expOutThinArgInPlace
                effortField effortMixedField
                effortMeet effortComp effortComp effortConv 
                (MInterval resH forgetMeH)
                effortTaylor 
                (MInterval hM hM)

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
     NumOrd.RoundedLatticeInPlace e) => 
    (ArithInOut.RoundedSquareRootInPlace (Interval e))
    where
    sqrtOutInPlaceEff 
        ((effortField, effortMixedField),
         (Int1To10 effortNewton),
         ((effortMeet, effortComp), effortConv)) 
        (MInterval resL resH)
        (MInterval lM hM) =
            do
            (MInterval forgetMeL forgetMeH) <- makeMutable zero 
            sqrtOutThinArgInPlace 
                effortField effortMixedField 
                effortMeet effortComp effortConv 
                (MInterval resL forgetMeH)
                effortNewton 
                lM
            sqrtOutThinArgInPlace
                effortField effortMixedField
                effortMeet effortComp effortConv 
                (MInterval forgetMeL resH)
                effortNewton 
                hM
    sqrtInInPlaceEff 
        ((effortField, effortMixedField),
         (Int1To10 effortNewton),
         ((effortMeet, effortComp), effortConv)) 
        (MInterval resL resH)
        (MInterval lM hM) =
            do
            (MInterval forgetMeL forgetMeH) <- makeMutable zero 
            sqrtOutThinArgInPlace 
                effortField effortMixedField 
                effortMeet effortComp effortConv 
                (MInterval forgetMeL resL)
                effortNewton 
                lM
            sqrtOutThinArgInPlace
                effortField effortMixedField
                effortMeet effortComp effortConv 
                (MInterval resH forgetMeH)
                effortNewton 
                hM
            