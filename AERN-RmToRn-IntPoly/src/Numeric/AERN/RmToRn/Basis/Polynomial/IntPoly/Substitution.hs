{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-|
    Module      :  Numeric.AERN.RmToRn.Basis.Polynomial.IntPoly.Substitution
    Description :  evaluation of interval polynomials  
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Evaluation of interval polynomials.
-}

module Numeric.AERN.RmToRn.Basis.Polynomial.IntPoly.Substitution
--    (
--    )
where

import Numeric.AERN.RmToRn.Basis.Polynomial.IntPoly.Basics
import Numeric.AERN.RmToRn.Basis.Polynomial.IntPoly.RingOps
import Numeric.AERN.RmToRn.Basis.Polynomial.IntPoly.NumericOrder
import Numeric.AERN.RmToRn.Basis.Polynomial.IntPoly.Evaluation

import Numeric.AERN.RmToRn.New
import Numeric.AERN.RmToRn.Domain
import Numeric.AERN.RmToRn.Evaluation

import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut
import Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsImplicitEffort
import Numeric.AERN.RealArithmetic.ExactOps
import Numeric.AERN.RealArithmetic.Measures

import qualified Numeric.AERN.RefinementOrder as RefOrd
import Numeric.AERN.RefinementOrder.OpsImplicitEffort
import qualified Numeric.AERN.NumericOrder as NumOrd
import Numeric.AERN.NumericOrder.OpsImplicitEffort

import Numeric.AERN.Basics.Effort (Int1To1000(..))

import Numeric.AERN.Misc.Debug

import qualified Data.IntMap as IntMap

instance
    (Ord var, Show var,
     ArithInOut.RoundedReal cf, 
     RefOrd.IntervalLike cf, 
     Show cf,
     Show (Imprecision cf),
     NumOrd.PartialComparison (Imprecision cf))
    =>
    HasEvalOps (IntPoly var cf) (IntPoly var cf)
    where
    type EvalOpsEffortIndicator (IntPoly var cf) (IntPoly var cf) = 
        (Int1To1000, ArithInOut.RoundedRealEffortIndicator cf)
    evalOpsDefaultEffort _ sampleP@(IntPoly cfg _) = 
        NumOrd.pCompareDefaultEffort sampleP
    evalOpsOut eff _ sampleP =
        polyPolyEvalOpsOut eff sampleP sampleCf
        where
        sampleCf = getSampleDomValue sampleP

polyPolyEvalOpsOut ::
    (Ord var, Show var, Show cf,
     RefOrd.IntervalLike cf, 
     ArithInOut.RoundedReal cf,
     NumOrd.PartialComparison (Imprecision cf),
     Show (Imprecision cf))
    =>
   (Int1To1000, ArithInOut.RoundedRealEffortIndicator cf) ->
   (IntPoly var cf) ->
   cf ->
   PolyEvalOps var cf (IntPoly var cf)
polyPolyEvalOpsOut effCmp@(_,effCf) sampleP sampleCf =
    let (<+>) = ArithInOut.addOutEff effAddCf in
    let (<*>) = ArithInOut.multOutEff effCf in
    let (<^>) = ArithInOut.powerToNonnegIntOutEff effCf in
    let (<=?) = NumOrd.pLeqEff effCmp in
    PolyEvalOps (zero sampleP) (<+>) (<*>) (<^>) (newConstFnFromSample sampleP) (const Nothing) (<=?) $
        Just $ PolyEvalMonoOps
            RefOrd.getEndpointsOutWithDefaultEffort
            RefOrd.fromEndpointsOutWithDefaultEffort
            isDefinitelyExact
            effCf
    where
    isDefinitelyExact p = 
        polyIsExactEff effImpr p == Just True
    effImpr = ArithInOut.rrEffortImprecision sampleCf effCf
    effAddCf = ArithInOut.fldEffortAdd sampleCf $ ArithInOut.rrEffortField sampleCf effCf


substPolyMainVarElim ::
    (Ord var, Show var, 
     ArithInOut.RoundedReal cf, RefOrd.IntervalLike cf, 
     Show cf) 
    => 
    (ArithInOut.RoundedRealEffortIndicator cf) ->
    cf {- zero coefficient -} ->
    cf {- value to substitute the main var with -} ->
    IntPoly var cf -> IntPoly var cf
substPolyMainVarElim eff z substVal p@(IntPoly cfg _)
    = 
    case substPolyMainVar eff z substPoly p of
        IntPoly cfg (IntPolyV _ coeffs) ->
            IntPoly cfgR terms
            where
            cfgR = cfgRemVar cfg
            terms = case IntMap.toList coeffs of [(0, terms)] -> terms
    where
    substPoly = mkPoly substVal
    mkPoly = newConstFn cfg undefined

substPolyMainVar ::
    (Ord var, Show var, 
     ArithInOut.RoundedReal cf, Show cf,
     RefOrd.IntervalLike cf) 
    => 
    (ArithInOut.RoundedRealEffortIndicator cf) ->
    cf {- zero coefficient -} ->
    IntPoly var cf {- polynomial to substitute the main var with -} ->
    IntPoly var cf -> IntPoly var cf
substPolyMainVar eff z substPoly p@(IntPoly cfg terms) =
--    unsafePrint
--    (
--        "substPolyMainVar: "
--        ++ "\n p = " ++ showP p
--        ++ "\n substPoly = " ++ showP substPoly
--        ++ "\n result = " ++ showP result
--    ) $
    result
    where
--    showP = showPoly show show
    result =
        IntPoly cfg $
            evalPolyMono substPolyEvalOps [substTerms] p
    isDefinitelyExact p = termsAreExactEff effImpr p == Just True
    termsFromEndpoints (terms1, terms2) =
        intpoly_terms $ 
            RefOrd.fromEndpointsOutWithDefaultEffort (IntPoly cfg terms1, IntPoly cfg terms2)
    termsGetEndpoints terms =
        (intpoly_terms poly1, intpoly_terms poly2)
        where
        (poly1, poly2) = 
            RefOrd.getEndpointsOutWithDefaultEffort (IntPoly cfg terms)
    substTerms = intpoly_terms substPoly
    substPolyEvalOps =
        let ?multInOutEffort = effMult in
        let ?addInOutEffort = effAdd in
        let ?joinmeetEffort = effJoin in
        let ?pCompareEffort = effComp in
        PolyEvalOps 
            (cf2Terms z) addTerms multTerms (powTerms sample vars) 
            cf2Terms terms2terms leqTerms $
            Just $ PolyEvalMonoOps 
                termsGetEndpoints termsFromEndpoints isDefinitelyExact eff
    cf2Terms cf = mkConstTerms cf vars
    terms2terms (IntPolyV v ts) | v == mainVar = Nothing
    terms2terms terms = Just $ IntPolyV mainVar $ IntMap.singleton 0 terms
    vars@(mainVar : _) = ipolycfg_vars cfg
    doms = ipolycfg_doms cfg
    leqTerms terms1 terms2 =
        (zero sample) <=? diffRange 
        where
        diffRange = evalPolyOnInterval eff domsR (IntPoly cfgR diff)
        diff = addTerms terms2 $ negTerms terms1
        (cfgR, domsR) =
            case terms1 of 
                IntPolyV v _ | v == mainVar -> (cfg, doms)
                _ -> (cfgR, domsR)
            where
            cfgR = cfgRemVar cfg
            domR = ipolycfg_doms cfgR
    effMult = ArithInOut.fldEffortMult sample $ ArithInOut.rrEffortField sample eff
    effAdd = ArithInOut.fldEffortAdd sample $ ArithInOut.rrEffortField sample eff
    effComp = ArithInOut.rrEffortNumComp sample eff
    effJoin = ArithInOut.rrEffortJoinMeet sample eff
    effImpr = ArithInOut.rrEffortImprecision sample eff
    sample = ipolycfg_sample_cf cfg

                