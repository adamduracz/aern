{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImplicitParams #-}
{-|
    Module      :  Numeric.AERN.RealArithmetic.NumericOrderRounding.InPlace.MixedFieldOps
    Description :  rounded basic arithmetic operations mixing 2 types
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    In-place versions of rounded basic arithmetical operations mixing 2 types.
    
    This module is hidden and reexported via its parent "NumericOrderRounding.InPlace". 
-}
module Numeric.AERN.RealArithmetic.NumericOrderRounding.InPlace.MixedFieldOps where

import Numeric.AERN.RealArithmetic.NumericOrderRounding.MixedFieldOps

import Numeric.AERN.RealArithmetic.NumericOrderRounding.FieldOps
import Numeric.AERN.RealArithmetic.NumericOrderRounding.Conversion
import Numeric.AERN.RealArithmetic.ExactOps

import Numeric.AERN.Basics.Exception
import Numeric.AERN.Basics.Mutable
import Numeric.AERN.Basics.Effort
import Numeric.AERN.RealArithmetic.Laws 
import Numeric.AERN.RealArithmetic.Measures
import qualified Numeric.AERN.Basics.NumericOrder as NumOrd
import Numeric.AERN.Basics.NumericOrder.OpsImplicitEffort

import Control.Monad.ST
import Control.Exception
import Data.Maybe

import Test.QuickCheck
import Test.Framework (testGroup, Test)
import Test.Framework.Providers.QuickCheck2 (testProperty)

class (RoundedMixedAdd t tn, CanBeMutable t) => RoundedMixedAddInPlace t tn where
    mixedAddUpInPlaceEff :: 
        t -> OpMutableNonmutEff (MixedAddEffortIndicator t tn) t tn s
    mixedAddDnInPlaceEff :: 
        t -> OpMutableNonmutEff (MixedAddEffortIndicator t tn) t tn s
    mixedAddUpInPlaceEff sample =
        pureToMutableNonmutEff sample mixedAddUpEff
    mixedAddDnInPlaceEff sample =
        pureToMutableNonmutEff sample mixedAddDnEff

{- properties of mixed addition -}

propMixedAddInPlaceEqualsConvert ::
    (NumOrd.PartialComparison t, Convertible tn t,
     RoundedMixedAddInPlace t tn, RoundedAdd t,
     Show t,
     HasDistance t,  Show (Distance t),  
     NumOrd.PartialComparison (Distance t), 
     HasInfinities (Distance t), HasZero (Distance t),
     Show (MixedAddEffortIndicator t tn),
     EffortIndicator (MixedAddEffortIndicator t tn),
     Show (ConvertEffortIndicator tn t),
     EffortIndicator (ConvertEffortIndicator tn t),
     Show (AddEffortIndicator t),
     EffortIndicator (AddEffortIndicator t),
     Show (DistanceEffortIndicator t),
     EffortIndicator (DistanceEffortIndicator t),
     Show (NumOrd.PartialCompareEffortIndicator t),
     EffortIndicator (NumOrd.PartialCompareEffortIndicator t)
     ) =>
    t -> t ->
    (NumOrd.PartialCompareEffortIndicator (Distance t)) -> 
    (DistanceEffortIndicator t,
     NumOrd.PartialCompareEffortIndicator t,
     (MixedAddEffortIndicator t tn,      
      AddEffortIndicator t,
      ConvertEffortIndicator tn t)) -> 
    t -> tn -> Bool
propMixedAddInPlaceEqualsConvert sample1 sample2 effortDistComp initEffort d n =
    equalRoundingUpDnImprovement
        expr1Up expr1Dn expr2Up expr2Dn 
        NumOrd.pLeqEff distanceBetweenEff effortDistComp initEffort
    where
    expr1Up (effMAdd,_,_) =
        let (+^|=) dR = mixedAddUpInPlaceEff d effMAdd dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR +^|= n
            unsafeReadMutable dR
    expr1Dn (effMAdd,_,_) =
        let (+.|=) dR = mixedAddDnInPlaceEff d effMAdd dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR +.|= n
            unsafeReadMutable dR
    expr2Up (_,effAdd,effConv) =
        let (+^) = addUpEff effAdd in (fromJust $ convertUpEff effConv n) +^ d
    expr2Dn (_,effAdd,effConv) =
        let (+.) = addDnEff effAdd in (fromJust $ convertDnEff effConv n) +. d



class (RoundedMixedMultiply t tn, CanBeMutable t) => RoundedMixedMultiplyInPlace t tn where
    mixedMultUpInPlaceEff :: 
        t -> OpMutableNonmutEff (MixedMultEffortIndicator t tn) t tn s
    mixedMultDnInPlaceEff :: 
        t -> OpMutableNonmutEff (MixedMultEffortIndicator t tn) t tn s
    mixedMultUpInPlaceEff sample =
        pureToMutableNonmutEff sample mixedMultUpEff
    mixedMultDnInPlaceEff sample =
        pureToMutableNonmutEff sample mixedMultDnEff

{- properties of mixed multiplication -}

propMixedMultInPlaceEqualsConvert ::
    (NumOrd.PartialComparison t, Convertible tn t,
     RoundedMixedMultiplyInPlace t tn, RoundedMultiply t,
     Show t,
     HasDistance t,  Show (Distance t),  
     NumOrd.PartialComparison (Distance t), 
     HasInfinities (Distance t), HasZero (Distance t),
     Show (MixedMultEffortIndicator t tn),
     EffortIndicator (MixedMultEffortIndicator t tn),
     Show (ConvertEffortIndicator tn t),
     EffortIndicator (ConvertEffortIndicator tn t),
     Show (MultEffortIndicator t),
     EffortIndicator (MultEffortIndicator t),
     Show (DistanceEffortIndicator t),
     EffortIndicator (DistanceEffortIndicator t),
     Show (NumOrd.PartialCompareEffortIndicator t),
     EffortIndicator (NumOrd.PartialCompareEffortIndicator t)
     ) =>
    t -> t ->
    (NumOrd.PartialCompareEffortIndicator (Distance t)) -> 
    (DistanceEffortIndicator t,
     NumOrd.PartialCompareEffortIndicator t,
     (MixedMultEffortIndicator t tn,      
      MultEffortIndicator t,
      ConvertEffortIndicator tn t)) -> 
    t -> tn -> Bool
propMixedMultInPlaceEqualsConvert sample1 sample2 effortDistComp initEffort d n =
    equalRoundingUpDnImprovement
        expr1Up expr1Dn expr2Up expr2Dn 
        NumOrd.pLeqEff distanceBetweenEff effortDistComp initEffort
    where
    expr1Up (effMMult,_,_) =
        let (*^|=) dR = mixedMultUpInPlaceEff d effMMult dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR *^|= n
            unsafeReadMutable dR
    expr1Dn (effMMult,_,_) =
        let (*.|=) dR = mixedMultDnInPlaceEff d effMMult dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR *.|= n
            unsafeReadMutable dR
    expr2Up (_,effMult,effConv) =
        let (*^) = multUpEff effMult in (fromJust $ convertUpEff effConv n) *^ d
    expr2Dn (_,effMult,effConv) =
        let (*.) = multDnEff effMult in (fromJust $ convertDnEff effConv n) *. d

class (RoundedMixedDivide t tn, CanBeMutable t) => RoundedMixedDivideInPlace t tn where
    mixedDivUpInPlaceEff :: 
        t -> OpMutableNonmutEff (MixedDivEffortIndicator t tn) t tn s
    mixedDivDnInPlaceEff :: 
        t -> OpMutableNonmutEff (MixedDivEffortIndicator t tn) t tn s
    mixedDivUpInPlaceEff sample =
        pureToMutableNonmutEff sample mixedDivUpEff
    mixedDivDnInPlaceEff sample =
        pureToMutableNonmutEff sample mixedDivDnEff

{- properties of mixed division -}

propMixedDivInPlaceEqualsConvert ::
    (NumOrd.PartialComparison t, Convertible tn t,
     RoundedMixedDivideInPlace t tn, RoundedDivide t,
     Show t,
     HasDistance t,  Show (Distance t),  
     NumOrd.PartialComparison (Distance t), 
     HasInfinities (Distance t), HasZero (Distance t),
     Show (MixedDivEffortIndicator t tn),
     EffortIndicator (MixedDivEffortIndicator t tn),
     Show (ConvertEffortIndicator tn t),
     EffortIndicator (ConvertEffortIndicator tn t),
     Show (DivEffortIndicator t),
     EffortIndicator (DivEffortIndicator t),
     Show (DistanceEffortIndicator t),
     EffortIndicator (DistanceEffortIndicator t),
     Show (NumOrd.PartialCompareEffortIndicator t),
     EffortIndicator (NumOrd.PartialCompareEffortIndicator t)
     ) =>
    t -> t ->
    (NumOrd.PartialCompareEffortIndicator (Distance t)) -> 
    (DistanceEffortIndicator t,
     NumOrd.PartialCompareEffortIndicator t,
     (MixedDivEffortIndicator t tn,      
      DivEffortIndicator t,
      ConvertEffortIndicator tn t)) -> 
    t -> tn -> Bool
propMixedDivInPlaceEqualsConvert sample1 sample2 effortDistComp initEffort d n =
    equalRoundingUpDnImprovement
        expr1Up expr1Dn expr2Up expr2Dn 
        NumOrd.pLeqEff distanceBetweenEff effortDistComp initEffort
    where
    expr1Up (effMDiv,_,_) =
        let (*^|=) dR = mixedDivUpInPlaceEff d effMDiv dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR *^|= n
            unsafeReadMutable dR
    expr1Dn (effMDiv,_,_) =
        let (*.|=) dR = mixedDivDnInPlaceEff d effMDiv dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR *.|= n
            unsafeReadMutable dR
    expr2Up (_,effDiv,effConv) =
        let (*^) = divUpEff effDiv in (fromJust $ convertUpEff effConv n) *^ d
    expr2Dn (_,effDiv,effConv) =
        let (*.) = divDnEff effDiv in (fromJust $ convertDnEff effConv n) *. d
    
testsUpDnMixedFieldOps (name, sample) (nameN, sampleN) =
    testGroup (name ++ " with " ++ nameN ++ ": in-place mixed up/dn rounded ops") $
        [
            testProperty "addition" (propMixedAddInPlaceEqualsConvert sample sampleN)
        ,
            testProperty "multiplication" (propMixedMultInPlaceEqualsConvert sample sampleN)
        ,
            testProperty "division" (propMixedDivInPlaceEqualsConvert sample sampleN)
        ]

class (RoundedMixedAddInPlace t tn, RoundedMixedMultiplyInPlace t tn) => RoundedMixedRingInPlace t tn

class (RoundedMixedRingInPlace t tn, RoundedMixedDivideInPlace t tn) => RoundedMixedFieldInPlace t tn
    