{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE FlexibleContexts #-}
{-|
    Module      :  Numeric.AERN.Poly.IntPoly
    Description :  datatype of polynomials with consistent interval coefficients  
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Datatype of polynomials with consistent interval coefficients.
-}

module Numeric.AERN.Poly.IntPoly 
    (
--        sineOutPoly, sineOutPolyThin,
        module Numeric.AERN.Poly.IntPoly.Config,
        module Numeric.AERN.Poly.IntPoly.IntPoly,
        module Numeric.AERN.Poly.IntPoly.New,
--        module Numeric.AERN.Poly.IntPoly.DomBoxChanges,
--        module Numeric.AERN.Poly.IntPoly.Differentiation,
        module Numeric.AERN.Poly.IntPoly.Evaluation,
        module Numeric.AERN.Poly.IntPoly.Reduction,
        module Numeric.AERN.Poly.IntPoly.Addition,
        module Numeric.AERN.Poly.IntPoly.Multiplication,
--        module Numeric.AERN.Poly.IntPoly.NumericOrder,
--        ,
--        module Numeric.AERN.Poly.IntPoly.RingOps,
--        module Numeric.AERN.Poly.IntPoly.Integrate,
--        module Numeric.AERN.Poly.IntPoly.RefinementOrder,
--        module Numeric.AERN.Poly.IntPoly.Substitution,
--        module Numeric.AERN.Poly.IntPoly.Minmax
    )
where

import Numeric.AERN.Poly.IntPoly.Config
import Numeric.AERN.Poly.IntPoly.IntPoly
import Numeric.AERN.Poly.IntPoly.New
--import Numeric.AERN.Poly.IntPoly.DomBoxChanges
--import Numeric.AERN.Poly.IntPoly.Differentiation -- deliberately hidden
import Numeric.AERN.Poly.IntPoly.Evaluation
import Numeric.AERN.Poly.IntPoly.Reduction
import Numeric.AERN.Poly.IntPoly.Addition
import Numeric.AERN.Poly.IntPoly.Multiplication
import Numeric.AERN.Poly.IntPoly.NumericOrder
--import Numeric.AERN.Poly.IntPoly.RingOps
--import Numeric.AERN.Poly.IntPoly.Integrate
--import Numeric.AERN.Poly.IntPoly.RefinementOrder
--import Numeric.AERN.Poly.IntPoly.Substitution
--import Numeric.AERN.Poly.IntPoly.Minmax



--import Numeric.AERN.RmToRn.New
--import Numeric.AERN.RmToRn.Domain
--
--import Numeric.AERN.Basics.Interval
--import Numeric.AERN.RealArithmetic.Interval.FieldOps (multiplyIntervals)
--
--import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut
--import Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsImplicitEffort
--
--import Numeric.AERN.RealArithmetic.ExactOps
--import Numeric.AERN.RealArithmetic.Measures
--
--import qualified Numeric.AERN.NumericOrder as NumOrd
--import Numeric.AERN.NumericOrder.OpsImplicitEffort
--import qualified Numeric.AERN.RefinementOrder as RefOrd
--import Numeric.AERN.RefinementOrder.OpsImplicitEffort
--
--import Numeric.AERN.Basics.Effort
--import Numeric.AERN.Basics.Consistency
--
--import Numeric.AERN.Misc.Debug
--
--import Test.QuickCheck
--
--{-| a quick and dirty sine implementation; this should be made generic
-- and move to aern-real -}
--sineOutPoly ::
--    (ArithInOut.RoundedReal cf, 
--     ArithInOut.RoundedMixedField cf cf,
--     RefOrd.IntervalLike cf,
--     GeneratableVariables var,
--     HasAntiConsistency cf,
--     Arbitrary cf, 
--     NumOrd.PartialComparison (Imprecision cf),  
--     Show (Imprecision cf),
--     Show var, Ord var, Show cf) 
--    =>
--    (RefOrd.GetEndpointsEffortIndicator (IntPoly var cf), 
--     RefOrd.FromEndpointsEffortIndicator (IntPoly var cf)) -> 
--    Int {-^ how many terms of the Taylor expansion to consider -} -> 
--    (ArithInOut.RoundedRealEffortIndicator cf) -> 
--    Int {-^ how many terms of the Taylor expansion to consider -} -> 
--    IntPoly var cf -> 
--    IntPoly var cf
--sineOutPoly (effGetE, effFromE) degreeBezier effCF n x@(IntPoly cfg _) =
--    let ?pCompareEffort = (Int1To1000 0, effCF) in
--    case (c0 <=? xPlus1pt5, xMinus1pt5 <=? c0) of
--        (Just True, Just True) -> 
----            unsafePrint ("sineOutPoly: using resultNoPeak") $
--            resultNoPeak
--        _ -> 
----            unsafePrint ("sineOutPoly: using resultWithPeakProtection") $
--            resultWithPeakProtection
--    where
--    resultNoPeak = RefOrd.fromEndpointsOutEff effFromE (sinXL, sinXR)
--    resultWithPeakProtection = 
--        resultNoPeak <+> peakErrorBound 
--    peakErrorBound = 
--        RefOrd.fromEndpointsOutEff effFromE (neg width, width) 
--    width = xR <+> (neg xL)
--    (xL,xR) = RefOrd.getEndpointsOutEff effGetE x
--    sinXL = sineOutPolyThin (effGetE, effFromE) degreeBezier effCF n xL
--    sinXR = sineOutPolyThin (effGetE, effFromE) degreeBezier effCF n xR
--    xMinus1pt5 = x <+>| (-1.5 :: Double) 
--    xPlus1pt5 = x <+>| (1.5 :: Double) 
--    c0 = newConstFnFromSample x $ zero sampleCf
--    
--    (<+>) = ArithInOut.addOutEff effCF
--    (<+>|) = ArithInOut.mixedAddOutEff effAddDbl
--    (<=?) = NumOrd.pLeqEff (Int1To1000 0, effCF) 
--
--    effAdd = ArithInOut.fldEffortAdd sampleCf $ ArithInOut.rrEffortField sampleCf effCF
--    effAddDbl = ArithInOut.mxfldEffortAdd sampleCf (1::Double) $ ArithInOut.rrEffortDoubleMixedField sampleCf effCF
--    sampleCf = getSampleDomValue x
--    
--        
--sineOutPolyThin ::
--    (ArithInOut.RoundedReal cf, 
--     ArithInOut.RoundedMixedField cf cf,
--     RefOrd.IntervalLike cf,
--     GeneratableVariables var,
--     HasAntiConsistency cf,
--     Arbitrary cf,  
--     NumOrd.PartialComparison (Imprecision cf),
--     Show (Imprecision cf),
--     Show var, Ord var, Show cf) =>
--    (RefOrd.GetEndpointsEffortIndicator (IntPoly var cf), 
--     RefOrd.FromEndpointsEffortIndicator (IntPoly var cf)) -> 
--    Int {-^ degree of Bezier approximation when computing min/max -} -> 
--    (ArithInOut.RoundedRealEffortIndicator cf) -> 
--    Int {-^ how many terms of the Taylor expansion to consider -} -> 
--    IntPoly var cf -> 
--    IntPoly var cf
--sineOutPolyThin (effGetE, effFromE) degreeBezier effCF n x@(IntPoly cfg _) =
----    unsafePrintReturn
----    (
----        "sinePoly:"
----        ++ "\n x = " ++ show x
----        ++ "\n n = " ++ show n
----        ++ "\n result = "
----    ) $
--    let (<*>) = ArithInOut.multOutEff effCF in 
--    x <*> (aux unitIntPoly (2*n+2)) -- x * (1 - x^2/(2*3)(1 - x^2/(4*5)(1 - ...)))
--    where
--    unitIntPoly = 
--        let (</\>) = RefOrd.meetOutEff effJoin in
--        newConstFn cfg undefined $ (neg o) </\> o
--    o = one sampleCf
--    aux acc 0 = acc
--    aux acc n =
----        unsafePrint
----        (
----            "  sinePoly aux:"
----            ++ "\n    acc = " ++ (show $ checkPoly acc)
----            ++ "\n    n = " ++ show n
----            ++ "\n    squareX = " ++ (show $ checkPoly squareX)
----            ++ "\n    squareXAcc = " ++ (show $ checkPoly squareXAcc)
----            ++ "\n    squareXDivNNPlusOneAcc = " ++ (show $ checkPoly squareXDivNNPlusOneAcc)
----            ++ "\n    negSquareXDivNNPlusOneAcc = " ++ (show $ checkPoly negSquareXDivNNPlusOneAcc)
----            ++ "\n    newAcc = " ++ (show $ checkPoly newAcc)
----        )$
--        aux newAcc (n-2)
--        where
--        newAcc = ArithInOut.mixedAddOutEff effAddInt negSquareXDivNNPlusOneAcc (1::Int)
--        negSquareXDivNNPlusOneAcc = negPoly squareXDivNNPlusOneAcc
--        squareXDivNNPlusOneAcc = ArithInOut.mixedDivOutEff effDivInt squareXAcc (n*(n+1))
--        squareXAcc = squareX <*> acc 
--    squareX = x <*> x
--    (<*>) = ArithInOut.multOutEff effCF
----    a <*> b = 
----        multPolys effCF a b
----        RefOrd.fromEndpointsOutEff effFromE $
----        multiplyIntervals
----            (pNonnegNonposEff (Int1To1000 0, effCF))
----            (multPolys effCF) (multPolys effCF)
----            (NumOrd.minDnEff effortMinmax) -- minL
----            (NumOrd.minUpEff effortMinmax) -- minR
----            (NumOrd.maxDnEff effortMinmax) -- maxL
----            (NumOrd.maxUpEff effortMinmax) -- maxR
----            (NumOrd.minDnEff effortMinmax)
----            (NumOrd.maxUpEff effortMinmax) 
----            (Interval aL aR) (Interval bL bR)
----        where
----        (aL, aR) = RefOrd.getEndpointsOutEff effGetE a
----        (bL, bR) = RefOrd.getEndpointsOutEff effGetE b
--    effortMinmax = minmaxUpDnDefaultEffortIntPolyWithBezierDegree degreeBezier sampleF
--    effJoin = ArithInOut.rrEffortJoinMeet sampleCf effCF
--    effAddInt = ArithInOut.mxfldEffortAdd sampleCf (1::Int) $ ArithInOut.rrEffortIntMixedField sampleCf effCF
--    effDivInt = ArithInOut.mxfldEffortDiv sampleCf (1::Int) $ ArithInOut.rrEffortIntMixedField sampleCf effCF
--    sampleCf = ipolycfg_sample_cf cfg
--    sampleF = x

    

        