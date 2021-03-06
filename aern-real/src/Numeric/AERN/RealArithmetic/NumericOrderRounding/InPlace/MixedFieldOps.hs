{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}

{-# LANGUAGE NoMonoLocalBinds #-}

{-|
    Module      :  Numeric.AERN.RealArithmetic.NumericOrderRounding.InPlace.MixedFieldOps
    Description :  rounded basic arithmetic operations mixing 2 types
    Copyright   :  (c) Michal Konecny, Jan Duracz
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    In-place versions of rounded basic arithmetical operations mixing 2 types.
    
    This module is hidden and reexported via its parent "NumericOrderRounding.InPlace". 
-}
module Numeric.AERN.RealArithmetic.NumericOrderRounding.InPlace.MixedFieldOps where

import Numeric.AERN.RealArithmetic.NumericOrderRounding.MixedFieldOps
import Numeric.AERN.RealArithmetic.NumericOrderRounding.InPlace.FieldOps

import Numeric.AERN.RealArithmetic.NumericOrderRounding.FieldOps
import Numeric.AERN.RealArithmetic.NumericOrderRounding.Conversion
import Numeric.AERN.RealArithmetic.ExactOps

import Numeric.AERN.Basics.Exception
import Numeric.AERN.Basics.Mutable
import Numeric.AERN.Basics.Effort
import Numeric.AERN.RealArithmetic.Laws 
import Numeric.AERN.RealArithmetic.Measures
import qualified Numeric.AERN.NumericOrder as NumOrd

import Control.Monad.ST
import Control.Exception
import Data.Maybe

import Test.QuickCheck
import Test.Framework (testGroup, Test)
import Test.Framework.Providers.QuickCheck2 (testProperty)

class (RoundedMixedAddEffort t tn, CanBeMutable t) => RoundedMixedAddInPlace t tn where
    mixedAddUpInPlaceEff :: 
        OpMutableNonmutEff (MixedAddEffortIndicator t tn) t tn s
    mixedAddDnInPlaceEff :: 
        OpMutableNonmutEff (MixedAddEffortIndicator t tn) t tn s


-- | Upward rounded in-place mixed addition with default effort
mixedAddUpInPlace :: (RoundedMixedAddInPlace t tn) => 
    OpMutableNonmut t tn s
mixedAddUpInPlace =
    mixedEffToMutableNonmut mixedAddUpInPlaceEff mixedAddDefaultEffort

-- | Upward rounded additive scalar action assignment with default effort
(+^|=) :: (RoundedMixedAddInPlace t tn) => OpNonmut t tn s
(+^|=) = mutableNonmutToNonmut mixedAddUpInPlace

-- | Downward rounded in-place mixed addition with default effort
mixedAddDnInPlace :: (RoundedMixedAddInPlace t tn) =>
    OpMutableNonmut t tn s
mixedAddDnInPlace =
    mixedEffToMutableNonmut mixedAddDnInPlaceEff mixedAddDefaultEffort

-- | Downward rounded additive scalar action assignment with default effort
(+.|=) :: (RoundedMixedAddInPlace t tn) => OpNonmut t tn s
(+.|=) = mutableNonmutToNonmut mixedAddDnInPlace


mixedAddUpInPlaceEffFromPure,
 mixedAddDnInPlaceEffFromPure ::
    (CanBeMutable t, RoundedMixedAdd t tn) =>
    OpMutableNonmutEff (MixedAddEffortIndicator t tn) t tn s
mixedAddUpInPlaceEffFromPure =
    pureToMutableNonmutEff mixedAddUpEff
mixedAddDnInPlaceEffFromPure =
    pureToMutableNonmutEff mixedAddDnEff
    
mixedAddUpInPlaceEffFromInPlace,
 mixedAddDnInPlaceEffFromInPlace ::
    (RoundedMixedAddInPlace t tn) =>
    (MixedAddEffortIndicator t tn) -> t -> tn -> t
mixedAddUpInPlaceEffFromInPlace = 
    mutableNonmutEffToPure mixedAddUpInPlaceEff 
mixedAddDnInPlaceEffFromInPlace = 
    mutableNonmutEffToPure mixedAddDnInPlaceEff 

-- an alternative default implementation using conversion 
-- - this could be more efficient

mixedAddUpInPlaceEffByConversion ::
    (Convertible tn t, RoundedAddInPlace t, Show tn) =>
    OpMutableNonmutEff (AddEffortIndicator t, ConvertEffortIndicator tn t) t tn s 
mixedAddUpInPlaceEffByConversion (effAdd, effConv) rM dM n =
    do
    sample <- readMutable dM
    nUpM <- makeMutable $ nUp sample
    addUpInPlaceEff effAdd rM dM nUpM
    where
    nUp sample = 
        case convertUpEff effConv sample n of
            (Just nUp) -> nUp
            _ -> throw $ AERNException $ 
                        "conversion failed during mixed addition: n = " ++ show n

mixedAddDnInPlaceEffByConversion ::
    (Convertible tn t, RoundedAddInPlace t, Show tn) =>
    OpMutableNonmutEff (AddEffortIndicator t, ConvertEffortIndicator tn t) t tn s 
mixedAddDnInPlaceEffByConversion (effAdd, effConv) rM dM n =
    do
    sample <- readMutable dM
    nDnM <- makeMutable $ nDn sample
    addDnInPlaceEff effAdd rM dM nDnM
    where
    nDn sample = 
        case convertDnEff effConv sample n of
            (Just nDn) -> nDn
            _ -> throw $ AERNException $ 
                        "conversion failed during mixed addition: n = " ++ show n


{- properties of mixed addition -}

propMixedAddInPlaceEqualsConvert ::
    (NumOrd.PartialComparison t, Convertible tn t,
     RoundedMixedAddInPlace t tn, 
     RoundedMixedAdd t tn, 
     RoundedAdd t,
     Show t, HasLegalValues t) 
    =>
    t -> tn ->
    (NumOrd.PartialCompareEffortIndicator t,
     (MixedAddEffortIndicator t tn,      
      AddEffortIndicator t,
      ConvertEffortIndicator tn t)) -> 
    (NumOrd.UniformlyOrderedSingleton t) -> 
    tn -> Bool
propMixedAddInPlaceEqualsConvert sample1 _sample2 initEffort 
        (NumOrd.UniformlyOrderedSingleton d) n =
    equalRoundingUpDn "in-place rounded mixed addition"
        expr1Up expr1Dn expr2Up expr2Dn 
        NumOrd.pLeqEff initEffort
    where
    expr1Up (effMAdd,_,_) =
        let (+^|=) dR = mixedAddUpInPlaceEff effMAdd dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR +^|= n
            unsafeReadMutable dR
    expr1Dn (effMAdd,_,_) =
        let (+.|=) dR = mixedAddDnInPlaceEff effMAdd dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR +.|= n
            unsafeReadMutable dR
    expr2Up (_,effAdd,effConv) =
        let (+^) = addUpEff effAdd in (fromJust $ convertUpEff effConv sample1 n) +^ d
    expr2Dn (_,effAdd,effConv) =
        let (+.) = addDnEff effAdd in (fromJust $ convertDnEff effConv sample1 n) +. d



class (RoundedMixedMultiplyEffort t tn, CanBeMutable t) => RoundedMixedMultiplyInPlace t tn where
    mixedMultUpInPlaceEff :: 
        OpMutableNonmutEff (MixedMultEffortIndicator t tn) t tn s
    mixedMultDnInPlaceEff :: 
        OpMutableNonmutEff (MixedMultEffortIndicator t tn) t tn s

-- | Upward rounded in-place mixed multiplication with default effort
mixedMultUpInPlace :: (RoundedMixedMultiplyInPlace t tn) => 
    OpMutableNonmut t tn s
mixedMultUpInPlace =
    mixedEffToMutableNonmut mixedMultUpInPlaceEff mixedMultDefaultEffort

-- | Upward rounded multiplicative scalar action assignment with default effort
(*^|=) :: (RoundedMixedMultiplyInPlace t tn) => OpNonmut t tn s
(*^|=) = mutableNonmutToNonmut mixedMultUpInPlace

-- | Downward rounded in-place mixed multiplication with default effort
mixedMultDnInPlace :: (RoundedMixedMultiplyInPlace t tn) => 
    OpMutableNonmut t tn s
mixedMultDnInPlace =
    mixedEffToMutableNonmut mixedMultDnInPlaceEff mixedMultDefaultEffort

-- | Downward rounded multiplicative scalar action assignment with default effort
(*.|=) :: (RoundedMixedMultiplyInPlace t tn) => OpNonmut t tn s
(*.|=) = mutableNonmutToNonmut mixedMultDnInPlace


mixedMultUpInPlaceEffFromPure,
 mixedMultDnInPlaceEffFromPure ::
    (CanBeMutable t, RoundedMixedMultiply t tn) =>
    OpMutableNonmutEff (MixedMultEffortIndicator t tn) t tn s
mixedMultUpInPlaceEffFromPure =
    pureToMutableNonmutEff mixedMultUpEff
mixedMultDnInPlaceEffFromPure =
    pureToMutableNonmutEff mixedMultDnEff

mixedMultUpInPlaceEffFromInPlace,
 mixedMultDnInPlaceEffFromInPlace ::
    (RoundedMixedMultiplyInPlace t tn) =>
    (MixedMultEffortIndicator t tn) -> t -> tn -> t
mixedMultUpInPlaceEffFromInPlace = 
    mutableNonmutEffToPure mixedMultUpInPlaceEff 
mixedMultDnInPlaceEffFromInPlace = 
    mutableNonmutEffToPure mixedMultDnInPlaceEff

{- properties of mixed multiplication -}

propMixedMultInPlaceEqualsConvert ::
    (NumOrd.PartialComparison t,  NumOrd.RoundedLattice t,
     Convertible tn t,
     RoundedMixedMultiplyInPlace t tn, 
     RoundedMixedMultiply t tn, 
     RoundedMultiply t,
     Show t, HasLegalValues t) 
    =>
    t -> tn ->
    (NumOrd.PartialCompareEffortIndicator t,
     (MixedMultEffortIndicator t tn,      
      (MultEffortIndicator t,
       ConvertEffortIndicator tn t,
       NumOrd.MinmaxEffortIndicator t))) -> 
    (NumOrd.UniformlyOrderedSingleton t) -> 
    tn -> Bool
propMixedMultInPlaceEqualsConvert sample1 sample2 initEffort 
        (NumOrd.UniformlyOrderedSingleton d) n =
    equalRoundingUpDn "in-place rounded mixed multiplication"
        expr1Up expr1Dn expr2Up expr2Dn 
        NumOrd.pLeqEff initEffort
    where
    expr1Up (effMMult,_) =
        let (*^|=) dR = mixedMultUpInPlaceEff effMMult dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR *^|= n
            unsafeReadMutable dR
    expr1Dn (effMMult,_) =
        let (*.|=) dR = mixedMultDnInPlaceEff effMMult dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR *.|= n
            unsafeReadMutable dR
    expr2Up (_,(effMult,effConv,effMinmax)) =
        let (*^) = multUpEff effMult in
        NumOrd.maxUpEff effMinmax  
            (d *^ (fromJust $ convertUpEff effConv sample1 n))
            (d *^ (fromJust $ convertDnEff effConv sample1 n))
    expr2Dn (_,(effMult,effConv,effMinmax)) =
        let (*.) = multDnEff effMult in
        NumOrd.minDnEff effMinmax  
            (d *. (fromJust $ convertUpEff effConv sample1 n))
            (d *. (fromJust $ convertDnEff effConv sample1 n))

class (RoundedMixedDivide t tn, CanBeMutable t) => RoundedMixedDivideInPlace t tn where
    mixedDivUpInPlaceEff :: 
        OpMutableNonmutEff (MixedDivEffortIndicator t tn) t tn s
    mixedDivDnInPlaceEff :: 
        OpMutableNonmutEff (MixedDivEffortIndicator t tn) t tn s

-- | Upward rounded in-place mixed reciprocal action with default effort
mixedDivUpInPlace :: (RoundedMixedDivideInPlace t tn) => 
    OpMutableNonmut t tn s
mixedDivUpInPlace =
    mixedEffToMutableNonmut mixedDivUpInPlaceEff mixedDivDefaultEffort

-- | Upward rounded multiplicative scalar reciprocal action assignment with default effort
(/^|=) :: (RoundedMixedDivideInPlace t tn) => OpNonmut t tn s
(/^|=) = mutableNonmutToNonmut mixedDivUpInPlace

-- | Downward rounded in-place mixed reciprocal action with default effort
mixedDivDnInPlace :: (RoundedMixedDivideInPlace t tn) => 
    OpMutableNonmut t tn s
mixedDivDnInPlace =
    mixedEffToMutableNonmut mixedDivDnInPlaceEff mixedDivDefaultEffort

-- | Downward rounded multiplicative scalar reciprocal action assignment with default effort
(/.|=) :: (RoundedMixedDivideInPlace t tn) => OpNonmut t tn s
(/.|=) = mutableNonmutToNonmut mixedDivDnInPlace


mixedDivUpInPlaceEffFromPure,
 mixedDivDnInPlaceEffFromPure ::
    (CanBeMutable t, RoundedMixedDivide t tn) =>
    OpMutableNonmutEff (MixedDivEffortIndicator t tn) t tn s
mixedDivUpInPlaceEffFromPure =
    pureToMutableNonmutEff mixedDivUpEff
mixedDivDnInPlaceEffFromPure =
    pureToMutableNonmutEff mixedDivDnEff

mixedDivUpInPlaceEffFromInPlace,
 mixedDivDnInPlaceEffFromInPlace ::
    (RoundedMixedDivideInPlace t tn) =>
    (MixedDivEffortIndicator t tn) -> t -> tn -> t
mixedDivUpInPlaceEffFromInPlace = 
    mutableNonmutEffToPure mixedDivUpInPlaceEff 
mixedDivDnInPlaceEffFromInPlace = 
    mutableNonmutEffToPure mixedDivDnInPlaceEff

{- properties of mixed division -}

propMixedDivInPlaceEqualsConvert ::
    (NumOrd.PartialComparison t,  NumOrd.RoundedLattice t,
     Convertible tn t,
     RoundedMixedDivideInPlace t tn, 
     RoundedMixedDivide t tn, 
     RoundedDivide t,
     Show t, HasZero t, HasLegalValues t)
    =>
    t -> tn ->
    (NumOrd.PartialCompareEffortIndicator t,
     (MixedDivEffortIndicator t tn,      
      (DivEffortIndicator t,
       ConvertEffortIndicator tn t,
       NumOrd.MinmaxEffortIndicator t))) -> 
    (NumOrd.UniformlyOrderedSingleton t) -> 
    tn -> Bool
propMixedDivInPlaceEqualsConvert sample1 sample2 
        initEffort@(effComp,(_,(_,effConv,_))) 
        (NumOrd.UniformlyOrderedSingleton d) n
    =
    equalRoundingUpDn "in-place rounded mixed division"
        expr1Up expr1Dn expr2Up expr2Dn 
        NumOrd.pLeqEff initEffort
    where
    expr1Up (effMDiv,_) =
        let (/^|=) dR = mixedDivUpInPlaceEff effMDiv dR dR in
        runST $ 
            do
            dR <- makeMutable d
            dR /^|= n
            unsafeReadMutable dR
    expr1Dn (effMDiv,_) =
        let 
--            (/.|=) :: forall t tn . ((RoundedMixedDivideInPlace t tn) => forall s . Mutable t s -> tn -> ST s ())
            (/.|=) dR = mixedDivDnInPlaceEff effMDiv dR dR 
        in
        runST $ 
            do
            dR <- makeMutable d
            dR /.|= n
            unsafeReadMutable dR
    expr2Up (_,(effDiv,effConv,effMinmax)) =
        let (/^) = divUpEff effDiv in
        NumOrd.maxUpEff effMinmax  
            (d /^ (fromJust $ convertUpEff effConv sample1 n))
            (d /^ (fromJust $ convertDnEff effConv sample1 n))
    expr2Dn (_,(effDiv,effConv,effMinmax)) =
        let (/.) = divDnEff effDiv in
        NumOrd.minDnEff effMinmax  
            (d /. (fromJust $ convertUpEff effConv sample1 n))
            (d /. (fromJust $ convertDnEff effConv sample1 n))
    
testsUpDnMixedFieldOpsInPlace (name, sample) (nameN, sampleN) =
    testGroup (name ++ " with " ++ nameN ++ ": in-place mixed up/dn rounded ops") $
        [
            testProperty "addition" (propMixedAddInPlaceEqualsConvert sample sampleN)
        ,
            testProperty "multiplication" (propMixedMultInPlaceEqualsConvert sample sampleN)
        ,
            testProperty "division" (propMixedDivInPlaceEqualsConvert sample sampleN)
        ]

class 
    (RoundedMixedAddInPlace t tn, 
     RoundedMixedMultiplyInPlace t tn, 
     RoundedMixedRingEffort t tn) 
    => 
    RoundedMixedRingInPlace t tn

class 
    (RoundedMixedRingInPlace t tn, 
     RoundedMixedDivideInPlace t tn,
     RoundedMixedFieldEffort t tn) 
    => 
    RoundedMixedFieldInPlace t tn
    